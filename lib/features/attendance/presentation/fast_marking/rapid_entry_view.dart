import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/conv_widgets.dart';
import '../../models/member.dart';
import '../../utils/session_roster_utils.dart';
import 'fast_marking_model.dart';
import 'fast_marking_shared.dart';

/// Fast marking by typing: the search field is anchored to the bottom so it
/// sits on top of the keyboard rather than behind it, keeps focus for the whole
/// session, and clears itself after every mark. Results grow upward towards the
/// field, and the return key marks the top hit when it is unambiguous.
class RapidEntryView extends StatefulWidget {
  const RapidEntryView({
    super.key,
    required this.roster,
    required this.onToggle,
    required this.onAddGuest,
    this.onDismiss,
  });

  final FastMarkingRoster roster;
  final MemberMarkCallback onToggle;
  final VoidCallback onAddGuest;

  /// Rendered as a "Back" chip when this view is opened as an overlay from
  /// another surface (the Likely here grid).
  final VoidCallback? onDismiss;

  @override
  State<RapidEntryView> createState() => _RapidEntryViewState();
}

class _RapidEntryViewState extends State<RapidEntryView> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final List<MarkedEntry> _justMarked = [];
  String _query = '';

  static const int _maxResults = 4;
  static const int _maxUndo = 3;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<SearchEntry> get _results {
    final all = rankedSearch(
      widget.roster.searchEntries,
      _query,
      priority: widget.roster.likelihoodPriority,
    );
    return all.length > _maxResults ? all.sublist(0, _maxResults) : all;
  }

  /// True when the return key should act: either a single result, or a top hit
  /// that matches strictly better than the runner-up.
  bool _isUnambiguous(List<SearchEntry> results) {
    if (results.length == 1) return true;
    if (results.length < 2) return false;
    final first = searchRank(results[0], _query);
    final second = searchRank(results[1], _query);
    if (first == null || second == null) return false;
    return first < second;
  }

  Future<void> _mark(Member member) async {
    final wasPresent = widget.roster.isPresent(member);
    await widget.onToggle(member, !wasPresent);
    if (!mounted) return;
    setState(() {
      pushMark(_justMarked, member, wasPresent, limit: _maxUndo);
      _controller.clear();
      _query = '';
    });
    // The whole point of this surface: the keyboard never closes and the
    // caret is ready for the next name before the mark has finished saving.
    _focusNode.requestFocus();
    unawaited(HapticFeedback.selectionClick());
  }

  Future<void> _undo(MarkedEntry entry) async {
    await widget.onToggle(entry.member, entry.previousPresent);
    if (!mounted) return;
    setState(() => _justMarked.remove(entry));
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    final results = _results;
    final unambiguous = _isUnambiguous(results);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.onDismiss != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConvPill(
                key: const Key('rapidEntryBack'),
                label: 'Back to the grid',
                ghost: true,
                leading: const Icon(Icons.arrow_back_rounded),
                onTap: widget.onDismiss,
              ),
            ),
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                JustMarkedStack(entries: _justMarked, onUndo: _undo),
                if (_justMarked.isNotEmpty) const SizedBox(height: 16),
                if (_query.isNotEmpty && results.isEmpty)
                  AddGuestRow(query: _query, onTap: widget.onAddGuest)
                else if (results.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      results.length == 1
                          ? '1 MATCH'
                          : '${results.length} MATCHES',
                      style: AppTypography.eyebrow(color: c.ink3),
                    ),
                  ),
                  for (var i = 0; i < results.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: FastMarkingRow(
                        key: Key(
                          'fastMarkingResult_${results[i].member.id}',
                        ),
                        member: results[i].member,
                        isPresent: widget.roster.isPresent(results[i].member),
                        subtitle: widget.roster.subtitleFor(results[i].member),
                        query: _query,
                        isTopHit: i == 0 && unambiguous,
                        onTap: () => _mark(results[i].member),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        MarkingSearchField(
          fieldKey: const Key('rapidEntryField'),
          controller: _controller,
          focusNode: _focusNode,
          hintText: 'Type a name',
          caption: 'Return marks the top hit. The field clears itself.',
          onChanged: (v) => setState(() => _query = v),
          onClear: () {
            _controller.clear();
            setState(() => _query = '');
            _focusNode.requestFocus();
          },
          onSubmitted: () {
            if (results.isNotEmpty && unambiguous) _mark(results.first.member);
          },
        ),
      ],
    );
  }
}
