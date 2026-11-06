import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:safesignal/core/services/visual_osint_engine.dart';

void main() {
  group('VisualOsintEngine - Cryptographic & Perceptual Hashing', () {
    test('Calculates accurate SHA-256 and MD5 for raw image bytes', () async {
      final sampleBytes = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG magic
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR
        0x00, 0x00, 0x01, 0x00, // Width 256
        0x00, 0x00, 0x01, 0x00, // Height 256
        0x08, 0x06, 0x00, 0x00, 0x00,
      ]);

      final report = await VisualOsintEngine.calculateHashes(
        sampleBytes,
        mimeType: 'image/png',
      );

      expect(report.sha256, isNotEmpty);
      expect(report.sha256.length, equals(64));
      expect(report.md5, isNotEmpty);
      expect(report.md5.length, equals(32));
      expect(report.dHash, isNotEmpty);
      expect(report.dHash.length, equals(16)); // 16 hex chars = 64 bits
      expect(report.mimeType, equals('image/png'));
      expect(report.fileSizeBytes, equals(sampleBytes.length));
    });

    test('Perceptual dHash produces deterministic 16-character hex representation', () {
      final sample = Uint8List.fromList(List.generate(100, (i) => i % 256));
      final dHash = VisualOsintEngine.calculateByteLevelDHash(sample);

      expect(dHash.length, equals(16));
      expect(RegExp(r'^[0-9A-F]{16}$').hasMatch(dHash), isTrue);
    });

    test('Hamming distance correctly evaluates identical, near-duplicate, and opposite hashes', () {
      const hashA = 'FFFF0000FFFF0000';
      const hashB = 'FFFF0000FFFF0000'; // Identical
      const hashC = 'FFFF0000FFFF0001'; // 1 bit different (distance 1)
      const hashD = '0000FFFF0000FFFF'; // Completely inverted (distance 64)

      expect(VisualOsintEngine.calculateHammingDistance(hashA, hashB), equals(0));
      expect(VisualOsintEngine.calculateVisualSimilarity(hashA, hashB), equals(100.0));

      expect(VisualOsintEngine.calculateHammingDistance(hashA, hashC), equals(1));
      expect(VisualOsintEngine.calculateVisualSimilarity(hashA, hashC), closeTo(98.4, 0.2));

      expect(VisualOsintEngine.calculateHammingDistance(hashA, hashD), equals(64));
      expect(VisualOsintEngine.calculateVisualSimilarity(hashA, hashD), equals(0.0));
    });
  });

  group('VisualOsintEngine - Multi-Engine Query Generation', () {
    test('Constructs compliant reverse image search URLs across 6 global engines', () {
      const targetUrl = 'https://example.com/suspicious_avatar.jpg';
      final queries = VisualOsintEngine.generateEngineQueries(targetUrl);

      expect(queries.length, equals(6));

      // 1. Google Lens
      final google = queries.firstWhere((q) => q.engineKey == 'google_lens');
      expect(google.queryUrl, contains('https://lens.google.com/uploadbyurl?url='));
      expect(google.queryUrl, contains(Uri.encodeComponent(targetUrl)));
      expect(google.isPrimary, isTrue);

      // 2. Yandex Images (Face & Social Avatar specialist)
      final yandex = queries.firstWhere((q) => q.engineKey == 'yandex_images');
      expect(yandex.queryUrl, contains('https://yandex.com/images/search?rpt=imageview&url='));
      expect(yandex.isPrimary, isTrue);

      // 3. TinEye (Historical crawler)
      final tineye = queries.firstWhere((q) => q.engineKey == 'tineye');
      expect(tineye.queryUrl, contains('https://tineye.com/search?url='));

      // 4. Bing Visual
      final bing = queries.firstWhere((q) => q.engineKey == 'bing_visual');
      expect(bing.queryUrl, contains('https://www.bing.com/images/search?view=detailv2'));

      // 5. Baidu Vision
      final baidu = queries.firstWhere((q) => q.engineKey == 'baidu_vision');
      expect(baidu.queryUrl, contains('https://graph.baidu.com/details'));

      // 6. SauceNAO
      final saucenao = queries.firstWhere((q) => q.engineKey == 'saucenao');
      expect(saucenao.queryUrl, contains('https://saucenao.com/search.php'));
    });
  });

  group('VisualOsintEngine - On-Device OCR Forensic Entity Extraction', () {
    test('Detects Digital Arrest and CBI extortion letterheads with high fidelity', () {
      const text = '''
      CENTRAL BUREAU OF INVESTIGATION (CBI)
      NEW DELHI HEADQUARTERS
      ORDER OF DIGITAL ARREST & NON-BAILABLE WARRANT
      Section 420 IPC and PMLA money laundering investigation.
      Do not disconnect video call.
      Pay fine deposit of ₹95,000 to clearance account: cbi.vault@okhdfcbank
      ''';

      final ocr = VisualOsintEngine.inspectTextForensics(text);

      expect(ocr.isFraudulentDocument, isTrue);
      expect(ocr.documentCategory, contains('Digital Arrest'));
      expect(ocr.detectedInstitutions, contains('Central Bureau of Investigation (CBI)'));
      expect(ocr.detectedScamKeywords, contains('DIGITAL ARREST'));
      expect(ocr.detectedScamKeywords, contains('SECTION 420'));
      expect(ocr.detectedUpiIds, contains('cbi.vault@okhdfcbank'));
      expect(ocr.detectedAmounts, contains('₹95,000'));
    });

    test('Detects Electricity bill disconnection extortion trap', () {
      const text = '''
      Dear consumer, electricity power will be disconnected tonight at 9:30 PM
      from electricity office because previous month bill was not updated.
      Immediately contact power officer at 9876543210.
      ''';

      final ocr = VisualOsintEngine.inspectTextForensics(text);

      expect(ocr.isFraudulentDocument, isTrue);
      expect(ocr.documentCategory, contains('Electricity'));
      expect(ocr.detectedScamKeywords, contains('ELECTRICITY POWER WILL BE DISCONNECTED'));
      expect(ocr.detectedPhoneNumbers, contains('9876543210'));
    });

    test('Extracts UPI IDs and payment amounts from banking payment proof receipts', () {
      const text = '''
      PhonePe Payment Successful
      Paid to Sharma Electronics
      Transaction ID: T26090214828192849182
      UPI Ref No: 492819284192
      Sender UPI: user.sharma@paytm
      Amount: ₹15,500
      ''';

      final ocr = VisualOsintEngine.inspectTextForensics(text);

      expect(ocr.documentCategory, contains('UPI / Banking Payment Receipt'));
      expect(ocr.detectedInstitutions, contains('PhonePe Payment Gateway'));
      expect(ocr.detectedUpiIds, contains('user.sharma@paytm'));
      expect(ocr.detectedAmounts, contains('₹15,500'));
    });

    test('Reports clean verdict with zero false positive on benign text', () {
      const text = '''
      Meeting minutes: Project SafeSignal quarterly engineering sprint.
      Reviewed architectural diagrams, database indexing, and user onboarding flows.
      ''';

      final ocr = VisualOsintEngine.inspectTextForensics(text);

      expect(ocr.isFraudulentDocument, isFalse);
      expect(ocr.documentCategory, equals('Standard Visual Document'));
      expect(ocr.detectedInstitutions, isEmpty);
      expect(ocr.detectedScamKeywords, isEmpty);
    });
  });

  group('VisualOsintEngine - Threat Assessment Matrix', () {
    test('Assigns critical severity score (>=85) to Digital Arrest forgeries', () {
      const hashes = VisualHashReport(
        sha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        md5: 'd41d8cd98f00b204e9800998ecf8427e',
        sha1: 'da39a3ee5e6b4b0d3255bfef95601890afd80709',
        dHash: 'F0F0F0F00F0F0F0F',
        fileSizeBytes: 54000,
        width: 1080,
        height: 1920,
        mimeType: 'image/jpeg',
      );

      final ocr = VisualOsintEngine.inspectTextForensics('''
      NOTICE OF DIGITAL ARREST
      CENTRAL BUREAU OF INVESTIGATION
      ''');

      final assessment = VisualOsintEngine.evaluateThreat(hashes, ocr, null);

      expect(assessment.threatScore, greaterThanOrEqualTo(85));
      expect(assessment.threatLevel, equals(VisualThreatLevel.critical));
      expect(assessment.verdictTitle, contains('CRITICAL FRAUD'));
      expect(assessment.recommendations, isNotEmpty);
    });
  });
}
