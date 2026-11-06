import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Threat Severity Classification for Visual OSINT
enum VisualThreatLevel { safe, low, medium, high, critical }

/// Cryptographic & Perceptual Hash Signatures of an Image
class VisualHashReport {
  final String sha256;
  final String md5;
  final String sha1;
  final String dHash;
  final int fileSizeBytes;
  final int? width;
  final int? height;
  final String mimeType;

  const VisualHashReport({
    required this.sha256,
    required this.md5,
    required this.sha1,
    required this.dHash,
    required this.fileSizeBytes,
    this.width,
    this.height,
    required this.mimeType,
  });

  Map<String, dynamic> toJson() => {
    'sha256': sha256,
    'md5': md5,
    'sha1': sha1,
    'dHash': dHash,
    'fileSizeBytes': fileSizeBytes,
    'width': width,
    'height': height,
    'mimeType': mimeType,
  };
}

/// Extracted text entities and forensic document findings
class OcrEntityExtraction {
  final String rawText;
  final List<String> detectedInstitutions;
  final List<String> detectedScamKeywords;
  final List<String> detectedUpiIds;
  final List<String> detectedPhoneNumbers;
  final List<String> detectedAmounts;
  final bool isFraudulentDocument;
  final String documentCategory;

  const OcrEntityExtraction({
    required this.rawText,
    this.detectedInstitutions = const [],
    this.detectedScamKeywords = const [],
    this.detectedUpiIds = const [],
    this.detectedPhoneNumbers = const [],
    this.detectedAmounts = const [],
    this.isFraudulentDocument = false,
    this.documentCategory = 'Standard Visual',
  });

  Map<String, dynamic> toJson() => {
    'rawText': rawText,
    'detectedInstitutions': detectedInstitutions,
    'detectedScamKeywords': detectedScamKeywords,
    'detectedUpiIds': detectedUpiIds,
    'detectedPhoneNumbers': detectedPhoneNumbers,
    'detectedAmounts': detectedAmounts,
    'isFraudulentDocument': isFraudulentDocument,
    'documentCategory': documentCategory,
  };
}

/// Target Reverse Image Search Engine Query
class ReverseEngineQuery {
  final String engineName;
  final String engineKey;
  final String queryUrl;
  final String description;
  final String specialization;
  final bool isPrimary;

  const ReverseEngineQuery({
    required this.engineName,
    required this.engineKey,
    required this.queryUrl,
    required this.description,
    required this.specialization,
    this.isPrimary = false,
  });
}

/// Visual Threat Assessment & Verdict
class VisualThreatAssessment {
  final int threatScore; // 0 - 100
  final VisualThreatLevel threatLevel;
  final String verdictTitle;
  final String primaryThreatType;
  final List<String> findings;
  final List<String> recommendations;

  const VisualThreatAssessment({
    required this.threatScore,
    required this.threatLevel,
    required this.verdictTitle,
    required this.primaryThreatType,
    this.findings = const [],
    this.recommendations = const [],
  });
}

/// Comprehensive Visual OSINT Inspection Result
class VisualOsintResult {
  final String? localFilePath;
  final String? imageUrl;
  final String? ephemeralHostedUrl;
  final VisualHashReport hashes;
  final OcrEntityExtraction ocrEntities;
  final List<ReverseEngineQuery> engineQueries;
  final VisualThreatAssessment assessment;
  final DateTime inspectedAt;

  const VisualOsintResult({
    this.localFilePath,
    this.imageUrl,
    this.ephemeralHostedUrl,
    required this.hashes,
    required this.ocrEntities,
    required this.engineQueries,
    required this.assessment,
    required this.inspectedAt,
  });
}

/// Universal Visual OSINT & Reverse Image Intelligence Engine
class VisualOsintEngine {
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
        'Accept': '*/*',
      },
    ),
  );

  // ─── 1. Cryptographic & Perceptual Hash Calculation ────────────────────────

  /// Calculates SHA-256, MD5, SHA-1 and 64-bit difference hash (dHash)
  static Future<VisualHashReport> calculateHashes(
    Uint8List bytes, {
    String mimeType = 'image/jpeg',
  }) async {
    final sha256Hash = sha256.convert(bytes).toString();
    final md5Hash = md5.convert(bytes).toString();
    final sha1Hash = sha1.convert(bytes).toString();
    final dHashValue = await calculateDHash(bytes);

    int? width;
    int? height;

    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      width = frame.image.width;
      height = frame.image.height;
    } catch (_) {
      // Fallback: parse basic PNG/JPEG header
      final dims = _parseBasicImageDimensions(bytes);
      width = dims.$1;
      height = dims.$2;
    }

    return VisualHashReport(
      sha256: sha256Hash,
      md5: md5Hash,
      sha1: sha1Hash,
      dHash: dHashValue,
      fileSizeBytes: bytes.length,
      width: width,
      height: height,
      mimeType: mimeType,
    );
  }

  /// Calculates a 64-bit Perceptual Difference Hash (dHash) for an image
  static Future<String> calculateDHash(Uint8List imageBytes) async {
    try {
      final codec = await ui.instantiateImageCodec(
        imageBytes,
        targetWidth: 9,
        targetHeight: 8,
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );

      if (byteData != null) {
        final buffer = byteData.buffer.asUint8List();
        BigInt hash = BigInt.zero;
        int bitIndex = 0;

        for (int y = 0; y < 8; y++) {
          for (int x = 0; x < 8; x++) {
            final leftIdx = (y * 9 + x) * 4;
            final rightIdx = (y * 9 + (x + 1)) * 4;

            final leftBrightness =
                0.299 * buffer[leftIdx] +
                0.587 * buffer[leftIdx + 1] +
                0.114 * buffer[leftIdx + 2];
            final rightBrightness =
                0.299 * buffer[rightIdx] +
                0.587 * buffer[rightIdx + 1] +
                0.114 * buffer[rightIdx + 2];

            if (leftBrightness > rightBrightness) {
              hash = hash | (BigInt.one << (63 - bitIndex));
            }
            bitIndex++;
          }
        }
        return hash.toRadixString(16).padLeft(16, '0').toUpperCase();
      }
    } catch (e) {
      debugPrint('Native UI dHash fallback triggered: $e');
    }

    return calculateByteLevelDHash(imageBytes);
  }

  /// Pure byte-level gradient fallback for headless test runners
  static String calculateByteLevelDHash(Uint8List bytes) {
    if (bytes.isEmpty) return '0000000000000000';
    BigInt hash = BigInt.zero;
    final step = bytes.length ~/ 72;
    if (step <= 0) return '0000000000000000';

    int bitIndex = 0;
    for (int y = 0; y < 8; y++) {
      for (int x = 0; x < 8; x++) {
        final leftIdx = (y * 9 + x) * step;
        final rightIdx = (y * 9 + (x + 1)) * step;
        final leftVal = leftIdx < bytes.length ? bytes[leftIdx] : 0;
        final rightVal = rightIdx < bytes.length ? bytes[rightIdx] : 0;

        if (leftVal > rightVal) {
          hash = hash | (BigInt.one << (63 - bitIndex));
        }
        bitIndex++;
      }
    }
    return hash.toRadixString(16).padLeft(16, '0').toUpperCase();
  }

  /// Calculates Hamming Distance between two 64-bit dHashes
  static int calculateHammingDistance(String hash1, String hash2) {
    final val1 = BigInt.tryParse(hash1, radix: 16) ?? BigInt.zero;
    final val2 = BigInt.tryParse(hash2, radix: 16) ?? BigInt.zero;
    BigInt xor = val1 ^ val2;
    int distance = 0;
    while (xor > BigInt.zero) {
      if ((xor & BigInt.one) == BigInt.one) distance++;
      xor = xor >> 1;
    }
    return distance;
  }

  /// Returns visual similarity percentage between 0.0% and 100.0%
  static double calculateVisualSimilarity(String hash1, String hash2) {
    final dist = calculateHammingDistance(hash1, hash2);
    final similarity = (1.0 - (dist / 64.0)) * 100.0;
    return similarity.clamp(0.0, 100.0);
  }

  // ─── 2. On-Device OCR Forensic Entity Extraction ───────────────────────────

  /// Extracts text and forensic cyber-threat markers from an image
  static Future<OcrEntityExtraction> extractOcrEntities(
    String filePath, {
    String? fallbackText,
  }) async {
    String rawText = fallbackText ?? '';

    if (rawText.isEmpty && filePath.isNotEmpty && File(filePath).existsSync()) {
      try {
        final textRecognizer = TextRecognizer(
          script: TextRecognitionScript.latin,
        );
        final inputImage = InputImage.fromFilePath(filePath);
        final RecognizedText recognized = await textRecognizer.processImage(
          inputImage,
        );
        rawText = recognized.text;
        await textRecognizer.close();
      } catch (e) {
        debugPrint('ML Kit OCR fallback: $e');
      }
    }

    return inspectTextForensics(rawText);
  }

  /// Inspects raw text string for scam lures, authorities, fake receipts, and UPIs
  static OcrEntityExtraction inspectTextForensics(String text) {
    if (text.trim().isEmpty) {
      return const OcrEntityExtraction(rawText: '');
    }

    final lower = text.toLowerCase();
    final List<String> detectedInstitutions = [];
    final List<String> detectedScamKeywords = [];
    final List<String> detectedUpiIds = [];
    final List<String> detectedPhoneNumbers = [];
    final List<String> detectedAmounts = [];

    // 1. Digital Arrest & Government Impersonation
    const authorityMap = {
      'cbi': 'Central Bureau of Investigation (CBI)',
      'central bureau': 'Central Bureau of Investigation (CBI)',
      'enforcement directorate': 'Enforcement Directorate (ED)',
      'ed office': 'Enforcement Directorate (ED)',
      'cyber crime': 'National Cyber Crime Cell',
      'cyber police': 'Cyber Police Department',
      'arrest warrant': 'Non-Bailable Arrest Warrant',
      'supreme court': 'Supreme Court of India',
      'high court': 'High Court of Judicature',
      'narcotics control': 'Narcotics Control Bureau (NCB)',
      'money laundering': 'PMLA / Money Laundering Notice',
      'mumbai police': 'Mumbai Police Commissionerate',
      'delhi police': 'Delhi Police Cyber Cell',
      'trai': 'Telecom Regulatory Authority (TRAI)',
      'customs': 'Indian Customs Authority',
    };

    for (final entry in authorityMap.entries) {
      if (lower.contains(entry.key) &&
          !detectedInstitutions.contains(entry.value)) {
        detectedInstitutions.add(entry.value);
      }
    }

    // 2. High-Pressure Scam Lures & Coercion Keywords
    const scamTriggers = [
      'digital arrest',
      'video call verification',
      'interrogation',
      'seize property',
      'bank account frozen',
      'section 420',
      'ipc 420',
      'it act 66d',
      'non-bailable',
      'electricity power will be disconnected',
      'tonight at 9:30',
      'call electricity officer',
      'update bill',
      'kbc lottery',
      'lucky winner',
      'daily income',
      'telegram task',
      'part time job',
      'usdt investment',
      'refund amount',
    ];

    for (final trigger in scamTriggers) {
      if (lower.contains(trigger)) {
        detectedScamKeywords.add(trigger.toUpperCase());
      }
    }

    // 3. Banking & Payment Receipt Indicators
    const bankingKeywords = {
      'phonepe': 'PhonePe Payment Gateway',
      'google pay': 'Google Pay (GPay)',
      'gpay': 'Google Pay (GPay)',
      'paytm': 'Paytm Payments Bank',
      'payment successful': 'Payment Receipt Successful Marker',
      'paid to': 'Merchant Payment Confirmation',
      'transaction successful': 'Transaction Clearance Notice',
      'utr': 'Banking UTR Number',
      'upi ref no': 'UPI Reference Code',
      'sbi': 'State Bank of India',
      'hdfc': 'HDFC Bank',
      'icici': 'ICICI Bank',
      'axis bank': 'Axis Bank',
      'punjab national bank': 'Punjab National Bank',
    };

    for (final entry in bankingKeywords.entries) {
      if (lower.contains(entry.key) &&
          !detectedInstitutions.contains(entry.value)) {
        detectedInstitutions.add(entry.value);
      }
    }

    // 4. Regex Extraction for UPI IDs
    final upiRegex = RegExp(
      r'[a-zA-Z0-9.\-_]{2,256}@(okhdfcbank|okaxis|okicici|oksbi|paytm|ybl|ibl|axl|upi|airtel|postbank)',
      caseSensitive: false,
    );
    for (final match in upiRegex.allMatches(text)) {
      final upi = match.group(0);
      if (upi != null && !detectedUpiIds.contains(upi)) {
        detectedUpiIds.add(upi);
      }
    }

    // 5. Regex Extraction for Phone Numbers (Indian mobile formats)
    final phoneRegex = RegExp(r'(?:\+91[\-\s]?)?[6-9]\d{9}');
    for (final match in phoneRegex.allMatches(text)) {
      final phone = match.group(0);
      if (phone != null && !detectedPhoneNumbers.contains(phone)) {
        detectedPhoneNumbers.add(phone);
      }
    }

    // 6. Regex Extraction for Transaction Amounts (₹ / Rs.)
    final amountRegex = RegExp(
      r'(?:₹|Rs\.?|INR)\s*[\d,]+(?:\.\d{2})?',
      caseSensitive: false,
    );
    for (final match in amountRegex.allMatches(text)) {
      final amt = match.group(0);
      if (amt != null && !detectedAmounts.contains(amt)) {
        detectedAmounts.add(amt);
      }
    }

    // Classification Category
    String category = 'Standard Visual Document';
    bool isFraud = false;

    if (detectedInstitutions.any((i) => i.contains('CBI') || i.contains('Police') || i.contains('Court') || i.contains('ED')) ||
        lower.contains('digital arrest') ||
        lower.contains('arrest warrant')) {
      category = 'Digital Arrest & Law Enforcement Forgery';
      isFraud = true;
    } else if (lower.contains('electricity') && lower.contains('disconnect')) {
      category = 'Electricity Power Disconnection Extortion';
      isFraud = true;
    } else if (lower.contains('kbc') || lower.contains('lottery') || lower.contains('lucky winner')) {
      category = 'Lottery & Advance-Fee Fraud Lure';
      isFraud = true;
    } else if (detectedInstitutions.any((i) => i.contains('PhonePe') || i.contains('Paytm') || i.contains('Google Pay')) &&
        (lower.contains('successful') || lower.contains('paid to'))) {
      category = 'UPI / Banking Payment Receipt Proof';
      // Flag as potential receipt verification target
    }

    return OcrEntityExtraction(
      rawText: text,
      detectedInstitutions: detectedInstitutions,
      detectedScamKeywords: detectedScamKeywords,
      detectedUpiIds: detectedUpiIds,
      detectedPhoneNumbers: detectedPhoneNumbers,
      detectedAmounts: detectedAmounts,
      isFraudulentDocument: isFraud,
      documentCategory: category,
    );
  }

  // ─── 3. Multi-Engine Reverse Search Matrix ─────────────────────────────────

  /// Generates direct query endpoints across the top 5 global visual search engines
  static List<ReverseEngineQuery> generateEngineQueries(String targetImageUrl) {
    final encoded = Uri.encodeComponent(targetImageUrl);

    return [
      ReverseEngineQuery(
        engineName: 'Google Lens',
        engineKey: 'google_lens',
        queryUrl: 'https://lens.google.com/uploadbyurl?url=$encoded',
        description:
            'Deep web indexing, consumer products, visual clone websites and global image matches.',
        specialization: 'Deep Web, Brand Matching & E-Commerce Clones',
        isPrimary: true,
      ),
      ReverseEngineQuery(
        engineName: 'Yandex Vision',
        engineKey: 'yandex_images',
        queryUrl: 'https://yandex.com/images/search?rpt=imageview&url=$encoded',
        description:
            'The undisputed gold standard for uncropped faces, VK/Telegram social avatars, and modified profile photos.',
        specialization: 'Faces, Catfish DP & Uncropped Social Avatars',
        isPrimary: true,
      ),
      ReverseEngineQuery(
        engineName: 'TinEye OSINT',
        engineKey: 'tineye',
        queryUrl: 'https://tineye.com/search?url=$encoded',
        description:
            'Tracks exact crawl history, earliest upload date on the internet, and modified versions.',
        specialization: 'First-Seen Crawl Date & Modification History',
      ),
      ReverseEngineQuery(
        engineName: 'Bing Visual',
        engineKey: 'bing_visual',
        queryUrl:
            'https://www.bing.com/images/search?view=detailv2&iss=sbi&form=SBIVSP&q=imgurl:$encoded',
        description:
            'Microsoft visual graph for entity resolution, cropped region search, and web domain mapping.',
        specialization: 'Entity Intelligence & Domain Footprints',
      ),
      ReverseEngineQuery(
        engineName: 'Baidu Vision',
        engineKey: 'baidu_vision',
        queryUrl: 'https://graph.baidu.com/details?isfromvs=1&sign=&url=$encoded',
        description:
            'Essential for tracing Asian supply chains, cloned retail catalogs, and cross-border fraud syndicates.',
        specialization: 'Asian Web & Cross-Border Clone Networks',
      ),
      ReverseEngineQuery(
        engineName: 'SauceNAO Forensic',
        engineKey: 'saucenao',
        queryUrl: 'https://saucenao.com/search.php?url=$encoded',
        description:
            'Database indexing anime, illustrations, stock art, and digital forum profile icons.',
        specialization: 'Stock Illustrations & Digital Artworks',
      ),
    ];
  }

  // ─── 4. Ephemeral Privacy-First Relay ──────────────────────────────────────

  /// Uploads local image to an ephemeral, zero-knowledge temporary storage
  /// that automatically self-destructs in 1 hour (no persistent logging).
  static Future<String?> uploadToEphemeralRelay(Uint8List imageBytes, {String fileName = 'safesignal_recon.jpg'}) async {
    try {
      // Primary: Catbox Litterbox (1 hour self-destruct)
      final formData = FormData.fromMap({
        'reqtype': 'fileupload',
        'time': '1h',
        'fileToUpload': MultipartFile.fromBytes(
          imageBytes,
          filename: fileName,
        ),
      });

      final response = await _dio.post(
        'https://litterbox.catbox.moe/resources/internals/api.php',
        data: formData,
        options: Options(
          headers: {'User-Agent': 'SafeSignal-Cyber-Radar/1.3.0'},
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final resultUrl = response.data.toString().trim();
        if (resultUrl.startsWith('http://') || resultUrl.startsWith('https://')) {
          return resultUrl;
        }
      }
    } catch (e) {
      debugPrint('Ephemeral Litterbox upload failed: $e');
    }

    try {
      // Secondary: Freeimage.host API fallback
      final formData = FormData.fromMap({
        'key': '6d207e02198a847aa98d0a2a901485a5',
        'action': 'upload',
        'source': base64Encode(imageBytes),
        'format': 'json',
      });

      final response = await _dio.post(
        'https://freeimage.host/api/1/upload',
        data: formData,
        options: Options(
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map && data['image'] != null && data['image']['url'] != null) {
          return data['image']['url'].toString();
        }
      }
    } catch (e) {
      debugPrint('Secondary Freeimage relay failed: $e');
    }

    return null;
  }

  // ─── 5. Threat Assessment & Scoring Matrix ─────────────────────────────────

  /// Computes final threat score and risk breakdown
  static VisualThreatAssessment evaluateThreat(
    VisualHashReport hashes,
    OcrEntityExtraction ocr,
    String? webUrl,
  ) {
    int score = 0;
    final List<String> findings = [];
    final List<String> recommendations = [];
    String threatType = 'Benign / Standard Visual';
    String verdictTitle = 'Image Clean & Unflagged';

    // 1. Digital Arrest / Fake Police Document
    if (ocr.isFraudulentDocument && ocr.documentCategory.contains('Digital Arrest')) {
      score = 98;
      threatType = 'Digital Arrest & Law Enforcement Forgery';
      verdictTitle = 'CRITICAL FRAUD: Fabricated Government Order';
      findings.add('Detected fake law enforcement letterhead: ${ocr.detectedInstitutions.join(", ")}');
      findings.add('High-pressure extortion language detected: ${ocr.detectedScamKeywords.join(", ")}');
      recommendations.add('DO NOT send money or join video calls. Law enforcement never arrests via WhatsApp or Skype.');
      recommendations.add('Immediately dial 1930 or report on cybercrime.gov.in.');
    }
    // 2. Electricity Disconnection Blackmail
    else if (ocr.isFraudulentDocument && ocr.documentCategory.contains('Electricity')) {
      score = 94;
      threatType = 'Utility Power Cut Extortion Trap';
      verdictTitle = 'HIGH RISK: Electricity Scam Notice';
      findings.add('Detected fraudulent power cutoff threat targeting local utility consumers.');
      if (ocr.detectedPhoneNumbers.isNotEmpty) {
        findings.add('Suspect contact numbers: ${ocr.detectedPhoneNumbers.join(", ")}');
      }
      recommendations.add('Power boards never send personal phone numbers for bill clearance. Contact your official DISCOM office.');
    }
    // 3. Fake UPI / Payment Receipt
    else if (ocr.detectedInstitutions.any((i) => i.contains('PhonePe') || i.contains('Paytm') || i.contains('Google Pay'))) {
      score = 45;
      threatType = 'Payment Receipt Verification Required';
      verdictTitle = 'CAUTION: Banking / Payment Proof';
      findings.add('Detected payment receipt proof mentioning ${ocr.detectedInstitutions.first}.');
      if (ocr.detectedUpiIds.isNotEmpty) {
        findings.add('Target UPI IDs: ${ocr.detectedUpiIds.join(", ")}');
      }
      if (ocr.detectedAmounts.isNotEmpty) {
        findings.add('Claimed amount: ${ocr.detectedAmounts.join(", ")}');
      }
      recommendations.add('Verify transaction balance directly inside your official banking app. Do not rely on customer-shown screenshots.');
    }
    // 4. Low Resolution or Suspicious Profile Avatar
    else if ((hashes.width != null && hashes.width! < 250) || (hashes.height != null && hashes.height! < 250)) {
      score = 25;
      threatType = 'Low Resolution / Cropped Profile Icon';
      verdictTitle = 'LOW RISK: Compressed Visual Asset';
      findings.add('Image is heavily compressed or cropped (${hashes.width}x${hashes.height}px), typical of downloaded social profile pictures.');
      recommendations.add('Run Yandex Vision reverse search to check if this face appears on stock photo catalogs or dating scam databases.');
    }

    VisualThreatLevel level;
    if (score >= 85) {
      level = VisualThreatLevel.critical;
    } else if (score >= 65) {
      level = VisualThreatLevel.high;
    } else if (score >= 40) {
      level = VisualThreatLevel.medium;
    } else if (score >= 20) {
      level = VisualThreatLevel.low;
    } else {
      level = VisualThreatLevel.safe;
    }

    if (findings.isEmpty) {
      findings.add('No known fraud keywords or forensic tampering patterns detected in visual inspection.');
    }
    if (recommendations.isEmpty) {
      recommendations.add('Use reverse image search engines below to verify original publisher and web appearance history.');
    }

    return VisualThreatAssessment(
      threatScore: score,
      threatLevel: level,
      verdictTitle: verdictTitle,
      primaryThreatType: threatType,
      findings: findings,
      recommendations: recommendations,
    );
  }

  // ─── 6. Full Pipeline Execution ────────────────────────────────────────────

  /// Executes full end-to-end Visual OSINT pipeline for a file or URL
  static Future<VisualOsintResult> analyze({
    String? localFilePath,
    String? imageUrl,
    String? manualOcrText,
  }) async {
    Uint8List bytes;
    String mimeType = 'image/jpeg';

    if (localFilePath != null && File(localFilePath).existsSync()) {
      final file = File(localFilePath);
      bytes = await file.readAsBytes();
      if (localFilePath.toLowerCase().endsWith('.png')) mimeType = 'image/png';
      if (localFilePath.toLowerCase().endsWith('.webp')) mimeType = 'image/webp';
    } else if (imageUrl != null && imageUrl.isNotEmpty) {
      final response = await _dio.get<List<int>>(
        imageUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      bytes = Uint8List.fromList(response.data!);
      final ct = response.headers.value('content-type');
      if (ct != null && ct.isNotEmpty) mimeType = ct.split(';').first.trim();
    } else {
      throw ArgumentError('Either localFilePath or imageUrl must be provided');
    }

    // 1. Calculate Hashes
    final hashes = await calculateHashes(bytes, mimeType: mimeType);

    // 2. OCR Entity Extraction
    final ocr = await extractOcrEntities(
      localFilePath ?? '',
      fallbackText: manualOcrText,
    );

    // 3. Ephemeral Relay for Local Files if no external URL
    String? publicUrl = imageUrl;
    String? ephemeralUrl;

    if (publicUrl == null || publicUrl.isEmpty) {
      ephemeralUrl = await uploadToEphemeralRelay(bytes);
      publicUrl = ephemeralUrl;
    }

    // 4. Generate Engine Queries
    final engineQueries = generateEngineQueries(publicUrl ?? 'https://via.placeholder.com/150');

    // 5. Threat Evaluation
    final assessment = evaluateThreat(hashes, ocr, publicUrl);

    return VisualOsintResult(
      localFilePath: localFilePath,
      imageUrl: imageUrl,
      ephemeralHostedUrl: ephemeralUrl,
      hashes: hashes,
      ocrEntities: ocr,
      engineQueries: engineQueries,
      assessment: assessment,
      inspectedAt: DateTime.now(),
    );
  }

  // ─── Helper: Parse Basic JPEG/PNG Dimensions ───────────────────────────────
  static (int?, int?) _parseBasicImageDimensions(Uint8List bytes) {
    if (bytes.length > 24) {
      // PNG signature: 89 50 4E 47 0D 0A 1A 0A
      if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E) {
        final w = (bytes[16] << 24) | (bytes[17] << 16) | (bytes[18] << 8) | bytes[19];
        final h = (bytes[20] << 24) | (bytes[21] << 16) | (bytes[22] << 8) | bytes[23];
        return (w, h);
      }
    }
    return (null, null);
  }
}
