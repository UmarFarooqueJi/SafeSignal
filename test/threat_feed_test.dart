import 'package:flutter_test/flutter_test.dart';
import 'package:safesignal/data/models/alert_model.dart';

void main() {
  group('Threat Intelligence Feed & Offline Advisory Tests', () {
    test(
      'Offline threat advisories contain required authentic Indian advisories',
      () {
        final advisories = AlertModel.offlineThreatAdvisories();
        expect(advisories.isNotEmpty, isTrue);
        expect(advisories.length, greaterThanOrEqualTo(5));

        final digitalArrest = advisories.firstWhere(
          (a) => a.category == 'digital_arrest',
        );
        expect(digitalArrest.headline, contains('Digital Arrest'));
        expect(digitalArrest.summary, contains('1930'));

        final certIn = advisories.firstWhere((a) => a.id.contains('cert_in'));
        expect(certIn.headline, contains('CERT-In'));
        expect(certIn.summary, contains('Accessibility'));

        final upiScam = advisories.firstWhere((a) => a.id.contains('upi'));
        expect(upiScam.summary, contains('UPI PIN'));
      },
    );

    test(
      'AlertModel serializes and deserializes accurately with toJson and fromJson',
      () {
        final now = DateTime.now();
        final alert = AlertModel(
          id: 'test_alert_01',
          headline: 'Test Cybercrime Alert',
          summary: 'Emergency reporting via 1930',
          sourceUrl: 'https://cybercrime.gov.in',
          isTrending: true,
          publishedAt: now,
          category: 'digital_arrest',
          isNew: true,
        );

        final json = alert.toJson();
        final reconstructed = AlertModel.fromJson(json);

        expect(reconstructed.id, equals(alert.id));
        expect(reconstructed.headline, equals(alert.headline));
        expect(reconstructed.summary, equals(alert.summary));
        expect(reconstructed.category, equals(alert.category));
        expect(reconstructed.isTrending, isTrue);
        expect(reconstructed.isNew, isTrue);
      },
    );
  });
}
