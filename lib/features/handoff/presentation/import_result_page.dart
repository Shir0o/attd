import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/design/app_typography.dart';
import '../../../core/design/widgets/conv_widgets.dart';
import '../data/handoff_service.dart';
import '../domain/handoff_file.dart';
import 'handoff_widgets.dart';

/// The owner's first look at a result file: who marked, how many were
/// present, any guests. Nothing changes until "Add to session".
class ImportResultPage extends StatefulWidget {
  const ImportResultPage({
    super.key,
    required this.result,
    required this.service,
    this.disableAnimations = false,
  });

  final HandoffResult result;
  final HandoffService service;
  final bool disableAnimations;

  @override
  State<ImportResultPage> createState() => _ImportResultPageState();
}

class _ImportResultPageState extends State<ImportResultPage> {
  bool _loading = true;
  ResultPreview? _preview;
  String? _refusal;
  bool _applying = false;
  ResultImportOutcome? _outcome;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final started = DateTime.now();
    ResultPreview? preview;
    String? refusal;
    try {
      preview = await widget.service.preview(widget.result);
    } on HandoffFormatException catch (e) {
      refusal = e.message;
    }
    final remaining =
        handoffSkeletonMinimum - DateTime.now().difference(started);
    if (remaining > Duration.zero && !widget.disableAnimations) {
      await Future<void>.delayed(remaining);
    }
    if (!mounted) return;
    setState(() {
      _preview = preview;
      _refusal = refusal;
      _loading = false;
    });
  }

  Future<void> _apply() async {
    setState(() => _applying = true);
    try {
      final outcome = await widget.service.apply(widget.result);
      if (!mounted) return;
      setState(() => _outcome = outcome);
    } on HandoffFormatException catch (e) {
      if (!mounted) return;
      setState(() {
        _refusal = e.message;
        _preview = null;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not add the marks. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        title: const ConvEyebrow('Marks from a helper'),
      ),
      body: SafeArea(
        child: SkeletonSwitcher(
          loading: _loading,
          disableAnimations: widget.disableAnimations,
          skeleton:
              HandoffSkeleton(disableAnimations: widget.disableAnimations),
          // Built only once loaded: [SkeletonSwitcher] takes the child eagerly.
          child: _loading
              ? const SizedBox.shrink()
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                  child: _content(context),
                ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final c = context.conv;
    final refusal = _refusal;
    if (refusal != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HandoffMessage(
            title: 'Nothing was added',
            body: refusal,
            icon: Icons.block_outlined,
          ),
          const SizedBox(height: 24),
          _closeButton(filled: true),
        ],
      );
    }
    final preview = _preview!;
    final result = widget.result;
    final date = DateFormat('EEEE, MMM d, yyyy').format(result.sessionDate);

    final outcome = _outcome;
    if (outcome != null) {
      final body = !outcome.changed
          ? 'These marks were already in the session, so nothing new was '
              'added.'
          : outcome.sessionCreated
              ? 'A session for $date was created with these marks.'
              : 'The marks were merged into the session for $date.';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HandoffMessage(
            title: outcome.changed ? 'Added to session' : 'Already added',
            body: body,
            icon: Icons.check_circle_outline,
          ),
          const SizedBox(height: 24),
          _closeButton(filled: true, label: 'Done'),
        ],
      );
    }

    final helper = result.helperName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConvEyebrow(date),
        const SizedBox(height: 8),
        Text(
          preview.event.title,
          style: AppTypography.fraunces(
            fontSize: 30,
            fontWeight: FontWeight.w600,
            color: c.ink,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          helper == null
              ? 'Marked by someone who gave no name.'
              : 'Marked by $helper.',
          style: AppTypography.geist(fontSize: 15, color: c.ink2, height: 1.45),
        ),
        const SizedBox(height: 24),
        HandoffStatRow(
          present: result.presentCount,
          absent: result.absentCount,
          guests: result.guestCount,
        ),
        const SizedBox(height: 16),
        Text(
          'Nothing changes until you add them. Present beats absent if you '
          'already marked someone, and the helper is recorded as who marked '
          'these.',
          style: AppTypography.geist(fontSize: 13, color: c.ink3, height: 1.45),
        ),
        const SizedBox(height: 24),
        FilledButton(
          key: const Key('addToSessionButton'),
          onPressed: _applying ? null : _apply,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: const Text('Add to session'),
        ),
        const SizedBox(height: 8),
        _closeButton(filled: false),
      ],
    );
  }

  Widget _closeButton({required bool filled, String label = 'Cancel'}) {
    final child = Text(filled && label == 'Cancel' ? 'Close' : label);
    void close() => Navigator.of(context).pop();
    final size = Size.fromHeight(filled ? 52 : 48);
    return filled
        ? FilledButton(
            key: const Key('closeHandoffButton'),
            onPressed: close,
            style: FilledButton.styleFrom(minimumSize: size),
            child: child,
          )
        : TextButton(
            key: const Key('cancelImportButton'),
            onPressed: close,
            style: TextButton.styleFrom(minimumSize: size),
            child: child,
          );
  }
}
