import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingController extends ChangeNotifier {
  OnboardingController(this._prefs) {
    _loadOnboardingStatus();
  }

  final SharedPreferences _prefs;
  static const _onboardingKey = 'onboarding_completed';
  static const _authPromptSeenKey = 'auth_prompt_seen';

  bool _onboardingCompleted = false;
  bool _authPromptSeen = false;

  bool get onboardingCompleted => _onboardingCompleted;
  bool get authPromptSeen => _authPromptSeen;

  bool get shouldShowOnboarding => !_onboardingCompleted;
  bool get shouldShowSignIn => _onboardingCompleted && !_authPromptSeen;

  void _loadOnboardingStatus() {
    _onboardingCompleted = _prefs.getBool(_onboardingKey) ?? false;
    _authPromptSeen = _prefs.getBool(_authPromptSeenKey) ?? false;
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    _onboardingCompleted = true;
    notifyListeners();
    await _prefs.setBool(_onboardingKey, true);
  }

  Future<void> completeSignInPrompt() async {
    _authPromptSeen = true;
    notifyListeners();
    await _prefs.setBool(_authPromptSeenKey, true);
  }
}
