import 'package:flutter/material.dart';

import '../../../core/design/app_shimmer.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/widgets/conv_widgets.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../attendance/models/family.dart';
import '../../attendance/models/member.dart';

class AssignSoloMembersPage extends StatefulWidget {
  const AssignSoloMembersPage({
    super.key,
    required this.repository,
    required this.soloMembers,
    this.disableAnimations = false,
  });

  final AttendanceRepository repository;
  final List<Member> soloMembers;
  final bool disableAnimations;

  @override
  State<AssignSoloMembersPage> createState() => _AssignSoloMembersPageState();
}

class _AssignSoloMembersPageState extends State<AssignSoloMembersPage> {
  late Future<List<Family>> _familiesFuture;
  final Map<String, String> _assignments = {}; // memberId -> familyId ('solo', existing ID, or 'new:name')
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadFamilies();
  }

  void _loadFamilies() {
    _familiesFuture = _fetchWithMinDelay();
  }

  Future<List<Family>> _fetchWithMinDelay() async {
    final results = await Future.wait([
      widget.repository.fetchFamilies(),
      if (!widget.disableAnimations)
        Future.delayed(const Duration(milliseconds: 800)),
    ]);
    return results.first as List<Family>;
  }

  static String _lastNameOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) return '';
    return parts.last;
  }

  Future<void> _showFamilyPicker(
    List<Family> realFamilies,
    Member member,
  ) async {
    final c = context.conv;
    final selectedId = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: c.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                child: Text(
                  'Assign ${member.displayName} to...',
                  style: AppTypography.fraunces(
                    fontSize: 20,
                    fontWeight: FontWeight.w400,
                    color: c.ink,
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.person_outline, color: c.ink3),
                title: Text('Keep Solo', style: TextStyle(color: c.ink)),
                trailing: _assignments[member.id] == null || _assignments[member.id] == 'solo'
                    ? Icon(Icons.check, color: c.primary)
                    : null,
                onTap: () => Navigator.of(ctx).pop('solo'),
              ),
              ListTile(
                leading: Icon(Icons.add, color: c.primary),
                title: Text(
                  'Create new family...',
                  style: TextStyle(color: c.primary, fontWeight: FontWeight.w500),
                ),
                onTap: () => Navigator.of(ctx).pop('prompt_new'),
              ),
              if (realFamilies.isNotEmpty) ...[
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: realFamilies.length,
                    itemBuilder: (context, idx) {
                      final f = realFamilies[idx];
                      final isSelected = _assignments[member.id] == f.id;
                      return ListTile(
                        leading: Icon(Icons.family_restroom, color: c.ink3),
                        title: Text(f.displayName, style: TextStyle(color: c.ink)),
                        subtitle: Text(
                          '${f.members.length} ${f.members.length == 1 ? 'member' : 'members'}',
                          style: TextStyle(fontSize: 12, color: c.ink3),
                        ),
                        trailing: isSelected ? Icon(Icons.check, color: c.primary) : null,
                        onTap: () => Navigator.of(ctx).pop(f.id),
                      );
                    },
                  ),
                ),
              ] else
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('No existing families yet.'),
                  ),
                ),
            ],
          ),
        );
      },
    );

    if (selectedId == null) return;

    if (selectedId == 'prompt_new') {
      final defaultLastName = _lastNameOf(member.displayName);
      final newName = await _promptNewFamilyName(defaultLastName);
      if (newName != null && newName.isNotEmpty) {
        setState(() {
          _assignments[member.id] = 'new:$newName';
        });
      }
    } else {
      setState(() {
        _assignments[member.id] = selectedId;
      });
    }
  }

  Future<String?> _promptNewFamilyName(String defaultName) async {
    final controller = TextEditingController(text: defaultName);
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Create New Family'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Family Name',
              hintText: 'Enter name',
            ),
            textCapitalization: TextCapitalization.words,
            onSubmitted: (val) => Navigator.of(ctx).pop(val.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _save() async {
    final updates = _assignments.entries
        .where((e) => e.value != 'solo')
        .toList();

    if (updates.isEmpty) {
      Navigator.of(context).pop(false);
      return;
    }

    setState(() => _saving = true);

    try {
      final cacheNewFamilies = <String, Family>{};

      for (final update in updates) {
        final memberId = update.key;
        final target = update.value;

        if (target.startsWith('new:')) {
          final familyName = target.substring(4);
          Family family;
          if (cacheNewFamilies.containsKey(familyName)) {
            family = cacheNewFamilies[familyName]!;
          } else {
            family = await widget.repository.addFamily(familyName);
            cacheNewFamilies[familyName] = family;
          }
          await widget.repository.moveMemberToFamily(memberId, family.id);
        } else {
          await widget.repository.moveMemberToFamily(memberId, target);
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error assigning members: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: c.ink),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: Text(
          'Assign Solo Members',
          style: AppTypography.eyebrow(color: c.ink3),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<List<Family>>(
        future: _familiesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildSkeleton(context);
          }

          final allFamilies = snapshot.data ?? [];
          final realFamilies = allFamilies.where((f) => !f.isAutoSingleton).toList();

          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 110),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'QUICK ASSIGNMENT',
                          style: AppTypography.eyebrow(color: c.primary),
                        ),
                        const SizedBox(height: 6),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '${widget.soloMembers.length} members',
                                style: TextStyle(color: c.primary),
                              ),
                              const TextSpan(text: ' are solo.'),
                            ],
                            style: AppTypography.fraunces(
                              fontSize: 30,
                              fontWeight: FontWeight.w400,
                              color: c.ink,
                              height: 1.1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Quickly group unaffiliated members into existing families, or tap to create new families in one go.',
                          style: TextStyle(fontSize: 14, color: c.ink2),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                  for (final member in widget.soloMembers) ...[
                    _buildMemberCard(realFamilies, member),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [c.bg.withValues(alpha: 0), c.bg],
                    ),
                  ),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                        child: Text(
                          'Cancel',
                          style: TextStyle(color: c.ink3),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: _saving ? null : _save,
                          style: FilledButton.styleFrom(
                            backgroundColor: c.primary,
                            foregroundColor: c.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Confirm Assignments',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMemberCard(List<Family> realFamilies, Member member) {
    final c = context.conv;
    final assignment = _assignments[member.id];
    
    String label = 'Stay Solo';
    IconData icon = Icons.person_outline;
    Color iconColor = c.ink3;

    if (assignment != null && assignment != 'solo') {
      if (assignment.startsWith('new:')) {
        label = 'New: ${assignment.substring(4)}';
        icon = Icons.add;
        iconColor = c.primary;
      } else {
        final family = realFamilies.firstWhere((f) => f.id == assignment, orElse: () => realFamilies.first);
        label = family.displayName;
        icon = Icons.family_restroom;
        iconColor = c.primary;
      }
    }

    final letter = member.displayName.isEmpty ? '?' : member.displayName.characters.first.toUpperCase();

    return ConvCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          ConvAvatar(letter: letter),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.displayName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Currently solo',
                  style: TextStyle(fontSize: 12, color: c.ink3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: assignment != null && assignment != 'solo'
                ? Color.alphaBlend(c.primary.withValues(alpha: 0.1), c.card)
                : c.cardSoft,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _showFamilyPicker(realFamilies, member),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 14, color: iconColor),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: assignment != null && assignment != 'solo' ? c.primary : c.ink,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_drop_down, size: 16, color: iconColor),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 110),
      children: [
        AppShimmer(
          width: double.infinity,
          height: 120,
          borderRadius: BorderRadius.circular(16),
          disableAnimations: widget.disableAnimations,
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < 4; i++) ...[
          AppShimmer(
            width: double.infinity,
            height: 72,
            borderRadius: BorderRadius.circular(18),
            disableAnimations: widget.disableAnimations,
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
