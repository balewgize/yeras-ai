import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yeras_ai/main.dart';

void main() {
  group('first-launch onboarding', () {
    testWidgets('fresh install shows onboarding before home',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await tester.pumpWidget(const ProviderScope(child: YerasAIApp()));
      await tester.pumpAndSettle();

      expect(find.text('Get started'), findsOneWidget);
      expect(find.text('How can I help?'), findsNothing);

      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();

      // Dismissed for good: home shows and the flag persists.
      expect(find.text('How can I help?'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('onboarding_seen'), isTrue);
    });

    testWidgets('seen flag skips straight to home',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'onboarding_seen': true,
      });
      await tester.pumpWidget(const ProviderScope(child: YerasAIApp()));
      await tester.pumpAndSettle();

      expect(find.text('Get started'), findsNothing);
      expect(find.text('How can I help?'), findsOneWidget);
    });
  });
}
