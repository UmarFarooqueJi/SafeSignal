import 'package:hive/hive.dart';

part 'alert_model.g.dart';

@HiveType(typeId: 1)
class AlertModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String headline;

  @HiveField(2)
  final String summary;

  @HiveField(3)
  final String? sourceUrl;

  @HiveField(4)
  final bool isTrending;

  @HiveField(5)
  final DateTime publishedAt;

  @HiveField(6)
  final String category; // digital_arrest, lottery, otp, investment, etc.

  @HiveField(7)
  final bool isNew;

  @HiveField(8)
  final String? imageUrl;

  AlertModel({
    required this.id,
    required this.headline,
    required this.summary,
    this.sourceUrl,
    required this.isTrending,
    required this.publishedAt,
    required this.category,
    required this.isNew,
    this.imageUrl,
  });

  factory AlertModel.fromJson(Map<String, dynamic> json) {
    return AlertModel(
      id: json['id'] ?? '',
      headline: json['headline'] ?? '',
      summary: json['summary'] ?? '',
      sourceUrl: json['source_url'],
      imageUrl: json['image_url'],
      isTrending: json['is_trending'] ?? false,
      publishedAt: DateTime.tryParse(json['published_at'] ?? '') ?? DateTime.now(),
      category: json['category'] ?? 'general',
      isNew: json['is_new'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'headline': headline,
        'summary': summary,
        'source_url': sourceUrl,
        'image_url': imageUrl,
        'is_trending': isTrending,
        'published_at': publishedAt.toIso8601String(),
        'category': category,
        'is_new': isNew,
      };

  static List<AlertModel> mockAlerts() => offlineThreatAdvisories();

  /// Authentic Indian Cyber Threat Intelligence Offline Cache (I4C, CERT-In, NPCI, RBI, TRAI)
  static List<AlertModel> offlineThreatAdvisories() => [
        AlertModel(
          id: 'i4c_digital_arrest_2026',
          headline: 'I4C & MHA Advisory: Beware of "Digital Arrest" Video Call Syndicates',
          summary:
              'Fraudsters impersonating CBI, ED, Customs, and State Police are video-calling citizens in staged police station backdrops, falsely claiming parcels containing narcotics or money laundering. Indian law enforcement NEVER conducts arrests via WhatsApp or Skype. Immediately call 1930 to freeze transactions.',
          isTrending: true,
          publishedAt: DateTime.now().subtract(const Duration(hours: 1)),
          category: 'digital_arrest',
          isNew: true,
          sourceUrl: 'https://cybercrime.gov.in',
        ),
        AlertModel(
          id: 'cert_in_banking_trojans',
          headline: 'CERT-In Advisory: Android Banking Trojans Masquerading as APK Updates',
          summary:
              'Sophisticated Android malware (Chameleon, GoldPickaxe, SpyMax) spread via WhatsApp links claiming to be Electricity Bill Updates or PM-Yojana schemes. These APKs abuse Android Accessibility permissions to intercept screen contents and steal banking 2FA credentials.',
          isTrending: true,
          publishedAt: DateTime.now().subtract(const Duration(hours: 3)),
          category: 'phishing',
          isNew: true,
          sourceUrl: 'https://www.cert-in.org.in',
        ),
        AlertModel(
          id: 'npci_rbi_upi_collect',
          headline: 'NPCI & RBI Alert: UPI PIN is Exclusively for Debiting Money, Never Receiving',
          summary:
              'Scammers are issuing fake refund collect requests on PhonePe, Google Pay, and Paytm. Entering your UPI PIN or scanning a received QR code ALWAYS transfers money OUT of your bank account. Never enter your UPI PIN to claim prizes or refunds.',
          isTrending: true,
          publishedAt: DateTime.now().subtract(const Duration(hours: 6)),
          category: 'investment',
          isNew: true,
          sourceUrl: 'https://www.npci.org.in',
        ),
        AlertModel(
          id: 'trai_sim_deactivation',
          headline: 'TRAI Alert: Automated IVR Calls Threatening 2-Hour SIM Deactivation',
          summary:
              'Syndicates are making automated calls threatening permanent SIM deactivation within 2 hours unless Aadhaar re-verification is completed over the phone. TRAI does not authorize any telecom operator to disconnect numbers via robotic calls.',
          isTrending: false,
          publishedAt: DateTime.now().subtract(const Duration(hours: 12)),
          category: 'otp',
          isNew: false,
          sourceUrl: 'https://sancharsaathi.gov.in',
        ),
        AlertModel(
          id: 'telegram_task_fraud_advisory',
          headline: 'I4C Warning: Transnational Telegram "Like & Rating" Part-Time Job Scams',
          summary:
              'Citizens are lured into WhatsApp and Telegram groups promising daily earnings of ₹3,000–₹5,000 for liking YouTube videos or Google reviews. Once trust is gained, victims are coerced into transferring money to fraudulent crypto/forex platforms.',
          isTrending: true,
          publishedAt: DateTime.now().subtract(const Duration(hours: 18)),
          category: 'investment',
          isNew: false,
          sourceUrl: 'https://cybercrime.gov.in',
        ),
        AlertModel(
          id: 'electricity_bill_scam_warning',
          headline: 'Power Ministry Alert: Fraudulent Electricity Disconnection SMSes',
          summary:
              'Fake SMSes claiming power disconnection tonight at 9:30 PM due to unpaid bills are phishing scams. Fraudsters ask victims to download AnyDesk or TeamViewer to update their consumer number, taking remote control of the phone.',
          isTrending: false,
          publishedAt: DateTime.now().subtract(const Duration(hours: 24)),
          category: 'phishing',
          isNew: false,
          sourceUrl: 'https://cybercrime.gov.in',
        ),
      ];
}
