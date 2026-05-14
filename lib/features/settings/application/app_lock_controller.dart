import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages biometric/device-credential app lock state.
///
/// Lock triggers: cold start (when enabled) and resume from background after
/// [backgroundLockThreshold] of inactivity.
class AppLockController extends ChangeNotifier {
  AppLockController(
    this._prefs, {
    LocalAuthentication? auth,
    Duration backgroundLockThreshold = const Duration(minutes: 1),
  }) : _auth = auth ?? LocalAuthentication(),
       _backgroundLockThreshold = backgroundLockThreshold {
    _enabled = _prefs.getBool(_enabledKey) ?? false;
    _isLocked = _enabled;
  }

  static const _enabledKey = 'app_lock_enabled';

  final SharedPreferences _prefs;
  final LocalAuthentication _auth;
  final Duration _backgroundLockThreshold;

  bool _enabled = false;
  bool _isLocked = false;
  bool _isAuthenticating = false;
  DateTime? _backgroundedAt;

  bool get isEnabled => _enabled;
  bool get isLocked => _enabled && _isLocked;
  bool get isAuthenticating => _isAuthenticating;

  /// Returns true if the device has biometrics or a device credential set up.
  Future<bool> canUseAppLock() async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return false;
      // canCheckBiometrics is false on devices with only PIN/passcode, but
      // isDeviceSupported + authenticate with biometricOnly:false still works.
      return true;
    } on Object {
      return false;
    }
  }

  /// Enables app lock after a successful authentication probe.
  Future<bool> enable() async {
    final ok = await _authenticate(reason: 'Confirm to enable app lock');
    if (!ok) return false;
    _enabled = true;
    await _prefs.setBool(_enabledKey, true);
    _isLocked = false;
    notifyListeners();
    return true;
  }

  /// Disables app lock after re-authenticating.
  Future<bool> disable() async {
    final ok = await _authenticate(reason: 'Confirm to disable app lock');
    if (!ok) return false;
    _enabled = false;
    _isLocked = false;
    await _prefs.setBool(_enabledKey, false);
    notifyListeners();
    return true;
  }

  /// Called when app is paused/detached.
  void markBackgrounded() {
    _backgroundedAt = DateTime.now();
  }

  /// Called when app resumes. Locks if inactivity exceeds threshold, or if
  /// the app was already locked (e.g. user cancelled the prompt and
  /// backgrounded). Always notifies on resume while locked so the gate can
  /// re-prompt for authentication.
  void onResumed() {
    if (!_enabled) return;
    final at = _backgroundedAt;
    _backgroundedAt = null;
    final shouldLock = _isLocked ||
        (at != null &&
            DateTime.now().difference(at) >= _backgroundLockThreshold);
    if (shouldLock) {
      _isLocked = true;
      notifyListeners();
    }
  }

  /// Prompts for authentication to unlock. Returns true on success.
  Future<bool> unlock() async {
    if (!_enabled || !_isLocked) return true;
    final ok = await _authenticate(reason: 'Unlock Attendance Tracker');
    if (ok) {
      _isLocked = false;
      notifyListeners();
    }
    return ok;
  }

  Future<bool> _authenticate({required String reason}) async {
    if (_isAuthenticating) return false;
    _isAuthenticating = true;
    notifyListeners();
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } on Object {
      return false;
    } finally {
      _isAuthenticating = false;
      notifyListeners();
    }
  }
}
