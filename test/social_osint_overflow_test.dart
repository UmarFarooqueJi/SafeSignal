import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safesignal/features/osint/social_osint_screen.dart';

void main() {
  testWidgets('SocialOsintScreen Phone Recon has zero RenderFlex overflows on 360x800 viewport', (WidgetTester tester) async {
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

    // Verify Phone Recon tab is selected
    expect(find.text('Global Telecom & Number OSINT'), findsOneWidget);

    // Test Sample 1: Digital Arrest Scam
    final digitalArrestChip = find.text('🚨 Digital Arrest Scam');
    expect(digitalArrestChip, findsOneWidget);
    await tester.tap(digitalArrestChip);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Scroll through results
    final scrollFinder = find.byType(SingleChildScrollView).first;
    await tester.drag(scrollFinder, const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.drag(scrollFinder, const Offset(0, -600));
    await tester.pumpAndSettle();

    // Verify UPI Resolution and Spam classification rendered
    expect(find.text('SPAM & FRAUD CLASSIFICATION RADAR'), findsOneWidget);
    expect(find.text('NPCI UPI REVERSE IDENTITY RESOLUTION'), findsOneWidget);

    // Test Sample 2: Twilio VoIP Threat
    await tester.drag(scrollFinder, const Offset(0, 1200));
    await tester.pumpAndSettle();
    final voipChip = find.text('☁️ Twilio VoIP Threat');
    expect(voipChip, findsOneWidget);
    await tester.ensureVisible(voipChip);
    await tester.pumpAndSettle();
    await tester.tap(voipChip);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.drag(scrollFinder, const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.drag(scrollFinder, const Offset(0, -600));
    await tester.pumpAndSettle();

    // Verify VoIP alert rendered
    expect(find.text('VOIP ALERT'), findsOneWidget);

    // Test Sample 3: Clean Enterprise
    await tester.drag(scrollFinder, const Offset(0, 1200));
    await tester.pumpAndSettle();
    final cleanChip = find.text('🏛️ Clean Enterprise (Jio)');
    expect(cleanChip, findsOneWidget);
    await tester.ensureVisible(cleanChip);
    await tester.pumpAndSettle();
    await tester.tap(cleanChip);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.drag(scrollFinder, const Offset(0, -600));
    await tester.pumpAndSettle();
  });
}
