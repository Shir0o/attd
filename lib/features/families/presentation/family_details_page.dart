import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/widgets/conv_widgets.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../attendance/models/attendance_status.dart';
import '../../attendance/models/family.dart';
import '../../attendance/models/member.dart';

class FamilyDetailsPage extends StatefulWidget {
  const FamilyDetailsPage({
    super.key,
    required this.family,
    required this.repository,
  });

  final Family family;
  final AttendanceRepository repository;

  @override
  State<FamilyDetailsPage> createState() => _FamilyDetailsPageState();
}

class _FamilyDetailsPageState extends State<FamilyDetailsPage> {
  late Family _family;
  List<Family> _allFamilies = const [];
  StreamSubscription? _familiesSub;

  @override
  void initState() {
    super.initState();
    _family = widget.family;
    _familiesSub = widget.repository.streamFamilies().listen((families) {
      if (!mounted) return;
      final updated = families.firstWhere(
        (f) => f.id == _family.id,
        orElse: () => _family,
      );
      setState(() {
        _allFamilies = families;
        _family = updated;
      });
    });
  }

  @override
  void dispose() {
    _familiesSub?.cancel();
    super.dispose();
  }

  /// Last whitespace-separated token of a name, normalized for comparison.
  static String _lastToken(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '';
    final parts = trimmed.split(RegExp(r'\s+'));
    return parts.last.toLowerCase();
  }

  List<Member> _suggestedMembers() {
    final familyToken = _lastToken(_family.displayName);
    if (familyToken.isEmpty) return const [];
    final currentMemberIds = _family.members.map((m) => m.id).toSet();
    final suggestions = <Member>[];
    for (final f in _allFamilies) {
      // Suggest from auto-created singletons or any family with 1 or fewer members —
      // these are members with no real family group yet.
      if (!f.isAutoSingleton && f.members.length > 1) continue;
      for (final m in f.members) {
        if (m.deletedAt != null) continue;
        if (currentMemberIds.contains(m.id)) continue;
        if (_lastToken(m.displayName) == familyToken) {
          suggestions.add(m);
        }
      }
    }
    suggestions.sort((a, b) => a.displayName.compareTo(b.displayName));
    return suggestions;
  }

  List<Member> _getUnaffiliatedMembers() {
    return [
      for (final f in _allFamilies)
        if (f.isAutoSingleton) ...f.members,
    ];
  }

  Future<void> _addExistingMember() async {
    final solo = _getUnaffiliatedMembers();
    if (solo.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('No solo members'),
          content: const Text('There are no unaffiliated solo members in the system.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final selected = await showDialog<Member>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Select Member'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: solo.length,
              itemBuilder: (context, idx) {
                final m = solo[idx];
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(m.displayName.characters.first.toUpperCase()),
                  ),
                  title: Text(m.displayName),
                  onTap: () => Navigator.of(ctx).pop(m),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    if (selected == null) return;
    try {
      await widget.repository.moveMemberToFamily(selected.id, _family.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added ${selected.displayName} to ${_family.displayName}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding member: $e')),
        );
      }
    }
  }

  Future<void> _addMember() async {
    final option = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) {
        final c = context.conv;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.person_add_alt_1_outlined, color: c.primary),
                title: const Text('Create New Member'),
                onTap: () => Navigator.of(ctx).pop('new'),
              ),
              ListTile(
                leading: Icon(Icons.people_outline, color: c.primary),
                title: const Text('Add Existing Member'),
                onTap: () => Navigator.of(ctx).pop('existing'),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted) return;

    if (option == 'new') {
      final name = await _promptName('Add Member', 'Member Name');
      if (name == null) return;
      final member = Member(
        id: 'member-${const Uuid().v4()}',
        displayName: name,
        isVisitor: false,
        defaultStatus: AttendanceStatus.absent,
      );
      try {
        final updated = await widget.repository.addMember(_family.id, member);
        if (mounted) setState(() => _family = updated);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error adding member: $e')),
          );
        }
      }
    } else if (option == 'existing') {
      await _addExistingMember();
    }
  }

  Future<void> _addSuggestion(Member suggestion) async {
    try {
      await widget.repository.moveMemberToFamily(suggestion.id, _family.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added ${suggestion.displayName} to ${_family.displayName}')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding suggestion: $e')),
        );
      }
    }
  }

  Future<void> _detachMember(Member member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${member.displayName} from ${_family.displayName}?'),
        content: const Text(
          'They will become an unaffiliated member. Past attendance history is preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.repository.detachMember(member.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing member: $e')),
        );
      }
    }
  }

  Future<String?> _promptName(String title, String label) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: label,
              hintText: 'Enter name',
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (value) => Navigator.of(context).pop(value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Add'),
            ),
          ],
        );
      },
    ).then((result) => (result == null || result.isEmpty) ? null : result);
  }

  Future<void> _deleteFamily() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Family?'),
        content: Text(
          'This will delete the family "${_family.displayName}" and unassociate all its members. The members will NOT be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.repository.deleteFamily(_family.id);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting family: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _suggestedMembers();
    final theme = Theme.of(context);
    final c = context.conv;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        elevation: 0,
        title: Text('Edit family', style: AppTypography.eyebrow(color: c.ink3)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.delete_outline, color: c.absent),
            tooltip: 'Delete Family',
            onPressed: _deleteFamily,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 10, 22, 100),
        children: [
          Text(
            _family.displayName,
            style: AppTypography.fraunces(
              fontSize: 44,
              fontWeight: FontWeight.w400,
              color: c.ink,
              letterSpacing: -1.32,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${_family.members.length} ${_family.members.length == 1 ? 'member' : 'members'}',
            style: TextStyle(color: c.ink2, fontSize: 14),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Text('MEMBERS', style: AppTypography.eyebrow(color: c.ink3)),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 10),
          if (_family.members.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('No members yet.',
                  style: TextStyle(fontSize: 15, color: c.ink2)),
            ),
          ..._family.members.map((member) {
            return ListTile(
              leading: CircleAvatar(
                backgroundColor:
                    theme.colorScheme.surfaceContainerHighest,
                child: Text(member.displayName.characters.first.toUpperCase()),
              ),
              title: Text(
                member.displayName,
                style: const TextStyle(fontSize: 18),
              ),
              subtitle: member.isVisitor
                  ? const Text('Visitor', style: TextStyle(fontSize: 14))
                  : null,
              trailing: IconButton(
                key: Key('detachMember_${member.id}'),
                tooltip: 'Remove from family',
                icon: const Icon(Icons.person_remove_outlined),
                onPressed: () => _detachMember(member),
              ),
            );
          }),
          if (suggestions.isNotEmpty) ...[
            const Divider(height: 32),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Suggested',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Unaffiliated members whose last name matches "${_family.displayName}".',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            ...suggestions.map((m) {
              return ListTile(
                key: Key('suggestion_${m.id}'),
                leading: CircleAvatar(
                  backgroundColor:
                      theme.colorScheme.secondaryContainer,
                  child: Text(m.displayName.characters.first.toUpperCase()),
                ),
                title: Text(m.displayName),
                trailing: TextButton.icon(
                  onPressed: () => _addSuggestion(m),
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              );
            }),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addMember,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Member'),
      ),
    );
  }
}
