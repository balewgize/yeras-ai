import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/onboarding_providers.dart';
import 'providers/theme_controller.dart';
import 'screens/home/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: YerasAIApp()));
}

class YerasAIApp extends ConsumerWidget {
  const YerasAIApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeControllerProvider);

    return MaterialApp(
      title: 'YerasAI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: const _LaunchGate(),
    );
  }
}

/// Shows the Phase 9 onboarding on first launch, then the home screen.
/// While the flag loads, an empty scaffold avoids flashing either one.
class _LaunchGate extends ConsumerWidget {
  const _LaunchGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seen = ref.watch(onboardingProvider);
    if (seen == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    return seen ? const HomeScreen() : const OnboardingScreen();
  }
}
