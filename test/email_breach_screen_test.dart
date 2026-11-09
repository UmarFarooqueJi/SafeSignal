import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safesignal/features/email_breach/email_breach_screen.dart';

void main() {
  testWidgets(
    'EmailBreachScreen renders single dedicated Email Breach UI with zero phone elements',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: EmailBreachScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Title & Header
      expect(find.text('Data Breach Check'), findsOneWidget);

      // Verify Email Input field exists
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);

      // Verify Scan Email button
      expect(find.text('Scan Email Breach'), findsOneWidget);

      // Verify Phone Recon elements are completely absent
      expect(find.text('Phone Number'), findsNothing);
      expect(find.text('Phone Intelligence'), findsNothing);
      expect(find.text('Scan Mobile Intelligence'), findsNothing);
      expect(find.text('Carrier'), findsNothing);
    },
  );
}
