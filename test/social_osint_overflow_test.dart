import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safesignal/features/osint/social_osint_screen.dart';

void main() {
  testWidgets('SocialOsintScreen Username OSINT renders cleanly with zero RenderFlex overflows on 360x800 viewport', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: SocialOsintScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Title and Subtitle in AppBar
    expect(find.text('Digital OSINT Suite'), findsOneWidget);
    expect(find.text('Public Handles & Profile Intel'), findsOneWidget);

    // Verify Search Card elements
    expect(find.text('Digital Identity Recon'), findsOneWidget);
    expect(find.text('Cross-platform handle & footprint scanner'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    // Verify quick sample handle chips
    expect(find.text('@uf_times'), findsOneWidget);
    expect(find.text('@torvalds'), findsOneWidget);
    expect(find.text('@spez'), findsOneWidget);
    expect(find.text('@carryminati'), findsOneWidget);

    // Verify no TabBar or Phone Recon text is present
    expect(find.text('Phone Recon'), findsNothing);
    expect(find.text('Global Telecom & Number OSINT'), findsNothing);
  });
}
