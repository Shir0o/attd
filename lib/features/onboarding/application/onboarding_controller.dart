import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingController extends ChangeNotifier {
  OnboardingController(this._prefs) {
    _loadOnboardingStatus();
  }

  final SharedPreferences _prefs;
  static const _onboardingKey = 'onboarding_completed';

  bool _onboardingCompleted = false;
  bool get onboardingCompleted => _onboardingCompleted;

  bool get shouldShowOnboarding => !_onboardingCompleted;

  void _loadOnboardingStatus() {
    _onboardingCompleted = _prefs.getBool(_onboardingKey) ?? false;
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    _onboardingCompleted = true;
    notifyListeners();
    await _prefs.setBool(_onboardingKey, true);
  }
}
