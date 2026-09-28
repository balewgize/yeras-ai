import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:staylocal/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('chat list empty state and navigation to chat screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: StayLocalApp()));
    await tester.pumpAndSettle();

    expect(find.text('No chats yet'), findsOneWidget);

    await tester.tap(find.text('New chat'));
    await tester.pumpAndSettle();

    expect(find.text('No model loaded'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('theme mode switches from settings', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: StayLocalApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
  });

  testWidgets('persisted theme mode is restored on launch',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'theme_mode': 'dark',
    });

    await tester.pumpWidget(const ProviderScope(child: StayLocalApp()));
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
  });
}
