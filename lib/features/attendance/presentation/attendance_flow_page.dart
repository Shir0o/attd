import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/attendance_repository.dart';
import '../models/attendance_status.dart';
import '../models/family.dart';
import '../models/member.dart';
import 'add_family_page.dart';

class AttendanceFlowPage extends StatefulWidget {
  const AttendanceFlowPage({super.key, required this.repository});

  final AttendanceRepository repository;

  @override
  State<AttendanceFlowPage> createState() => _AttendanceFlowPageState();
}

class _AttendanceFlowPageState extends State<AttendanceFlowPage> {
  late Future<List<Family>> _familiesFuture;
  final PageController _pageController = PageController();
  final Map<String, Map<String, AttendanceStatus>> _attendance = {};
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _familiesFuture = widget.repository.fetchFamilies();
  }

  AttendanceStatus _statusFor(String familyId, Member member) {
    final familyStatuses = _attendance[familyId];
    if (familyStatuses == null) return member.defaultStatus;
    return familyStatuses[member.id] ?? member.defaultStatus;
  }

  void _updateStatus(String familyId, Member member, AttendanceStatus status) {
    setState(() {
      final familyStatuses = _attendance.putIfAbsent(familyId, () => {});
      familyStatuses[member.id] = status;
    });
  }

  void _jumpTo(int index) {
    _currentPage = index;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _addVisitor(Family family) async {
    final name = await _promptName('Add visitor', 'Visitor name');
    if (name == null) return;

    final visitor = Member(
      id: 'visitor-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1000)}',
      displayName: name,
      isVisitor: true,
      defaultStatus: AttendanceStatus.present,
    );

    final updatedFamily = await widget.repository.addMember(family.id, visitor);
    setState(() {
      _attendance.putIfAbsent(updatedFamily.id, () => {});
      _attendance[updatedFamily.id]![visitor.id] = AttendanceStatus.present;
      _familiesFuture = widget.repository.fetchFamilies();
    });
  }

  Future<void> _addMember(Family family) async {
    final name = await _promptName('Add member', 'Member name');
    if (name == null) return;

    final member = Member(
      id: 'member-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1000)}',
      displayName: name,
      isVisitor: false,
      defaultStatus: AttendanceStatus.absent,
    );

    final updatedFamily = await widget.repository.addMember(family.id, member);
    setState(() {
      _familiesFuture = widget.repository.fetchFamilies();
    });
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
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Add'),
            ),
          ],
        );
      },
    ).then((result) => (result == null || result.isEmpty) ? null : result);
  }

  Future<void> _addFamily() async {
    final newFamily = await Navigator.of(context).push<Family>(
      MaterialPageRoute(
        builder: (context) => AddFamilyPage(repository: widget.repository),
      ),
    );

    if (newFamily != null) {
      setState(() {
        _familiesFuture = widget.repository.fetchFamilies();
      });
      
      // Wait for families to reload then jump to last page
      final families = await _familiesFuture;
      if (mounted) {
        _jumpTo(families.indexOf(newFamily));
      }
    }
  }


  void _onNavigate(List<Family> families, int delta) {
    final target = (_currentPage + delta).clamp(0, families.length - 1);
    if (target != _currentPage) {
      setState(() {
        _currentPage = target;
      });
      _jumpTo(target);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Start attendance'),
        actions: [
          IconButton(
            onPressed: _addFamily,
            icon: const Icon(Icons.add),
            tooltip: 'Add family',
          ),
        ],
      ),
      body: FutureBuilder<List<Family>>(
        future: _familiesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No families available'));
          }

          final families = snapshot.data!;
          final shortcuts = <LogicalKeySet, Intent>{
            LogicalKeySet(LogicalKeyboardKey.arrowLeft): const _PageIntent(-1),
            LogicalKeySet(LogicalKeyboardKey.arrowRight): const _PageIntent(1),
            LogicalKeySet(LogicalKeyboardKey.pageUp): const _PageIntent(-1),
            LogicalKeySet(LogicalKeyboardKey.pageDown): const _PageIntent(1),
          };

          return Shortcuts(
            shortcuts: shortcuts,
            child: Actions(
              actions: {
                _PageIntent: CallbackAction<_PageIntent>(
                  onInvoke: (intent) => _onNavigate(families, intent.delta),
                ),
              },
              child: Focus(
                autofocus: true,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Text(
                            'Family ${_currentPage + 1} of ${families.length}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Spacer(),
                          Wrap(
                            spacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _currentPage > 0
                                    ? () => _onNavigate(families, -1)
                                    : null,
                                icon: const Icon(Icons.arrow_left),
                                label: const Text('Prev'),
                              ),
                              FilledButton.icon(
                                onPressed: _currentPage < families.length - 1
                                    ? () => _onNavigate(families, 1)
                                    : null,
                                icon: const Icon(Icons.arrow_right),
                                label: const Text('Next'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        physics: const ClampingScrollPhysics(),
                        onPageChanged: (index) {
                          setState(() {
                            _currentPage = index;
                          });
                        },
                        itemCount: families.length,
                        itemBuilder: (context, index) {
                          final family = families[index];
                          return _FamilyAttendanceView(
                            family: family,
                            statusBuilder: (member) =>
                                _statusFor(family.id, member),
                            onStatusChanged: (member, status) =>
                                _updateStatus(family.id, member, status),
                            onAddVisitor: () => _addVisitor(family),
                            onAddMember: () => _addMember(family),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FamilyAttendanceView extends StatelessWidget {
  const _FamilyAttendanceView({
    required this.family,
    required this.statusBuilder,
    required this.onStatusChanged,
    required this.onAddVisitor,
    required this.onAddMember,
  });

  final Family family;
  final AttendanceStatus Function(Member) statusBuilder;
  final void Function(Member, AttendanceStatus) onStatusChanged;
  final VoidCallback onAddVisitor;
  final VoidCallback onAddMember;

  @override
  Widget build(BuildContext context) {
    final statuses = AttendanceStatus.values
        .map(
          (status) => ButtonSegment<AttendanceStatus>(
            value: status,
            label: Text(status.label),
          ),
        )
        .toList();
    final hasVisitors = family.members.any((member) => member.isVisitor);

    return FocusTraversalGroup(
      policy: WidgetOrderTraversalPolicy(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.groups, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  family.displayName,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                FilledButton.tonal(
                  onPressed: onAddMember,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.person_add),
                      SizedBox(width: 8),
                      Text('Add member'),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: onAddVisitor,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Add visitor'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Use arrow keys to select a family, Tab to move fields.'),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: family.members.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final member = family.members[index];
                  final status = statusBuilder(member);
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceTint.withOpacity(0.14),
                      child: Text(member.displayName.characters.first.toUpperCase()),
                    ),
                    title: Text(member.displayName),
                    subtitle: member.isVisitor ? const Text('Visitor') : null,
                    trailing: SegmentedButton<AttendanceStatus>(
                      segments: statuses,
                      selected: {status},
                      onSelectionChanged: (selected) =>
                          onStatusChanged(member, selected.first),
                      showSelectedIcon: false,
                      multiSelectionEnabled: false,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageIntent extends Intent {
  const _PageIntent(this.delta);
  final int delta;
}
