import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/widgets/conv_theme.dart';
import '../../../core/maintenance/bulk_maintenance_service.dart';
import '../../../data/session_repository.dart';
import '../../attendance/data/attendance_repository.dart';

/// Opens the duplicate-member cleanup sheet.
///
/// Suggestions are name-based; the merge itself is member-id based, so two
/// genuinely different people who share a name are never merged by accident.
Future<void> showDuplicateMembersCleanupSheet({
  required BuildContext context,
  required AttendanceRepository attendanceRepository,
  required SessionRepository sessionRepository,
  required Future<void> Function() onComplete,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DuplicateMembersCleanupSheet(
      attendanceRepository: attendanceRepository,
      sessionRepository: sessionRepository,
      onComplete: onComplete,
    ),
  );
}

class DuplicateMembersCleanupSheet extends StatefulWidget {
  const DuplicateMembersCleanupSheet({
    super.key,
    required this.attendanceRepository,
    required this.sessionRepository,
    required this.onComplete,
  });

  final AttendanceRepository attendanceRepository;
  final SessionRepository sessionRepository;
  final Future<void> Function() onComplete;

  @override
  State<DuplicateMembersCleanupSheet> createState() =>
      _DuplicateMembersCleanupSheetState();
}

class _DuplicateMembersCleanupSheetState
    extends State<DuplicateMembersCleanupSheet> {
  static const _dismissedPrefsKey = 'duplicate_member_suggestions_dismissed';

  late final BulkMaintenanceService _service;
  final Set<String> _dismissed = {};
  final Set<String> _included = {};
  final Map<String, String> _targetByGroup = {};

  List<DuplicateMemberGroup> _groups = const [];
  List<MemberMergePlan>? _plans;
  BulkDryRunResult? _result;
  String? _error;
  bool _loading = true;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    _service = BulkMaintenanceService(
      attendanceRepository: widget.attendanceRepository,
      sessionRepository: widget.sessionRepository,
    );
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final dismissed =
          (prefs.getStringList(_dismissedPrefsKey) ?? const <String>[]).toSet();
      final groups = await _service.findDuplicateMembers();
      if (!mounted) return;
      setState(() {
        _dismissed.addAll(dismissed);
        _groups = groups;
        for (final group in groups) {
          _targetByGroup[group.key] = group.suggestedTarget.member.id;
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not scan for duplicates: $e';
      });
    }
  }

  List<DuplicateMemberGroup> get _visibleGroups =>
      _groups.where((group) => !_dismissed.contains(group.key)).toList();

  List<MemberMergePlan> _buildPlans() {
    final plans = <MemberMergePlan>[];
    for (final group in _groups) {
      if (!_included.contains(group.key)) continue;
      final targetId =
          _targetByGroup[group.key] ?? group.suggestedTarget.member.id;
      final target = group.occurrences.firstWhere(
        (occurrence) => occurrence.member.id == targetId,
        orElse: () => group.suggestedTarget,
      );
      for (final occurrence in group.occurrences) {
        if (occurrence.member.id == target.member.id) continue;
        plans.add(MemberMergePlan(
          sourceMemberId: occurrence.member.id,
          targetMemberId: target.member.id,
          sourceName: occurrence.member.displayName,
          targetName: target.member.displayName,
        ));
      }
    }
    return plans;
  }

  void _setIncluded(DuplicateMemberGroup group, bool included) {
    setState(() {
      if (included) {
        _included.add(group.key);
      } else {
        _included.remove(group.key);
      }
      _resetPreview();
    });
  }

  void _selectTarget(DuplicateMemberGroup group, String memberId) {
    setState(() {
      _targetByGroup[group.key] = memberId;
      _included.add(group.key);
      _resetPreview();
    });
  }

  void _resetPreview() {
    _result = null;
    _plans = null;
    _error = null;
  }

  Future<void> _dismiss(DuplicateMemberGroup group) async {
    setState(() {
      _dismissed.add(group.key);
      _included.remove(group.key);
      _resetPreview();
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_dismissedPrefsKey, _dismissed.toList());
  }

  Future<void> _runDryRun() async {
    final plans = _buildPlans();
    if (plans.isEmpty) {
      setState(() {
        _error = 'Select at least one duplicate group to merge.';
        _result = null;
        _plans = null;
      });
      return;
    }

    setState(() {
      _error = null;
      _result = null;
      _plans = null;
    });
    try {
      final result = await _service.simulateMergeMembers(plans);
      if (!mounted) return;
      setState(() {
        _result = result;
        _plans = plans;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Dry run simulation failed: $e');
      }
    }
  }

  Future<void> _apply() async {
    final plans = _plans;
    if (plans == null) return;
    setState(() => _applying = true);
    try {
      await _service.executeMergeMembers(plans);
      await widget.onComplete();
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Merged ${plans.length} duplicate record'
            '${plans.length == 1 ? '' : 's'}.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _applying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Duplicate cleanup failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    final visible = _visibleGroups;
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(26),
            topRight: Radius.circular(26),
          ),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          14,
          20,
          MediaQuery.of(context).viewInsets.bottom + 18,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: c.hair,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: c.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.group_remove_outlined,
                    color: c.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Duplicate cleanup',
                        style: AppTypography.fraunces(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: c.ink,
                        ),
                      ),
                      Text(
                        'Same name, different member records · id-safe merge',
                        style: TextStyle(fontSize: 12, color: c.ink3),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, color: c.ink3),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(36),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null && visible.isEmpty)
              _buildError(c)
            else if (visible.isEmpty)
              _buildEmpty(c)
            else ...[
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: visible.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) =>
                      _buildGroupCard(c, visible[index]),
                ),
              ),
              const SizedBox(height: 12),
              _buildFooter(c),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(ConvocationColors c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 8),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.check_circle_outline, color: c.present, size: 32),
            const SizedBox(height: 10),
            Text(
              'No duplicate names found.',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: c.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Records that share a name but have different member IDs will '
              'appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: c.ink3, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(ConvocationColors c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Text(
        _error ?? 'Something went wrong.',
        style: TextStyle(color: c.absent, fontSize: 13),
      ),
    );
  }

  Widget _buildGroupCard(ConvocationColors c, DuplicateMemberGroup group) {
    final included = _included.contains(group.key);
    final targetId =
        _targetByGroup[group.key] ?? group.suggestedTarget.member.id;
    return Container(
      key: ValueKey('duplicate_group_${group.key}'),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      decoration: BoxDecoration(
        color: c.cardSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  group.displayName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                  ),
                ),
              ),
              Checkbox(
                key: ValueKey('duplicate_include_${group.key}'),
                value: included,
                activeColor: c.primary,
                onChanged: (value) => _setIncluded(group, value ?? false),
              ),
            ],
          ),
          Text(
            '${group.occurrences.length} member records · choose the one to keep',
            style: TextStyle(fontSize: 11.5, color: c.ink3),
          ),
          const SizedBox(height: 4),
          for (final occurrence in group.occurrences)
            InkWell(
              key: ValueKey(
                'duplicate_target_${group.key}_${occurrence.member.id}',
              ),
              borderRadius: BorderRadius.circular(10),
              onTap: () => _selectTarget(group, occurrence.member.id),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Radio<String>(
                      value: occurrence.member.id,
                      groupValue: targetId,
                      activeColor: c.primary,
                      onChanged: (value) {
                        if (value != null) _selectTarget(group, value);
                      },
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            occurrence.isLoner
                                ? 'Loner'
                                : occurrence.family.displayName,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: c.ink,
                            ),
                          ),
                          Text(
                            '${occurrence.linkedMarkCount} linked mark'
                            '${occurrence.linkedMarkCount == 1 ? '' : 's'}'
                            ' · ID ${_shortId(occurrence.member.id)}',
                            style: TextStyle(fontSize: 11.5, color: c.ink3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (group.unlinkedMarkCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '${group.unlinkedMarkCount} name-only mark'
                '${group.unlinkedMarkCount == 1 ? '' : 's'} '
                'without a member ID will not be touched.',
                style: TextStyle(fontSize: 11.5, color: c.ink3),
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: ValueKey('duplicate_dismiss_${group.key}'),
              onPressed: () => _dismiss(group),
              child: Text(
                'Not an issue',
                style: TextStyle(fontSize: 12, color: c.ink3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(ConvocationColors c) {
    final result = _result;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null)
          Container(
            key: const ValueKey('duplicate_cleanup_error'),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.absent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _error!,
              style: TextStyle(color: c.absent, fontSize: 12.5),
            ),
          ),
        if (result == null)
          OutlinedButton.icon(
            key: const ValueKey('duplicate_cleanup_dry_run'),
            onPressed: _runDryRun,
            icon: const Icon(Icons.analytics_outlined, size: 18),
            label: const Text('Calculate Dry Run'),
            style: OutlinedButton.styleFrom(
              foregroundColor: c.primary,
              side: BorderSide(color: c.primary.withValues(alpha: 0.4)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          )
        else ...[
          Container(
            key: const ValueKey('duplicate_cleanup_results'),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.cardSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle_outline,
                        color: c.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Dry-Run Validation Preview',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: c.ink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _resultRow(c, 'Duplicate profiles removed:',
                    '${result.rosterMembersRemoved}'),
                _resultRow(
                    c, 'Past sessions affected:', '${result.sessionsAffected}'),
                _resultRow(
                    c, 'Historical marks updated:', '${result.marksUpdated}'),
                if (result.collisionsPruned > 0)
                  _resultRow(
                    c,
                    'Intra-session collisions pruned:',
                    '${result.collisionsPruned}',
                    highlight: const Color(0xFFD97706),
                  ),
                if (result.affectedSessionTitles.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Sample sessions affected:',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: c.ink3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  ...result.affectedSessionTitles.take(3).map(
                        (title) => Text(
                          '• $title',
                          style: TextStyle(fontSize: 11.5, color: c.ink2),
                        ),
                      ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            key: const ValueKey('duplicate_cleanup_apply'),
            onPressed: _applying ? null : _apply,
            icon: _applying
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.done_all, size: 18),
            label: Text(
              _applying
                  ? 'Applying...'
                  : 'Confirm & Apply (${result.totalOperations} changes)',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: c.primary,
              foregroundColor: c.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ],
    );
  }

  Widget _resultRow(
    ConvocationColors c,
    String label,
    String value, {
    Color? highlight,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12.5, color: c.ink2)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: highlight ?? c.ink,
            ),
          ),
        ],
      ),
    );
  }

  static String _shortId(String id) =>
      id.length > 10 ? '${id.substring(0, 8)}…' : id;
}
