import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingController extends ChangeNotifier {
  OnboardingController(this._prefs) {
    _loadOnboardingStatus();
  }

  final SharedPreferences _prefs;
  static const _onboardingKey = 'onboarding_completed';
  static const _coordinatorAgeAffirmedKey = 'coordinator_age_affirmed';

  bool _onboardingCompleted = false;
  bool get onboardingCompleted => _onboardingCompleted;

  bool _coordinatorAgeAffirmed = false;
  bool get coordinatorAgeAffirmed => _coordinatorAgeAffirmed;

  bool get shouldShowOnboarding => !_onboardingCompleted;

  void _loadOnboardingStatus() {
    _onboardingCompleted = _prefs.getBool(_onboardingKey) ?? false;
    _coordinatorAgeAffirmed = _prefs.getBool(_coordinatorAgeAffirmedKey) ?? false;
    notifyListeners();
  }

  Future<void> setCoordinatorAgeAffirmed(bool affirmed) async {
    _coordinatorAgeAffirmed = affirmed;
    notifyListeners();
    await _prefs.setBool(_coordinatorAgeAffirmedKey, affirmed);
  }

  Future<void> completeOnboarding() async {
    if (!_coordinatorAgeAffirmed) return;
    _onboardingCompleted = true;
    notifyListeners();
    await _prefs.setBool(_onboardingKey, true);
  }
}
