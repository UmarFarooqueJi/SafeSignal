import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safesignal/main.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'onboarding_done': true,
      'isLoggedIn': true,
      'isProfileSetupDone': true,
    });
  });

  testWidgets('SafeSignal app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: SafeSignalApp()));
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
