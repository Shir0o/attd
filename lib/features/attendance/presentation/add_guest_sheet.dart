import 'package:flutter/material.dart';

import '../../../core/design/app_radii.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/widgets/conv_widgets.dart';
import '../models/family.dart';
import '../models/member.dart';

/// The control that submitted an [AddMemberSheet].
enum AddMemberSheetControl { addToRoster, markGuest, existingMember }

/// What an [AddMemberSheet] pops with on submit, so its opener can start a
/// landing flight from the control that was used (#222 M3). A cancel pops with
/// null.
class AddMemberSheetResult {
  const AddMemberSheetResult({required this.control, required this.rect});

  final AddMemberSheetControl control;

  /// The control's global rect when it was used. A keyboard submit reports the
  /// "Add to roster" pill.
  final Rect rect;
}

/// "Add someone" — adds a person to the session on the spot, always as here.
///
/// Typing a name suggests matching people from the Member Directory; tapping
/// one marks them here straight away (joining the Event Roster if they are not
/// on it). Anyone else is someone new, added either to the roster or as a
/// guest by the two submit pills.
class AddMemberSheet extends StatefulWidget {
  const AddMemberSheet({
    super.key,
    required this.onAdd,
    this.availableMembers = const [],
    this.families = const [],
    this.rosterMemberIds,
    this.disableAnimations = false,
  });

  final void Function(
    String name,
    bool isPresent,
    bool isGuest,
    Member? existingMember,
  ) onAdd;
  final List<Member> availableMembers;
  final List<Family> families;

  /// Ids on this event's roster. When given, each suggestion says whether
  /// the person is already on this event.
  final Set<String>? rosterMemberIds;

  /// The host page's test/override flag for decorative motion.
  final bool disableAnimations;

  @override
  State<AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends State<AddMemberSheet> {
  final _nameController = TextEditingController();
  final _nameFocus = FocusNode();
  final _rosterPill = GlobalKey();
  final _guestPill = GlobalKey();

  /// The morph sheet's entrance while it forms; null for a plain sheet.
  late final Animation<double>? _forming;

  @override
  void initState() {
    super.initState();
    // A morph sheet forms first and the keyboard rises after (#222 M1).
    _forming = convMorphSheetFormingOf(context)
      ?..addStatusListener(_focusOnceFormed);
  }

  void _focusOnceFormed(AnimationStatus status) {
    if (!status.isCompleted) return;
    _forming!.removeStatusListener(_focusOnceFormed);
    _nameFocus.requestFocus();
  }

  @override
  void dispose() {
    _forming?.removeStatusListener(_focusOnceFormed);
    _nameFocus.dispose();
    _nameController.dispose();
    super.dispose();
  }

  static Rect _globalRect(BuildContext context) {
    final box = context.findRenderObject()! as RenderBox;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  void _addNew({required bool asGuest}) {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    widget.onAdd(name, true, asGuest, null);
    Navigator.of(context).pop(
      AddMemberSheetResult(
        control: asGuest
            ? AddMemberSheetControl.markGuest
            : AddMemberSheetControl.addToRoster,
        rect: _globalRect((asGuest ? _guestPill : _rosterPill).currentContext!),
      ),
    );
  }

  void _addExisting(Member member, Rect rowRect) {
    widget.onAdd(member.displayName, true, false, member);
    Navigator.of(context).pop(
      AddMemberSheetResult(
        control: AddMemberSheetControl.existingMember,
        rect: rowRect,
      ),
    );
  }

  String _subtitleFor(Member member, Map<String, String> memberFamilyMap) {
    final household = memberFamilyMap[member.id] ?? 'Loner';
    final roster = widget.rosterMemberIds;
    if (roster == null) return household;
    return roster.contains(member.id)
        ? '$household · on this event'
        : '$household · not on this event';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.conv;

    // Deduplicate available members by ID
    final seenIds = <String>{};
    final uniqueMembers = <Member>[];
    for (final m in widget.availableMembers) {
      if (m.deletedAt == null && (m.id.isEmpty || seenIds.add(m.id))) {
        uniqueMembers.add(m);
      }
    }

    final memberFamilyMap = <String, String>{};
    for (final f in widget.families) {
      for (final m in f.members) {
        if (!f.isAutoSingleton && f.displayName.isNotEmpty) {
          memberFamilyMap[m.id] = f.displayName;
        }
      }
    }

    final query = _nameController.text.toLowerCase().trim();
    final suggestions = query.isEmpty
        ? <Member>[]
        : uniqueMembers
            .where((m) => m.displayName.toLowerCase().contains(query))
            .take(3)
            .toList();
    final firstName = _nameController.text.trim().split(RegExp(r'\s+')).first;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: AppRadii.sheetR,
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.hair,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Add someone',
                style: AppTypography.fraunces(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: c.ink,
                ),
              ),
              const SizedBox(height: 16),
              const ConvEyebrow('Name'),
              const SizedBox(height: 6),
              TextField(
                key: const Key('addSheetNameField'),
                controller: _nameController,
                focusNode: _nameFocus,
                autofocus: _forming == null,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                style: AppTypography.geist(fontSize: 17, color: c.ink),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _addNew(asGuest: false),
                decoration: InputDecoration(
                  hintText: 'Full name',
                  hintStyle: AppTypography.geist(fontSize: 17, color: c.ink3),
                  filled: true,
                  fillColor: c.cardSoft,
                  border: OutlineInputBorder(
                    borderRadius: AppRadii.softR,
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
              ),
              if (suggestions.isNotEmpty) ...[
                const SizedBox(height: 16),
                const ConvEyebrow('Already in your members · tap to mark here'),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: c.bg2,
                    borderRadius: AppRadii.tileR,
                  ),
                  child: Column(
                    children: [
                      for (final member in suggestions)
                        _SuggestionRow(
                          key: Key('addSheetSuggestion_${member.id}'),
                          member: member,
                          subtitle: _subtitleFor(member, memberFamilyMap),
                          onTap: (rect) => _addExisting(member, rect),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const ConvEyebrow('Someone new'),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    key: _rosterPill,
                    child: _SubmitPill(
                      key: const Key('addSheetAddToRoster'),
                      label: 'Add to roster',
                      filled: true,
                      disableAnimations: widget.disableAnimations,
                      onTap: () => _addNew(asGuest: false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    key: _guestPill,
                    child: _SubmitPill(
                      key: const Key('addSheetMarkGuest'),
                      label: 'Mark as guest',
                      filled: false,
                      onTap: () => _addNew(asGuest: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                firstName.isEmpty
                    ? 'Either way, they are marked here.'
                    : 'Either way, $firstName is marked here.',
                textAlign: TextAlign.center,
                style: AppTypography.geist(fontSize: 12, color: c.ink3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({
    super.key,
    required this.member,
    required this.subtitle,
    required this.onTap,
  });

  final Member member;
  final String subtitle;

  /// Receives the row's global rect.
  final ValueChanged<Rect> onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadii.compactR,
        onTap: () => onTap(_AddMemberSheetState._globalRect(context)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: c.cardSoft,
                  child: Text(
                    member.displayName.isEmpty
                        ? '?'
                        : member.displayName[0].toUpperCase(),
                    style: AppTypography.geist(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.displayName,
                        style: AppTypography.geist(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: c.ink,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: AppTypography.geist(fontSize: 12, color: c.ink3),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.add_rounded, color: c.primary, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SubmitPill extends StatelessWidget {
  const _SubmitPill({
    super.key,
    required this.label,
    required this.filled,
    required this.onTap,
    this.disableAnimations = false,
  });

  final String label;
  final bool filled;
  final VoidCallback onTap;
  final bool disableAnimations;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    final pill = Material(
      color: filled ? c.primary : c.cardSoft,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: SizedBox(
          height: 52,
          child: Center(
            child: Text(
              label,
              style: AppTypography.geist(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: filled ? c.onPrimary : c.primary,
              ),
            ),
          ),
        ),
      ),
    );
    // Only the filled violet pill presses in; the tonal one stays flat.
    return filled
        ? ConvPressable(disableAnimations: disableAnimations, child: pill)
        : pill;
  }
}
