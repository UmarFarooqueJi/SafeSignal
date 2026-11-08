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

    // Test Sample 1: CBI Warrant
    final cbiChip = find.text('🏛️ CBI Warrant');
    expect(cbiChip, findsOneWidget);
    await tester.tap(cbiChip);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Scroll through all cards
    final scrollFinder = find.byType(SingleChildScrollView).first;
    await tester.drag(scrollFinder, const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.drag(scrollFinder, const Offset(0, -600));
    await tester.pumpAndSettle();

    // Test Sample 2: Catfish Avatar (Biometric Radar card)
    await tester.drag(scrollFinder, const Offset(0, 1200));
    await tester.pumpAndSettle();
    final catfishChip = find.text('👤 Catfish Avatar');
    expect(catfishChip, findsOneWidget);
    await tester.ensureVisible(catfishChip);
    await tester.pumpAndSettle();
    await tester.tap(catfishChip);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.drag(scrollFinder, const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.drag(scrollFinder, const Offset(0, -600));
    await tester.pumpAndSettle();

    // Test Sample 3: UPI Payment Receipt
    await tester.drag(scrollFinder, const Offset(0, 1200));
    await tester.pumpAndSettle();
    final upiChip = find.text('💳 UPI Receipt');
    expect(upiChip, findsOneWidget);
    await tester.ensureVisible(upiChip);
    await tester.pumpAndSettle();
    await tester.tap(upiChip);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.drag(scrollFinder, const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.drag(scrollFinder, const Offset(0, -600));
    await tester.pumpAndSettle();
  });
}
