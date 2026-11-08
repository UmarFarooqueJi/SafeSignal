import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safesignal/features/osint/social_osint_screen.dart';

void main() {
  testWidgets('SocialOsintScreen has zero RenderFlex overflows on 360x800 viewport', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: SocialOsintScreen(initialTab: 1),
      ),
    );
    await tester.pumpAndSettle();

    // Tap Sample button
    final sampleBtn = find.text('Sample');
    expect(sampleBtn, findsOneWidget);
    await tester.tap(sampleBtn);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Scroll down to test all cards in the scroll view
    final scrollFinder = find.byType(SingleChildScrollView);
    await tester.drag(scrollFinder, const Offset(0, -600));
    await tester.pumpAndSettle();

    await tester.drag(scrollFinder, const Offset(0, -600));
    await tester.pumpAndSettle();
  });
}
