import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// First-launch onboarding gate (Phase 9). Null while the flag loads,
/// false on a fresh install, true once the user taps "Get started".
class OnboardingController extends Notifier<bool?> {
  static const String prefKey = 'onboarding_seen';

  @override
  bool? build() {
    _loadSaved();
    return null;
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(prefKey) ?? false;
  }

  Future<void> markSeen() async {
    state = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefKey, true);
  }
}

final onboardingProvider =
    NotifierProvider<OnboardingController, bool?>(OnboardingController.new);
