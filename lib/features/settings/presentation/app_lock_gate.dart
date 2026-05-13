import 'package:flutter/material.dart';

import '../application/app_lock_controller.dart';

/// Wraps [child] and overlays a lock screen when [controller] is locked.
class AppLockGate extends StatefulWidget {
  const AppLockGate({
    super.key,
    required this.controller,
    required this.child,
  });

  final AppLockController controller;
  final Widget child;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> {
  bool _promptInFlight = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybePrompt());
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (!mounted) return;
    setState(() {});
    _maybePrompt();
  }

  Future<void> _maybePrompt() async {
    if (_promptInFlight) return;
    if (!widget.controller.isLocked) return;
    if (widget.controller.isAuthenticating) return;
    _promptInFlight = true;
    try {
      await widget.controller.unlock();
    } finally {
      _promptInFlight = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (widget.controller.isLocked)
          _LockOverlay(
            isAuthenticating: widget.controller.isAuthenticating,
            onUnlock: _maybePrompt,
          ),
      ],
    );
  }
}

class _LockOverlay extends StatelessWidget {
  const _LockOverlay({
    required this.isAuthenticating,
    required this.onUnlock,
  });

  final bool isAuthenticating;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      color: colorScheme.surface,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lock_outline,
                    size: 40,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Attendance is locked',
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Authenticate to continue',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: isAuthenticating ? null : onUnlock,
                  icon: const Icon(Icons.fingerprint),
                  label: Text(isAuthenticating ? 'Authenticating…' : 'Unlock'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
