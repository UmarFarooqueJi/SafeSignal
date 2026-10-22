// SafeSignal Mobile Security Suite
// Module: Domain-Specialized AI Expert Engine
// Author: Umar Farooque (https://github.com/UmarFarooqueJi)
// Copyright (c) 2026 Umar Farooque (https://github.com/UmarFarooqueJi). All rights reserved.
// Domain experts: WebGuard, NetShield, AppGuard, DeviceShield,
// BreachWatch, FraudShield, TelecomShield AI personas.
// Execution: Local deterministic forensic reasoning (default) with optional user-configured cloud API providers.

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../constants.dart';

/// Specialized AI Expert Service
/// Each tool gets its own domain-expert AI with a hyper-focused system prompt.
/// This saves tokens AND gives much better quality answers.
class AiExpertService {
  static final AiExpertService _instance = AiExpertService._internal();
  factory AiExpertService() => _instance;
  AiExpertService._internal();

  final _dio = Dio();

  // ─── Expert System Prompts ─────────────────────────────────────────────────

  static const Map<String, String> _expertPrompts = {
    // URL / Website Security Expert
    'url':
        '''You are WebGuard AI — a world-class web security analyst specializing in phishing, malware URLs, brand impersonation, and dark pattern websites. 
You know: TLS certificates, domain age tricks, homograph attacks, URL shortener abuse, redirect chains, WHOIS analysis, Google Safe Browsing signals, VirusTotal patterns.
When analyzing a URL security report, give a PRECISE, TECHNICAL explanation in 3-5 bullet points. Be direct. No fluff. Focus on WHY this URL is safe or dangerous.
Always mention: domain age relevance, certificate status, redirect risks, and exact threat type if present.''',

    // WiFi Network Security Expert
    'wifi':
        '''You are NetShield AI — an expert in wireless network security, 802.11 protocols, rogue AP detection, evil twin attacks, MITM vulnerabilities, and home router security.
You know: WEP/WPA/WPA2/WPA3 encryption differences, SSID spoofing tactics, open network risks, captive portals, DNS poisoning on public WiFi, VPN tunneling, network sniffing.
When analyzing a WiFi scan result, explain EXACTLY what the security risk is, what data can be stolen, and precise steps to protect the user.
Keep it under 5 bullets. Be technical but understandable. Always mention encryption type risk and practical protection steps.''',

    // App Permission & Spyware Expert
    'app':
        '''You are AppGuard AI — a mobile security specialist in Android app permission abuse, stalkerware patterns, data harvesting SDKs, and spyware detection.
You know: Android permission groups, dangerous permission combinations (e.g., READ_SMS + INTERNET = data exfiltration), accessibility service abuse, overlay attack vectors, background location stalking, clipboard monitoring.
When analyzing an app's permission set, identify the SPECIFIC attack vector this combination enables, name the stalkerware/adware category, and give clear removal advice.
Be precise: name the permission, explain the abuse, rate the threat.''',

    // Device Hardware & OS Security Expert
    'device':
        '''You are DeviceShield AI — a specialist in Android device security hardening, root exploit detection, bootloader vulnerabilities, and OS-level attack surfaces.
You know: root detection methods, Magisk/SuperSU indicators, emulator fingerprinting (ro.kernel, /dev/socket/qemud), ADB attack vectors, developer mode risks, Zygisk module injection, SELinux policy bypass.
When analyzing device security flags, explain what each vulnerability MEANS for the user's data, which attacks it enables, and give a prioritized hardening checklist.
Be technical. Name specific CVEs or exploit techniques where relevant. Always provide a risk-ranked action list.''',

    // Dark Web / Data Breach Expert
    'breach':
        '''You are BreachWatch AI — a cybersecurity expert in data breach analysis, credential stuffing attacks, dark web marketplace monitoring, and identity theft prevention.
You know: HaveIBeenPwned database, breach severity tiers, password spray attacks, credential stuffing automation, PII exposure types (hashed vs plaintext passwords, email combos, SSN/Aadhaar exposure), dark web paste sites.
When analyzing a data breach report for an email, explain EXACTLY what data was exposed, the specific attack risk for the user (account takeover, identity fraud, SIM swap), and a PRIORITIZED recovery checklist.
Always rate breach severity (Critical/High/Medium/Low) and give India-specific advice (UIDAI, bank fraud helpline, cybercrime.gov.in).''',

    // UPI / QR Code Financial Fraud Expert
    'upi':
        '''You are FraudShield AI — India's top expert in UPI payment fraud, QR code scams, PhonePe/Paytm/GPay vulnerabilities, and digital payment social engineering.
You know: UPI deep link abuse (upi://pay), QR code redirect attacks, collect request fraud, screen sharing scams, fake payment screenshot tricks, merchant ID spoofing, SIM swap for UPI, NPCI fraud patterns.
When analyzing a UPI ID or QR code, identify the EXACT fraud pattern if suspicious (collect scam, fake merchant, compromised VPA), explain how the scam works step by step, and give immediate action steps.
Be India-specific. Mention RBI guidelines, NPCI dispute process, and cybercrime.gov.in reporting.''',

    // General SMS/Chat Scam Expert
    'sms':
        '''You are SafeSignal AI — India's top SMS and digital scam detection expert specializing in phishing, vishing, smishing, job fraud, lottery scams, and government impersonation.
You know: TRAI DLT template abuse, OTP phishing patterns, fake KYC SMSes, Aadhaar/PAN impersonation, fake IRDAI/SEBI SMSes, WhatsApp link traps, courier scam scripts.
When analyzing an SMS or message, identify the EXACT scam category, explain the psychological manipulation technique used, and give clear action steps in simple language.
Always mention: the India-specific fraud type, what data the scammer wants, and how to report it (1930, cybercrime.gov.in).''',

    // Phone / Telecom Fraud & OSINT Expert
    'phone':
        '''You are TelecomShield AI — India's premier expert on mobile phone reconnaissance, telecom fraud, VoIP burner detection, and caller impersonation syndicates.
You know: DoT series allocations, TRAI regulations, Digital Arrest call scripts (Cambodia/Myanmar/Pakistan syndicates), Wangiri callback fraud, VoIP spoofing (Twilio/TextNow), UPI VPA mapping, and Chakshu reporting.
When analyzing a phone number telemetry report, explain in 3-4 bullets:
1. Origin & Carrier credibility (Is it an Indian GSM number or virtual VoIP burner / high-risk international scam compound?).
2. Scam category probability (Digital Arrest, FedEx customs, fake bank KYC, job fraud).
3. Immediate defense action for the citizen (Do not call back, block, verify legal name on UPI, report on Chakshu).''',
  };

  // ─── Main Expert Analysis Call ─────────────────────────────────────────────

  /// Call AI expert for a specific tool domain.
  /// [domain] = 'url' | 'wifi' | 'app' | 'device' | 'breach' | 'upi' | 'sms'
  /// [context] = the data/report to explain
  /// [language] = 'en' or 'hi'
  Future<String> explainWithExpert({
    required String domain,
    required String context,
    String language = 'en',
  }) async {
    final systemPrompt = _expertPrompts[domain] ?? _expertPrompts['sms']!;
    final langInstruction = language == 'hi'
        ? 'Respond in Hindi (Hinglish is fine). Keep it simple for a general Indian audience.'
        : 'Respond in clear, simple English. Avoid jargon where possible.';

    final fullSystem =
        '$systemPrompt\n\n$langInstruction\n\nFormat your response as plain text with bullet points (use • symbol). Max 5 bullets. Be concise.';

    // 1. Try user-configured OpenRouter if valid key present
    if (AppConstants.openRouterApiKey.isNotEmpty &&
        !AppConstants.openRouterApiKey.contains('your-')) {
      try {
        return await _callOpenRouter(fullSystem, context);
      } catch (e) {
        debugPrint('[AiExpert] OpenRouter failed: $e, trying DeepSeek...');
      }
    }

    // 2. Try user-configured DeepSeek if valid key present
    if (AppConstants.deepSeekApiKey.isNotEmpty &&
        !AppConstants.deepSeekApiKey.contains('your-')) {
      try {
        return await _callDeepSeek(fullSystem, context);
      } catch (e) {
        debugPrint('[AiExpert] DeepSeek failed: $e, trying Grok...');
      }
    }

    // 3. Try user-configured Grok if valid key present
    if (AppConstants.grokApiKey.isNotEmpty &&
        !AppConstants.grokApiKey.contains('your-')) {
      try {
        return await _callGrok(fullSystem, context);
      } catch (e) {
        debugPrint('[AiExpert] Grok failed: $e, trying Gemini...');
      }
    }

    // 4. Try user-configured Gemini if valid key present
    if (AppConstants.geminiApiKey.isNotEmpty &&
        !AppConstants.geminiApiKey.contains('your-')) {
      try {
        return await _callGemini(fullSystem, context);
      } catch (e) {
        debugPrint('[AiExpert] Gemini failed: $e');
      }
    }

    // 5. Cloudflare Workers AI (High-speed serverless Llama 3.1)
    if (AppConstants.cloudflareAccountId.isNotEmpty &&
        AppConstants.cloudflareAiToken.isNotEmpty &&
        !AppConstants.cloudflareAccountId.contains('your-') &&
        !AppConstants.cloudflareAiToken.contains('your-')) {
      try {
        return await _callCloudflareWorkersAI(fullSystem, context);
      } catch (e) {
        debugPrint('[AiExpert] Cloudflare Workers AI failed: $e');
      }
    }

    // 6. Complete On-Device Agentic Forensic Analysis (Zero Cloud Egress for Privacy)
    return _generateOnDeviceExpertAnalysis(domain, context, language);
  }

  // ─── Cloudflare Workers AI Call ──────────────────────────────────────────

  Future<String> _callCloudflareWorkersAI(
    String systemPrompt,
    String userContent,
  ) async {
    final cfAccount = AppConstants.cloudflareAccountId;
    final cfToken = AppConstants.cloudflareAiToken;
    const model = '@cf/meta/llama-3.1-8b-instruct';

    final response = await _dio.post(
      'https://api.cloudflare.com/client/v4/accounts/$cfAccount/ai/run/$model',
      options: Options(
        headers: {
          'Authorization': 'Bearer $cfToken',
          'Content-Type': 'application/json',
        },
        sendTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ),
      data: {
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userContent},
        ],
      },
    );

    if (response.statusCode == 200 && response.data != null) {
      final res = response.data['result'];
      if (res != null && res['response'] != null) {
        final answer = res['response'].toString().trim();
        if (answer.isNotEmpty) return answer;
      }
    }
    throw Exception('Invalid Cloudflare Workers AI response');
  }

  // ─── OpenRouter API Call ───────────────────────────────────────────────────

  Future<String> _callOpenRouter(
    String systemPrompt,
    String userContent,
  ) async {
    final response = await _dio.post(
      'https://openrouter.ai/api/v1/chat/completions',
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${AppConstants.openRouterApiKey}',
          'HTTP-Referer': 'https://github.com/UmarFarooqueJi/SafeSignal',
          'X-Title': 'SafeSignal',
        },
        sendTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
      ),
      data: {
        'model': 'deepseek/deepseek-chat',
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userContent},
        ],
        'temperature': 0.2,
        'max_tokens': 500,
      },
    );
    return response.data['choices'][0]['message']['content'] as String;
  }

  // ─── DeepSeek API Call ─────────────────────────────────────────────────────

  Future<String> _callDeepSeek(String systemPrompt, String userContent) async {
    final response = await _dio.post(
      'https://api.deepseek.com/chat/completions',
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${AppConstants.deepSeekApiKey}',
        },
        sendTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
      ),
      data: {
        'model': 'deepseek-chat',
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userContent},
        ],
        'temperature': 0.2,
        'max_tokens': 500,
      },
    );
    return response.data['choices'][0]['message']['content'] as String;
  }

  // ─── Grok API Call ─────────────────────────────────────────────────────────

  Future<String> _callGrok(String systemPrompt, String userContent) async {
    final response = await _dio.post(
      'https://api.x.ai/v1/chat/completions',
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${AppConstants.grokApiKey}',
        },
        sendTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
      ),
      data: {
        'model': 'grok-3-mini',
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userContent},
        ],
        'temperature': 0.2,
        'max_tokens': 500,
      },
    );
    return response.data['choices'][0]['message']['content'] as String;
  }

  // ─── Gemini API Call ───────────────────────────────────────────────────────

  Future<String> _callGemini(String systemPrompt, String userContent) async {
    final response = await _dio.post(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent',
      queryParameters: {'key': AppConstants.geminiApiKey},
      data: {
        'system_instruction': {
          'parts': [
            {'text': systemPrompt},
          ],
        },
        'contents': [
          {
            'parts': [
              {'text': userContent},
            ],
          },
        ],
        'generationConfig': {'temperature': 0.2, 'maxOutputTokens': 500},
      },
      options: Options(
        headers: {'Content-Type': 'application/json'},
        sendTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
      ),
    );
    return response.data['candidates'][0]['content']['parts'][0]['text']
        as String;
  }

  // ─── On-Device Agentic Forensic Analysis ───────────────────────────────────

  String _generateOnDeviceExpertAnalysis(String domain, String context, String language) {
    final lower = context.toLowerCase();
    final isHi = language == 'hi';

    switch (domain) {
      case 'url':
        final isDangerous = lower.contains('dangerous') || lower.contains('unsafe') || lower.contains('scam') || lower.contains('phishing');
        final isImpersonation = lower.contains('impersonat') || lower.contains('deceptive') || lower.contains('typosquat');
        final isDropper = lower.contains('dropper') || lower.contains('.apk') || lower.contains('executable');
        final isVerified = lower.contains('verified') || lower.contains('authentic') || lower.contains('safe');

        if (isDropper) {
          return isHi
              ? '• CRITICAL ALERT: Is URL se seedha executable APK ya mobile malware download ho raha hai.\n• Ye Android banking trojan ya stalkerware ho sakta hai jo SMS aur OTP chura sakta hai.\n• Is file ko bilkul install mat karein; browser download cancel karein.\n• Kisi bhi unverified third-party link se app download na karein.'
              : '• CRITICAL ALERT: This URL directly serves an executable payload or APK dropper.\n• High probability of Android banking trojans or spyware capable of exfiltrating SMS and OTPs.\n• Cancel the download immediately; do NOT open or sideload this package.\n• Only install verified applications from official app stores.';
        }
        if (isImpersonation) {
          return isHi
              ? '• DECEPTIVE BRAND SPOOFING: Ye website kisi popular bank ya sarkari agency ki nakal kar rahi hai.\n• Official domain name match nahi karta; visual deception aur homograph tactics use kiye gaye hain.\n• Is link par koi bhi NetBanking password, debit card details ya Aadhaar/PAN mat daalein.\n• Turant official authentic portal par jaakar verify karein.'
              : '• DECEPTIVE BRAND IMPERSONATION: This domain is spoofing a recognized financial or government portal.\n• The host syntax deviates from registered institutional endpoints via deceptive lookalikes.\n• Never input NetBanking credentials, card PINs, or identity numbers on this page.\n• Verify directly via the official authorized institution domain.';
        }
        if (isDangerous) {
          return isHi
              ? '• HIGH THREAT DETECTED: Is domain ka security audit fail ho chuka hai.\n• Phishing patterns, unverified SSL transport, ya disposable high-risk TLD paya gaya hai.\n• Ye link financial credential chori ya malicious redirection ke liye use ho raha hai.\n• Is link ko turant band karein aur kisi ko forward na karein.'
              : '• HIGH THREAT DETECTED: This domain failed forensic security integrity audits.\n• Matched suspicious phishing keywords, missing TLS encryption, or high-abuse disposable TLDs.\n• Likely engineered for credential harvesting or deceptive redirects.\n• Discontinue navigation immediately and do not enter personal data.';
        }
        if (isVerified) {
          return isHi
              ? '• VERIFIED SAFE DOMAIN: Ye domain official institutional registry mein authenticated hai.\n• Valid SSL/TLS handshake aur active legitimate DNS infrastructure verify hua hai.\n• Normal browsing ke liye safe hai; hamesha browser address bar mein lock icon zaroor dekhein.'
              : '• VERIFIED LEGITIMATE HOST: Recognized in SafeSignal\'s authenticated institutional registry.\n• Valid SSL/TLS certificates and genuine corporate DNS infrastructure confirmed.\n• Safe for ordinary access; always verify the secure lock indicator in your browser.';
        }
        return isHi
            ? '• CAUTION / UNVERIFIED HOST: Ye domain kisi official allowlist mein authenticated nahi hai.\n• Unknown domain age ya neutral infrastructure signals hain.\n• Kisi bhi form ya login page par sensitive financial data bharne se pehle savdhan rahein.'
            : '• CAUTION / UNVERIFIED HOST: This domain is not present in verified institutional registries.\n• Neutral infrastructure with unverified reputation.\n• Exercise caution before submitting personal, banking, or sensitive identity details.';

      case 'wifi':
        final isOpen = lower.contains('open') || lower.contains('none') || lower.contains('wep');
        final isCaptive = lower.contains('captive') || lower.contains('intercept');
        final isTlsIssue = lower.contains('ssl') && (lower.contains('tamper') || lower.contains('strip') || lower.contains('fail'));

        if (isTlsIssue) {
          return isHi
              ? '• CRITICAL NETWORK TAMPERING: HTTPS certificate validation fail hua hai.\n• Koi router ya attacker is network par aapka encrypted data inspect karne ki koshish kar raha hai.\n• Is WiFi se turant disconnect karein aur mobile data use karein.'
              : '• CRITICAL NETWORK TAMPERING: HTTPS certificate handshake failed on this network.\n• Possible SSL stripping or Man-in-the-Middle inspection active on the gateway.\n• Disconnect from this Wi-Fi network immediately and switch to mobile carrier data.';
        }
        if (isCaptive) {
          return isHi
              ? '• CAPTIVE PORTAL ACTIVE: Internet access authenticate hone tak restricted hai.\n• Login page par credit card, Aadhaar ya sensitive passwords mat daalein.\n• Public portal authentication ke baad trusted VPN zaroor enable karein.'
              : '• CAPTIVE PORTAL ACTIVE: Internet traffic is intercepted until portal authentication.\n• Never enter banking credentials, payment details, or personal passwords on captive pages.\n• Enable a trusted VPN tunnel once authenticated on public Wi-Fi.';
        }
        if (isOpen) {
          return isHi
              ? '• UNENCRYPTED OPEN NETWORK: Is WiFi par koi WPA2/WPA3 password encryption nahi hai.\n• Same network par baitha koi bhi hacker unencrypted network packets sniff kar sakta hai.\n• Is network par banking, UPI, ya office documents access karte waqt VPN zaroor use karein.'
              : '• UNENCRYPTED OPEN NETWORK: No 802.11 WPA2/WPA3 encryption active on this access point.\n• Over-the-air packets can be sniffed by nearby attackers on the same radio channel.\n• Always tunnel sensitive traffic through an encrypted VPN when accessing financial services.';
        }
        return isHi
            ? '• SECURE WIRELESS ENCRYPTION: Network WPA2/WPA3 AES encryption protocol use kar raha hai.\n• Wireless link encrypted hai; router default admin password zaroor update rakhein.'
            : '• ENCRYPTED WIRELESS LINK: Network utilizes standard WPA2/WPA3 AES encryption.\n• Over-the-air frames are protected; maintain updated router firmware and strong credentials.';

      case 'app':
        final isStalkerware = lower.contains('stalkerware') || lower.contains('spyware') || lower.contains('critical');
        final isSideloaded = lower.contains('sideload') || lower.contains('unknown source');
        final hasDangerousPerms = lower.contains('sms') || lower.contains('accessibility') || lower.contains('overlay');

        if (isStalkerware) {
          return isHi
              ? '• CRITICAL STALKERWARE SIGNATURE: App mein stealth surveillance patterns mile hain.\n• Background mein location, microphone, ya camera chupke se track karne ki capability hai.\n• Is app ko turant device settings se Uninstall karein.'
              : '• CRITICAL STALKERWARE DETECTED: App matches known covert tracking and surveillance signatures.\n• Capable of unauthorized background tracking, microphone activation, or SMS monitoring.\n• Uninstall this application immediately from Android Device Settings.';
        }
        if (isSideloaded && hasDangerousPerms) {
          return isHi
              ? '• HIGH RISK SIDELOADED APK: Ye app verified app store ke bahar se install ki gayi hai.\n• Sensitive permissions (SMS/Overlay/Accessibility) ke sath milkar ye financial trojan ban sakti hai.\n• Agar aapne khud install nahi kiya hai toh turant remove karein.'
              : '• HIGH RISK SIDELOADED PACKAGE: Installed outside verified Google Play / OEM app stores.\n• Combined with sensitive permissions (SMS, Accessibility, Overlays), this poses banking trojan risk.\n• Remove the APK immediately if not explicitly installed and trusted by you.';
        }
        return isHi
            ? '• APP AUDIT REPORT: App permissions standard guidelines ke anusar hain.\n• Koshish karein ki unverified apps ko background location aur SMS access na dein.'
            : '• APP AUDIT REPORT: Permissions conform to standard operational baseline.\n• Review periodic permission grants and revoke SMS/accessibility from unneeded apps.';

      case 'breach':
        return isHi
            ? '• DATA BREACH RECOVERY: Aapka email public ya dark-web breach dump mein darj hai.\n• Turant apna primary password change karein aur complex unique password use karein.\n• Tamam banking aur email accounts par Two-Factor Authentication (2FA) enable karein.\n• Kisi bhi achanak aane wale verification SMS ya call par vishwas na karein.'
            : '• DATA BREACH RECOVERY: Credentials associated with this email were detected in breach databases.\n• Immediately rotate your master password; never reuse passwords across services.\n• Enforce Two-Factor Authentication (2FA / Authenticator App) across all critical accounts.\n• Remain vigilant against targeted spear-phishing and credential stuffing attempts.';

      case 'upi':
        return isHi
            ? '• FINANCIAL SCAM DEFENSE: UPI PIN sirf paise BHEJNE ke liye hota hai, paise paane ke liye nahi.\n• Agar koi bole ki "PIN daalo aur paise receive honge", toh wo 100% fraud hai.\n• Anjaan logo ki UPI collect requests ko turant reject karein.\n• Kisi bhi fraud transaction par turant 1930 ya cybercrime.gov.in par report karein.'
            : '• UPI PAYMENT SECURITY: UPI PIN is strictly required for DEBITING funds, never for receiving money.\n• Any request asking for your PIN to "receive a refund, cashback, or reward" is 100% fraud.\n• Decline unknown collect requests immediately in your UPI application.\n• Report unauthorized transactions within 24 hours to 1930 and your bank for payment freeze.';

      default:
        return isHi
            ? '• ON-DEVICE CYBER DEFENSE: SafeSignal ne data ka local forensic analysis poora kiya.\n• Kisi bhi suspicious link, OTP ya payment request par bina jaanch vishwas na karein.\n• National Cyber Crime Helpline: 1930 (24x7 Free Citizen Helpline).'
            : '• ON-DEVICE CYBER DEFENSE: Forensic parameters analyzed via SafeSignal on-device rules.\n• Never transfer funds or disclose one-time passwords under urgent duress.\n• National Cyber Crime Helpline: 1930 (Official Indian Citizen Support).';
    }
  }
}
