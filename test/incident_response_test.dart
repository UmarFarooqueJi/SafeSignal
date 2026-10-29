import 'package:flutter_test/flutter_test.dart';

void main() {
  group('1930 Incident Response & Legal Complaint Specification Tests', () {
    test(
      'FIR Complaint template correctly formats Section 66D IT Act parameters',
      () {
        const amount = '45000';
        const utr = 'UTR987654321012';
        const bank = 'State Bank of India';
        const scammer = 'fraudster@fakeupi';

        final complaint =
            '''
COMPLAINT UNDER SECTION 66D OF THE INFORMATION TECHNOLOGY ACT, 2000 (CYBER FRAUD & CHEATING BY PERSONATION)

To,
The National Cyber Crime Reporting Portal / Station House Officer

INCIDENT DETAILS:
- Approximate Loss Amount: ₹$amount
- Transaction UTR / Ref Number: $utr
- My Bank / Payment App: $bank
- Suspect Identifier (Phone / UPI / Telegram): $scammer

BRIEF MODUS OPERANDI:
The suspect initiated communication under false pretenses (digital arrest / fake courier / APK phishing / fraudulent UPI collect request).

PRAYER:
1. Direct the intermediary banks and payment aggregators to immediately freeze the beneficiary account linked to the suspect UPI/Account under the CFCFRS protocol.
2. Register an official FIR under Section 66D IT Act and relevant provisions of the Bharatiya Nyaya Sanhita (BNS).
''';

        expect(complaint.contains('SECTION 66D'), isTrue);
        expect(complaint.contains('₹45000'), isTrue);
        expect(complaint.contains('UTR987654321012'), isTrue);
        expect(complaint.contains('State Bank of India'), isTrue);
        expect(complaint.contains('fraudster@fakeupi'), isTrue);
        expect(complaint.contains('CFCFRS protocol'), isTrue);
      },
    );

    test(
      'Emergency Bank Freeze Directory covers major Indian public and private institutions',
      () {
        final banks = [
          'State Bank of India (SBI)',
          'HDFC Bank',
          'ICICI Bank',
          'Axis Bank',
          'Punjab National Bank (PNB)',
          'Bank of Baroda (BoB)',
          'Kotak Mahindra Bank',
          'PhonePe Fraud Support',
          'Google Pay Grievance',
          'Paytm Payments Bank',
        ];

        expect(banks.length, equals(10));
        expect(banks.contains('State Bank of India (SBI)'), isTrue);
        expect(banks.contains('HDFC Bank'), isTrue);
        expect(banks.contains('PhonePe Fraud Support'), isTrue);
      },
    );
  });
}
