import 'package:flutter/material.dart';

import '../../../core/design/app_shimmer.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/widgets/conv_widgets.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../attendance/models/family.dart';
import '../../attendance/models/member.dart';

class DuplicateGroup {
  DuplicateGroup({
    required this.displayName,
    required this.occurrences,
  });

  final String displayName;
  final List<DuplicateOccurrence> occurrences;
}

class DuplicateOccurrence {
  DuplicateOccurrence({
    required this.family,
    required this.member,
  });

  final Family family;
  final Member member;
}

enum ResolutionType { keepOne, removeSpecific, renameSpecific, none }

class DuplicateResolution {
  DuplicateResolution({
    required this.group,
    this.type = ResolutionType.none,
    this.targetOccurrence,
    this.renameValue,
  });

  final DuplicateGroup group;
  ResolutionType type;
  DuplicateOccurrence? targetOccurrence; // Used for keepOne (the one to keep), removeSpecific, renameSpecific
  String? renameValue;
}

class ResolveDuplicatesPage extends StatefulWidget {
  const ResolveDuplicatesPage({
    super.key,
    required this.repository,
    this.disableAnimations = false,
  });

  final AttendanceRepository repository;
  final bool disableAnimations;

  @override
  State<ResolveDuplicatesPage> createState() => _ResolveDuplicatesPageState();
}

class _ResolveDuplicatesPageState extends State<ResolveDuplicatesPage> {
  late Future<List<DuplicateGroup>> _duplicatesFuture;
  final List<DuplicateResolution> _resolutions = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadDuplicates();
  }

  void _loadDuplicates() {
    setState(() {
      _duplicatesFuture = _fetchDuplicates();
    });
  }

  Future<List<DuplicateGroup>> _fetchDuplicates() async {
    final results = await Future.wait([
      widget.repository.fetchFamilies(),
      if (!widget.disableAnimations)
        Future.delayed(const Duration(milliseconds: 800)),
    ]);

    final families = results.first as List<Family>;
    final realFamilies = families.where((f) => !f.isAutoSingleton).toList();

    // Map display name -> occurrences
    final nameToOccurrences = <String, List<DuplicateOccurrence>>{};
    for (final f in realFamilies) {
      for (final m in f.members) {
        if (m.deletedAt != null) continue;
        nameToOccurrences.putIfAbsent(m.displayName, () => []).add(
              DuplicateOccurrence(family: f, member: m),
            );
      }
    }

    final groups = <DuplicateGroup>[];
    for (final entry in nameToOccurrences.entries) {
      if (entry.value.length > 1) {
        groups.add(DuplicateGroup(
          displayName: entry.key,
          occurrences: entry.value,
        ));
      }
    }

    // Initialize resolution states
    _resolutions.clear();
    for (final g in groups) {
      _resolutions.add(DuplicateResolution(group: g));
    }

    return groups;
  }

  Future<void> _promptRename(
    DuplicateResolution res,
    DuplicateOccurrence occ,
  ) async {
    final controller = TextEditingController(
      text: res.renameValue ?? occ.member.displayName,
    );
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Rename Member'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Distinguishing Name',
              hintText: 'e.g. John Doe Jr.',
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
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (newName != null && newName.isNotEmpty && newName != occ.member.displayName) {
      setState(() {
        res.type = ResolutionType.renameSpecific;
        res.targetOccurrence = occ;
        res.renameValue = newName;
      });
    }
  }

  Future<void> _save() async {
    final activeResolutions = _resolutions
        .where((r) => r.type != ResolutionType.none)
        .toList();

    if (activeResolutions.isEmpty) {
      Navigator.of(context).pop(false);
      return;
    }

    setState(() => _saving = true);

    try {
      final allFamilies = await widget.repository.fetchFamilies();
      final now = DateTime.now();

      // Apply each resolution to the families list
      var updatedFamilies = List<Family>.from(allFamilies);

      for (final res in activeResolutions) {
        switch (res.type) {
          case ResolutionType.keepOne:
            final keepOcc = res.targetOccurrence!;
            final name = res.group.displayName;

            updatedFamilies = updatedFamilies.map((family) {
              // If it is the family we want to keep it in, do nothing
              if (family.id == keepOcc.family.id) return family;

              // Otherwise, remove the duplicate member with the same display name
              final filtered = family.members
                  .where((m) => m.displayName != name)
                  .toList();
              
              if (filtered.length != family.members.length) {
                return family.copyWith(members: filtered, updatedAt: now);
              }
              return family;
            }).toList();
            break;

          case ResolutionType.removeSpecific:
            final removeOcc = res.targetOccurrence!;
            updatedFamilies = updatedFamilies.map((family) {
              if (family.id != removeOcc.family.id) return family;
              final filtered = family.members
                  .where((m) => m.id != removeOcc.member.id)
                  .toList();
              return family.copyWith(members: filtered, updatedAt: now);
            }).toList();
            break;

          case ResolutionType.renameSpecific:
            final renameOcc = res.targetOccurrence!;
            updatedFamilies = updatedFamilies.map((family) {
              if (family.id != renameOcc.family.id) return family;
              final updatedMembers = family.members.map((m) {
                if (m.id == renameOcc.member.id) {
                  return m.copyWith(
                    displayName: res.renameValue!,
                    updatedAt: now,
                  );
                }
                return m;
              }).toList();
              return family.copyWith(members: updatedMembers, updatedAt: now);
            }).toList();
            break;

          case ResolutionType.none:
            break;
        }
      }

      // Save changes back to repository
      await widget.repository.saveFamilies(updatedFamilies);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error resolving duplicates: $e')),
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
          'Resolve Duplicate Members',
          style: AppTypography.eyebrow(color: c.ink3),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<List<DuplicateGroup>>(
        future: _duplicatesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildSkeleton(context);
          }

          final groups = snapshot.data ?? [];
          if (groups.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No duplicate display names found!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.ink2),
                ),
              ),
            );
          }

          final resolvedCount = _resolutions.where((r) => r.type != ResolutionType.none).length;

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
                          'DUPLICATES FOUND',
                          style: AppTypography.eyebrow(color: c.absent),
                        ),
                        const SizedBox(height: 6),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '${groups.length} duplicates',
                                style: TextStyle(color: c.absent),
                              ),
                              const TextSpan(text: ' detected.'),
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
                          'Decide which family each member truly belongs in, or rename them to distinguish them if they are separate people.',
                          style: TextStyle(fontSize: 14, color: c.ink2),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                  for (var i = 0; i < groups.length; i++) ...[
                    _buildDuplicateCard(_resolutions[i]),
                    const SizedBox(height: 14),
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
                          onPressed: _saving || resolvedCount == 0 ? null : _save,
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
                              : Text(
                                  resolvedCount > 0
                                      ? 'Apply $resolvedCount ${resolvedCount == 1 ? 'Resolution' : 'Resolutions'}'
                                      : 'Resolve Duplicates',
                                  style: const TextStyle(
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

  Widget _buildDuplicateCard(DuplicateResolution res) {
    final c = context.conv;
    final group = res.group;

    String actionText = 'No resolution selected';
    Color actionColor = c.ink3;

    switch (res.type) {
      case ResolutionType.keepOne:
        actionText = 'Keep only in ${res.targetOccurrence!.family.displayName}';
        actionColor = c.primary;
        break;
      case ResolutionType.removeSpecific:
        actionText = 'Remove from ${res.targetOccurrence!.family.displayName}';
        actionColor = c.absent;
        break;
      case ResolutionType.renameSpecific:
        actionText = 'Rename to: "${res.renameValue}" in ${res.targetOccurrence!.family.displayName}';
        actionColor = c.clayDeep;
        break;
      case ResolutionType.none:
        break;
    }

    final letter = group.displayName.isEmpty ? '?' : group.displayName.characters.first.toUpperCase();

    return ConvCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ConvAvatar(letter: letter, tone: ConvTone.absent),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.displayName,
                      style: AppTypography.fraunces(
                        fontSize: 20,
                        fontWeight: FontWeight.w400,
                        color: c.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Found in ${group.occurrences.length} families',
                      style: TextStyle(fontSize: 12, color: c.ink3),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'ASSIGNED FAMILIES',
            style: AppTypography.eyebrow(color: c.ink3),
          ),
          const SizedBox(height: 8),
          for (final occ in group.occurrences) ...[
            _buildOccurrenceRow(res, occ),
            const SizedBox(height: 8),
          ],
          const Divider(height: 24),
          Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: actionColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  actionText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: actionColor,
                  ),
                ),
              ),
              if (res.type != ResolutionType.none)
                TextButton(
                  onPressed: () {
                    setState(() {
                      res.type = ResolutionType.none;
                      res.targetOccurrence = null;
                      res.renameValue = null;
                    });
                  },
                  child: const Text('Reset', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOccurrenceRow(DuplicateResolution res, DuplicateOccurrence occ) {
    final c = context.conv;
    final isKept = res.type == ResolutionType.keepOne && res.targetOccurrence == occ;
    final isRemoved = res.type == ResolutionType.removeSpecific && res.targetOccurrence == occ;
    final isRenamed = res.type == ResolutionType.renameSpecific && res.targetOccurrence == occ;

    TextStyle textStyle = TextStyle(color: c.ink, fontSize: 14, fontWeight: FontWeight.w500);
    if (isRemoved) {
      textStyle = textStyle.copyWith(decoration: TextDecoration.lineThrough, color: c.ink3);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isKept
            ? Color.alphaBlend(c.primary.withValues(alpha: 0.08), c.card)
            : isRemoved
                ? Color.alphaBlend(c.absent.withValues(alpha: 0.08), c.card)
                : c.cardSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.family_restroom, size: 16, color: isKept ? c.primary : c.ink3),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  occ.family.displayName,
                  style: textStyle,
                ),
                if (isRenamed)
                  Text(
                    'Renamed to: ${res.renameValue}',
                    style: TextStyle(fontSize: 11, color: c.clayDeep, fontWeight: FontWeight.w500),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, size: 18, color: c.ink3),
            color: c.bg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (val) {
              if (val == 'keep') {
                setState(() {
                  res.type = ResolutionType.keepOne;
                  res.targetOccurrence = occ;
                  res.renameValue = null;
                });
              } else if (val == 'remove') {
                setState(() {
                  res.type = ResolutionType.removeSpecific;
                  res.targetOccurrence = occ;
                  res.renameValue = null;
                });
              } else if (val == 'rename') {
                _promptRename(res, occ);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'keep',
                child: Text('Keep only here', style: TextStyle(color: c.ink)),
              ),
              PopupMenuItem(
                value: 'remove',
                child: Text('Remove from this family', style: TextStyle(color: c.absent)),
              ),
              PopupMenuItem(
                value: 'rename',
                child: Text('Rename to distinguish', style: TextStyle(color: c.ink)),
              ),
            ],
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
        for (var i = 0; i < 2; i++) ...[
          AppShimmer(
            width: double.infinity,
            height: 200,
            borderRadius: BorderRadius.circular(22),
            disableAnimations: widget.disableAnimations,
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}
