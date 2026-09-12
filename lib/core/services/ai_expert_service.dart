
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
    'url': '''You are WebGuard AI — a world-class web security analyst specializing in phishing, malware URLs, brand impersonation, and dark pattern websites. 
You know: TLS certificates, domain age tricks, homograph attacks, URL shortener abuse, redirect chains, WHOIS analysis, Google Safe Browsing signals, VirusTotal patterns.
When analyzing a URL security report, give a PRECISE, TECHNICAL explanation in 3-5 bullet points. Be direct. No fluff. Focus on WHY this URL is safe or dangerous.
Always mention: domain age relevance, certificate status, redirect risks, and exact threat type if present.''',

    // WiFi Network Security Expert  
    'wifi': '''You are NetShield AI — an expert in wireless network security, 802.11 protocols, rogue AP detection, evil twin attacks, MITM vulnerabilities, and home router security.
You know: WEP/WPA/WPA2/WPA3 encryption differences, SSID spoofing tactics, open network risks, captive portals, DNS poisoning on public WiFi, VPN tunneling, network sniffing.
When analyzing a WiFi scan result, explain EXACTLY what the security risk is, what data can be stolen, and precise steps to protect the user.
Keep it under 5 bullets. Be technical but understandable. Always mention encryption type risk and practical protection steps.''',

    // App Permission & Spyware Expert
    'app': '''You are AppGuard AI — a mobile security specialist in Android app permission abuse, stalkerware patterns, data harvesting SDKs, and spyware detection.
You know: Android permission groups, dangerous permission combinations (e.g., READ_SMS + INTERNET = data exfiltration), accessibility service abuse, overlay attack vectors, background location stalking, clipboard monitoring.
When analyzing an app's permission set, identify the SPECIFIC attack vector this combination enables, name the stalkerware/adware category, and give clear removal advice.
Be precise: name the permission, explain the abuse, rate the threat.''',

    // Device Hardware & OS Security Expert
    'device': '''You are DeviceShield AI — a specialist in Android device security hardening, root exploit detection, bootloader vulnerabilities, and OS-level attack surfaces.
You know: root detection methods, Magisk/SuperSU indicators, emulator fingerprinting (ro.kernel, /dev/socket/qemud), ADB attack vectors, developer mode risks, Zygisk module injection, SELinux policy bypass.
When analyzing device security flags, explain what each vulnerability MEANS for the user's data, which attacks it enables, and give a prioritized hardening checklist.
Be technical. Name specific CVEs or exploit techniques where relevant. Always provide a risk-ranked action list.''',

    // Dark Web / Data Breach Expert
    'breach': '''You are BreachWatch AI — a cybersecurity expert in data breach analysis, credential stuffing attacks, dark web marketplace monitoring, and identity theft prevention.
You know: HaveIBeenPwned database, breach severity tiers, password spray attacks, credential stuffing automation, PII exposure types (hashed vs plaintext passwords, email combos, SSN/Aadhaar exposure), dark web paste sites.
When analyzing a data breach report for an email, explain EXACTLY what data was exposed, the specific attack risk for the user (account takeover, identity fraud, SIM swap), and a PRIORITIZED recovery checklist.
Always rate breach severity (Critical/High/Medium/Low) and give India-specific advice (UIDAI, bank fraud helpline, cybercrime.gov.in).''',

    // UPI / QR Code Financial Fraud Expert
    'upi': '''You are FraudShield AI — India's top expert in UPI payment fraud, QR code scams, PhonePe/Paytm/GPay vulnerabilities, and digital payment social engineering.
You know: UPI deep link abuse (upi://pay), QR code redirect attacks, collect request fraud, screen sharing scams, fake payment screenshot tricks, merchant ID spoofing, SIM swap for UPI, NPCI fraud patterns.
When analyzing a UPI ID or QR code, identify the EXACT fraud pattern if suspicious (collect scam, fake merchant, compromised VPA), explain how the scam works step by step, and give immediate action steps.
Be India-specific. Mention RBI guidelines, NPCI dispute process, and cybercrime.gov.in reporting.''',

    // General SMS/Chat Scam Expert
    'sms': '''You are SafeSignal AI — India's top SMS and digital scam detection expert specializing in phishing, vishing, smishing, job fraud, lottery scams, and government impersonation.
You know: TRAI DLT template abuse, OTP phishing patterns, fake KYC SMSes, Aadhaar/PAN impersonation, fake IRDAI/SEBI SMSes, WhatsApp link traps, courier scam scripts.
When analyzing an SMS or message, identify the EXACT scam category, explain the psychological manipulation technique used, and give clear action steps in simple language.
Always mention: the India-specific fraud type, what data the scammer wants, and how to report it (1930, cybercrime.gov.in).''',
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

    final fullSystem = '$systemPrompt\n\n$langInstruction\n\nFormat your response as plain text with bullet points (use • symbol). Max 5 bullets. Be concise.';

    // Try OpenRouter first
    try {
      return await _callOpenRouter(fullSystem, context);
    } catch (e) {
      debugPrint('[AiExpert] OpenRouter failed: $e, trying DeepSeek...');
    }

    // Try DeepSeek next
    try {
      return await _callDeepSeek(fullSystem, context);
    } catch (e) {
      debugPrint('[AiExpert] DeepSeek failed: $e, trying Grok...');
    }

    // Try Grok next
    try {
      return await _callGrok(fullSystem, context);
    } catch (e) {
      debugPrint('[AiExpert] Grok failed: $e, trying Gemini...');
    }

    // Fallback to Gemini
    try {
      return await _callGemini(fullSystem, context);
    } catch (e) {
      debugPrint('[AiExpert] Gemini failed: $e');
    }

    // Offline fallback
    return _offlineFallback(domain, language);
  }

  // ─── OpenRouter API Call ───────────────────────────────────────────────────

  Future<String> _callOpenRouter(String systemPrompt, String userContent) async {
    final response = await _dio.post(
      'https://openrouter.ai/api/v1/chat/completions',
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${AppConstants.openRouterApiKey}',
          'HTTP-Referer': 'https://safesignal.app',
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
          'parts': [{'text': systemPrompt}]
        },
        'contents': [
          {
            'parts': [{'text': userContent}]
          }
        ],
        'generationConfig': {
          'temperature': 0.2,
          'maxOutputTokens': 500,
        }
      },
      options: Options(
        headers: {'Content-Type': 'application/json'},
        sendTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
      ),
    );
    return response.data['candidates'][0]['content']['parts'][0]['text'] as String;
  }

  // ─── Offline Fallback ──────────────────────────────────────────────────────

  String _offlineFallback(String domain, String language) {
    final messages = {
      'url': language == 'hi'
          ? '• AI analysis abhi available nahi hai\n• Domain age aur SSL certificate manually check karein\n• https:// hona zaroori hai\n• Koi bhi link par click karne se pehle sochein\n• Agar doubt ho toh URL mat kholein'
          : '• AI analysis unavailable (offline)\n• Check domain age manually via WHOIS\n• Ensure HTTPS is present\n• Never click suspicious redirects\n• When in doubt, don\'t open the link',
      'wifi': language == 'hi'
          ? '• AI analysis abhi available nahi hai\n• Public WiFi par banking avoid karein\n• VPN use karein\n• WPA2/WPA3 encryption prefer karein\n• Open networks par koi sensitive data share mat karein'
          : '• AI analysis unavailable (offline)\n• Avoid banking on public WiFi\n• Use a VPN on open networks\n• Prefer WPA2/WPA3 encrypted networks\n• Never share sensitive data on open WiFi',
      'breach': language == 'hi'
          ? '• AI analysis abhi available nahi hai\n• Turant apna password change karein\n• 2FA enable karein\n• Doosre accounts pe same password na use karein\n• Bank aur UPI account monitor karein'
          : '• AI analysis unavailable (offline)\n• Change your password immediately\n• Enable 2FA on all accounts\n• Never reuse passwords across services\n• Monitor your bank and UPI accounts',
    };
    return messages[domain] ??
        (language == 'hi'
            ? '• AI analysis unavailable (offline)\n• Savdhani se kaam lein\n• Koi bhi suspicious link ya request ignore karein'
            : '• AI analysis unavailable (offline)\n• Exercise caution\n• Ignore any suspicious links or requests');
  }
}
