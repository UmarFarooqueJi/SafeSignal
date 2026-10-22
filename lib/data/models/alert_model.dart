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

  /// Authentic Indian Cyber Threat Intelligence Offline Cache (I4C, CERT-In, NPCI, RBI, TRAI, DoT)
  static List<AlertModel> offlineThreatAdvisories() => [
        AlertModel(
          id: 'i4c_digital_arrest_2026',
          headline: 'I4C & MHA Advisory: Beware of "Digital Arrest" Video Call Syndicates',
          summary:
              'Fraudsters impersonating CBI, ED, Narcotics Control Bureau, and State Police are video-calling citizens in staged police station setups with fake uniforms and badges. They falsely claim an international parcel containing passports or MDMA has been seized in your name. Indian law enforcement NEVER conducts arrests, trials, or bail demands via WhatsApp, Skype, or video calls. Never transfer funds to "RBI verification accounts." Immediately disconnect and dial 1930.',
          isTrending: true,
          publishedAt: DateTime.now().subtract(const Duration(minutes: 25)),
          category: 'digital_arrest',
          isNew: true,
          sourceUrl: 'https://cybercrime.gov.in',
        ),
        AlertModel(
          id: 'fedex_customs_narcotics_extortion',
          headline: 'DoT & Cyber Cell Warning: FedEx / DHL Illegal Courier Parcel Extortion',
          summary:
              'Automated IVR calls claiming to be from FedEx or Customs state that a parcel sent from Mumbai to Taiwan/Cambodia containing 140 grams of narcotics was intercepted using your Aadhaar number. Victims are transferred to fake police officers who threaten non-bailable warrants. Real courier companies never initiate police video calls. Report sender numbers on Sanchar Saathi (Chakshu portal).',
          isTrending: true,
          publishedAt: DateTime.now().subtract(const Duration(hours: 1)),
          category: 'digital_arrest',
          isNew: true,
          sourceUrl: 'https://sancharsaathi.gov.in',
        ),
        AlertModel(
          id: 'cert_in_banking_trojans',
          headline: 'CERT-In Advisory CIAD-2026: Android Banking Trojans Masquerading as APKs',
          summary:
              'Sophisticated Android banking malware (Chameleon, GoldPickaxe, SpyMax) is distributed through WhatsApp links claiming to be Electricity Bill Updates or PM-Yojana schemes. These APKs abuse Android Accessibility Services to log keystrokes, intercept screen contents, and bypass banking 2FA SMS OTPs. SafeSignal recommends never sideloading unverified APKs outside verified software repositories.',
          isTrending: true,
          publishedAt: DateTime.now().subtract(const Duration(hours: 2)),
          category: 'phishing',
          isNew: true,
          sourceUrl: 'https://www.cert-in.org.in',
        ),
        AlertModel(
          id: 'electricity_bill_scam_warning',
          headline: 'Ministry of Power Alert: Fake 9:30 PM Electricity Disconnection SMSes',
          summary:
              'Fraudulent SMSes stating: "Dear Consumer, your electricity power will be disconnected tonight at 9:30 PM because your previous month bill was not updated. Contact Officer at 98xxxxxx." Calling the number leads to instructions to install AnyDesk, TeamViewer, or a malicious APK to "re-verify the consumer number," enabling complete remote takeover of your banking apps. Power distribution companies never send disconnection notices via personal 10-digit mobile numbers.',
          isTrending: true,
          publishedAt: DateTime.now().subtract(const Duration(hours: 3)),
          category: 'phishing',
          isNew: true,
          sourceUrl: 'https://cybercrime.gov.in',
        ),
        AlertModel(
          id: 'telegram_task_fraud_advisory',
          headline: 'I4C Advisory: Transnational Telegram "Like & Rating" Part-Time Job Scams',
          summary:
              'Citizens are lured into WhatsApp and Telegram groups promising daily earnings of ₹3,000–₹5,000 for liking YouTube videos or submitting Google Maps ratings. Fraudsters initially pay ₹150–₹300 via UPI to establish trust, then coerce victims into "VIP Prepaid Investment Tasks" on fraudulent crypto/forex platforms, resulting in multi-lakh financial losses.',
          isTrending: true,
          publishedAt: DateTime.now().subtract(const Duration(hours: 5)),
          category: 'investment',
          isNew: true,
          sourceUrl: 'https://cybercrime.gov.in',
        ),
        AlertModel(
          id: 'npci_rbi_upi_collect',
          headline: 'NPCI & RBI Alert: UPI PIN is Exclusively for Debiting Money, Never Receiving',
          summary:
              'Scammers pose as buyers on OLX, marketplace platforms, or fake customer support, sending "Collect Requests" or QR codes on PhonePe, Google Pay, and Paytm claiming to refund or pay money. GOLDEN RULE: Entering your UPI PIN or scanning a QR code ALWAYS transfers money OUT of your bank account. Receiving funds NEVER requires entering a UPI PIN.',
          isTrending: true,
          publishedAt: DateTime.now().subtract(const Duration(hours: 7)),
          category: 'investment',
          isNew: true,
          sourceUrl: 'https://www.npci.org.in',
        ),
        AlertModel(
          id: 'trai_sim_deactivation',
          headline: 'TRAI Alert: Automated Robotic Calls Threatening 2-Hour SIM Disconnection',
          summary:
              'Transnational syndicates are placing robocalls impersonating the Telecom Regulatory Authority of India (TRAI), stating your SIM card will be permanently blocked in 2 hours due to illegal advertising or cybercrime complaints. Victims are instructed to "Press 9" to connect to an investigator. TRAI clarifies that it never contacts individuals regarding phone disconnection.',
          isTrending: false,
          publishedAt: DateTime.now().subtract(const Duration(hours: 10)),
          category: 'otp',
          isNew: false,
          sourceUrl: 'https://sancharsaathi.gov.in',
        ),
        AlertModel(
          id: 'echallan_traffic_fine_apk',
          headline: 'State Cyber Cell Advisory: Fraudulent e-Challan Traffic Fine APKs',
          summary:
              'Malicious SMSes claiming pending traffic violation fines with links like "echallan-parivahan.apk" or "trafficpolice-fine.site" are circulating. Sideloading this APK installs an SMS-stealing trojan that reads incoming NetBanking OTPs while displaying a fake Parivahan payment portal. Always verify challans exclusively on the official parivahan.gov.in website.',
          isTrending: true,
          publishedAt: DateTime.now().subtract(const Duration(hours: 14)),
          category: 'phishing',
          isNew: false,
          sourceUrl: 'https://parivahan.gov.in',
        ),
        AlertModel(
          id: 'sbi_yono_pan_kyc_phishing',
          headline: 'SBI Cyber Advisory: Fake "YONO Account Blocked" PAN Card Phishing',
          summary:
              'Phishing messages mimicking State Bank of India claim: "Your SBI YONO account has been suspended due to pending PAN card verification. Click here to reactivate." The linked fake portals harvest NetBanking username, password, profile password, and debit card PIN. SBI never sends SMS links to update PAN or Aadhaar details.',
          isTrending: true,
          publishedAt: DateTime.now().subtract(const Duration(hours: 18)),
          category: 'phishing',
          isNew: false,
          sourceUrl: 'https://bank.sbi',
        ),
        AlertModel(
          id: 'ai_voice_clone_emergency',
          headline: 'CERT-In Threat Note: AI Voice Cloning Family Emergency & Kidnapping Scams',
          summary:
              'Criminal syndicates use 3-second audio samples from social media reels to clone family members\' voices using generative AI. They call parents claiming the child has been arrested by police or met with an accident, demanding urgent UPI transfers of ₹50,000–₹2,00,000. Always verify independently through a separate call before transferring emergency funds.',
          isTrending: false,
          publishedAt: DateTime.now().subtract(const Duration(hours: 22)),
          category: 'general',
          isNew: false,
          sourceUrl: 'https://www.cert-in.org.in',
        ),
        AlertModel(
          id: 'instant_loan_harassment',
          headline: 'RBI Public Caution: Predatory Instant Loan Apps & Gallery Extortion',
          summary:
              'Unregistered lending apps (Lightning Loan, CashPark, FastRupee) advertise 5-minute loans on social media. Upon installation, they require full Contacts and Storage/Camera permissions. If repayment is delayed by even 1 day, syndicates morph victim photos and harass emergency contacts. Borrow only from RBI-regulated banks and verified NBFCs.',
          isTrending: false,
          publishedAt: DateTime.now().subtract(const Duration(hours: 26)),
          category: 'general',
          isNew: false,
          sourceUrl: 'https://rbi.org.in',
        ),
        AlertModel(
          id: 'aadhaar_biometric_lock',
          headline: 'UIDAI Advisory: Lock Aadhaar Biometrics to Block AePS Fingerprint Fraud',
          summary:
              'Fraudsters clone latent silicon fingerprints from public land registry documents to withdraw funds via Aadhaar Enabled Payment Systems (AePS) without requiring SMS OTPs. Citizens are strongly urged to lock their biometrics using the official mAadhaar app or myaadhaar.uidai.gov.in portal.',
          isTrending: false,
          publishedAt: DateTime.now().subtract(const Duration(hours: 30)),
          category: 'otp',
          isNew: false,
          sourceUrl: 'https://myaadhaar.uidai.gov.in',
        ),
        AlertModel(
          id: 'google_search_fake_helpline',
          headline: 'Cyber Police Alert: Fake Customer Care Numbers on Google Search & Maps',
          summary:
              'Fraudsters edit Google Maps business listings and run search ads for airline, courier, and bank customer support numbers. When victims call, scammers instruct them to download screen-sharing tools or initiate small test transactions of ₹1 to ₹10 which route into malicious UPI collect triggers. Always source support contacts directly from the back of your bank card or official app.',
          isTrending: false,
          publishedAt: DateTime.now().subtract(const Duration(hours: 36)),
          category: 'general',
          isNew: false,
          sourceUrl: 'https://cybercrime.gov.in',
        ),
        AlertModel(
          id: 'whatsapp_pink_stalkerware',
          headline: 'CERT-In Advisory: "WhatsApp Pink" & "Free 5G Recharge" Malicious Droppers',
          summary:
              'Viral WhatsApp forwards claiming to provide a "Pink Theme" or "Free 1-Year 5G Recharge" distribute malicious APK droppers. Once installed, the spyware auto-replies to all incoming WhatsApp messages to spread virally, steals contact lists, and forwards SMS messages to remote command-and-control servers.',
          isTrending: false,
          publishedAt: DateTime.now().subtract(const Duration(hours: 42)),
          category: 'phishing',
          isNew: false,
          sourceUrl: 'https://www.cert-in.org.in',
        ),
      ];
}
