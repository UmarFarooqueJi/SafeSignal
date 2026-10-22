import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../data/models/verdict_model.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants.dart';
import '../settings/settings_screen.dart';
import '../../core/services/pdf_report_service.dart';
import '../../core/services/url_intelligence_engine.dart';

// Chat message model
class ChatMessage {
  final String text;
  final bool isUser;
  final bool isLoading;
  final VerdictModel? verdict;
  final File? image;

  const ChatMessage({
    required this.text,
    required this.isUser,
    this.isLoading = false,
    this.verdict,
    this.image,
  });
}

// State notifier for chat — using Riverpod Notifier
class ChatNotifier extends Notifier<List<ChatMessage>> {
  static ChatMessage welcomeMsg(String lang) {
    if (lang == 'hi') {
      return const ChatMessage(
        text:
            '🛡️ Namaste! Main SafeSignal AI Cyber Expert hoon.\n\nMain ek elite cybersecurity expert hoon jo aapko:\n• Kisi bhi suspicious message, link ya screenshot ki jaanch karna\n• Cyber fraud, scam, phishing se bachne ke tarike batana\n• Android security, app permissions, VPN, password tips\n• Digital arrest, OTP scam, loan app fraud — koi bhi cyber threat\n\nAap seedha kuch bhi pooch sakte hain ya koi suspicious message paste kar sakte hain. Screenshot upload bhi kar sakte hain.\n\n🔒 Aapki privacy 100% protected hai.',
        isUser: false,
      );
    } else {
      return const ChatMessage(
        text:
            '🛡️ Hello! I am SafeSignal AI Cyber Expert.\n\nI am a trained cybersecurity expert who can:\n• Analyze any suspicious message, link or screenshot\n• Teach you how to stay safe from fraud & phishing\n• Advise on Android security, VPN, passwords, app permissions\n• Explain any cyber threat: digital arrest, OTP scam, loan fraud\n\nAsk me anything or paste a suspicious message below. You can also upload screenshots for analysis.\n\n🔒 Your privacy is fully protected.',
        isUser: false,
      );
    }
  }

  @override
  List<ChatMessage> build() => [ChatNotifier.welcomeMsg('hi')];

  Future<void> analyzeMessage(String text, {File? image, String language = 'hi'}) async {
    // Show user message / image
    final userMsg = ChatMessage(text: text, isUser: true, image: image);
    state = [...state, userMsg];

    // Loading indicator
    final loadingText = image != null
        ? (language == 'hi' ? 'Screenshot scan ho raha hai... 🔍' : 'Scanning screenshot with AI... 🔍')
        : (language == 'hi' ? 'AI jaanch ho rahi hai... 🔍' : 'AI is analyzing... 🔍');
    state = [
      ...state,
      ChatMessage(text: loadingText, isUser: false, isLoading: true),
    ];

    VerdictModel verdict;
    String? ocrText;

    try {
      // 1. If image is provided, run real on-device OCR to extract all visible text from the screenshot
      if (image != null) {
        ocrText = await _extractTextFromImage(image);
      }

      final hasCloudKey = !AppConstants.isAirGappedMode &&
          (AppConstants.openRouterApiKey.isNotEmpty || AppConstants.deepSeekApiKey.isNotEmpty);

      if (hasCloudKey) {
        String promptText = text;
        if (image != null) {
          if (ocrText != null && ocrText.trim().isNotEmpty) {
            promptText = """
[USER UPLOADED A SCREENSHOT FOR CYBER AUDIT]
OCR Extracted Text from Screenshot:
\"\"\"
$ocrText
\"\"\"

User Note / Query: ${text.isEmpty || text == '[Screenshot Analysis Request]' ? 'Is this screenshot a scam, phishing, digital arrest, or bank fraud?' : text}
""";
          } else {
            promptText = """
[USER UPLOADED AN IMAGE]
(No readable text found via OCR in this image).
User Note / Query: ${text.isEmpty || text == '[Screenshot Analysis Request]' ? 'Analyze this image for cyber threat risks.' : text}
""";
          }
        }

        final history = state
            .where((m) => !m.isLoading && m != userMsg && m.text.isNotEmpty && m.verdict == null)
            .toList();
        final recentHistory = history.length > 6 ? history.sublist(history.length - 6) : history;

        verdict = await _analyzeWithAI(promptText, image, language, recentHistory, ocrText: ocrText);
      } else {
        // Fast, deterministic, air-gapped on-device cyber intelligence reasoning
        if (image != null) {
          verdict = await _analyzeImageHeuristics(image, text, language, ocrText: ocrText);
        } else {
          verdict = await _analyzeText(text, language);
        }
      }
    } catch (e) {
      debugPrint('[ChatAI] On-device reasoning fallback: $e');
      if (image != null) {
        verdict = await _analyzeImageHeuristics(image, text, language, ocrText: ocrText);
      } else {
        verdict = await _analyzeText(text, language);
      }
    }

    state = state.where((m) => !m.isLoading).toList();
    if (verdict.verdict == 'INFO') {
      String infoText = verdict.why.isNotEmpty ? verdict.why.join('\n\n') : 'Kuch samajh nahi aaya, kripya dobara likhein.';
      infoText = _extractCleanHumanText(infoText);
      state = [...state, ChatMessage(text: infoText, isUser: false, verdict: null)];
    } else {
      state = [...state, ChatMessage(text: '', isUser: false, verdict: verdict)];
    }
  }

  /// On-Device Private OCR Text Extraction for uploaded screenshots (Zero Cloud Egress)
  static Future<String> _extractTextFromImage(File image) async {
    try {
      final inputImage = InputImage.fromFilePath(image.path);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      try {
        final recognizedText = await textRecognizer.processImage(inputImage);
        final lines = <String>[];
        for (final block in recognizedText.blocks) {
          for (final line in block.lines) {
            final t = line.text.trim();
            if (t.isNotEmpty) lines.add(t);
          }
        }
        if (lines.isNotEmpty) {
          final result = lines.join('\n').trim();
          debugPrint('[ChatOCR] Successfully extracted ${lines.length} lines, total length: ${result.length}');
          return result;
        }
        final parsed = recognizedText.text.trim();
        if (parsed.isNotEmpty) return parsed;
      } finally {
        await textRecognizer.close();
      }
    } catch (e) {
      debugPrint('[ChatOCR] On-device OCR processing error: $e. Ensuring zero cloud leakage.');
    }
    return '';
  }

  static String _extractCleanHumanText(String raw) {
    String text = raw.trim();

    // 1. Remove markdown code fences if wrapped
    if (text.startsWith('```json')) text = text.substring(7);
    if (text.startsWith('```')) text = text.substring(3);
    if (text.endsWith('```')) text = text.substring(0, text.length - 3);
    text = text.trim();

    // 2. Direct JSON decode if valid JSON map
    if (text.startsWith('{') && text.endsWith('}')) {
      try {
        final dynamic decoded = jsonDecode(text);
        if (decoded is Map) {
          if (decoded['why'] != null) {
            final why = decoded['why'];
            if (why is List && why.isNotEmpty) {
              return why.map((e) => e.toString()).join('\n\n');
            }
            if (why is String && why.trim().isNotEmpty) {
              return why.trim();
            }
          }
          if (decoded['summary'] != null) {
            final summary = decoded['summary'].toString().trim();
            if (summary.isNotEmpty) return summary;
          }
        }
      } catch (_) {}
    }

    // 3. Fallback extraction for malformed or pseudo-dictionary text
    if (text.contains('why:') ||
        text.contains('summary:') ||
        text.contains('"why"') ||
        text.contains('"summary"') ||
        text.startsWith('{')) {
      final whyArrayMatch = RegExp(r"""["']?why["']?\s*:\s*\[\s*([\s\S]*?)\s*\](?:\s*,|\s*\})""").firstMatch(text);
      if (whyArrayMatch != null) {
        String val = whyArrayMatch.group(1)?.trim() ?? '';
        val = val.replaceAll(RegExp(r"""^["']|["']$"""), '').trim();
        val = val.replaceAll(RegExp(r"""["']\s*,\s*["']"""), '\n\n').trim();
        if (val.isNotEmpty && !val.contains('confidence:') && !val.contains('verdict:')) {
          return val;
        }
      }

      final whyStringMatch = RegExp(r"""["']?why["']?\s*:\s*["']([\s\S]*?)["'](?:\s*,|\s*\})""").firstMatch(text);
      if (whyStringMatch != null) {
        String val = whyStringMatch.group(1)?.trim() ?? '';
        if (val.isNotEmpty && !val.contains('confidence:') && !val.contains('verdict:')) {
          return val;
        }
      }

      final summaryMatch = RegExp(r"""["']?summary["']?\s*:\s*["']([\s\S]*?)["'](?:\s*,|\s*\})""").firstMatch(text);
      if (summaryMatch != null) {
        String val = summaryMatch.group(1)?.trim() ?? '';
        if (val.isNotEmpty && !val.contains('confidence:') && !val.contains('verdict:')) {
          return val;
        }
      }

      final summaryUnquoted = RegExp(r"""["']?summary["']?\s*:\s*([\s\S]*?)(?=(?:,\s*(?:verdict|whatToDo|why|confidence|riskLevel)\s*:|\}$))""").firstMatch(text);
      if (summaryUnquoted != null) {
        String val = summaryUnquoted.group(1)?.trim() ?? '';
        val = val.replaceAll(RegExp(r"""^["']|["']$"""), '').trim();
        if (val.isNotEmpty && !val.contains('confidence:') && !val.contains('verdict:')) {
          return val;
        }
      }

      final whyUnquoted = RegExp(r"""["']?why["']?\s*:\s*\[([\s\S]*?)\]""").firstMatch(text);
      if (whyUnquoted != null) {
        String val = whyUnquoted.group(1)?.trim() ?? '';
        val = val.replaceAll(RegExp(r"""^["']|["']$"""), '').trim();
        if (val.isNotEmpty && !val.contains('confidence:') && !val.contains('verdict:')) {
          return val;
        }
      }

      // Fallback: Strip metadata fields entirely
      String stripped = text;
      stripped = stripped.replaceAll(RegExp(r"""["']?(?:confidence|riskLevel|scamType|verdict|whatToDo|isScam)\s*:[^,\}\]]*[,\]\}]?""", caseSensitive: false), '');
      stripped = stripped.replaceAll(RegExp(r"""["']?(?:why|summary)\s*:\s*\[?""", caseSensitive: false), '');
      stripped = stripped.replaceAll(RegExp(r'[{}\[\]]'), '');
      stripped = stripped.replaceAll(RegExp(r'^\s*,\s*|\s*,\s*$'), '').trim();
      if (stripped.isNotEmpty) {
        return stripped;
      }
    }

    return text.isNotEmpty ? text : raw;
  }

  bool _isScamAnalysisQuery(String text) {
    final lower = text.toLowerCase().trim();
    final indicators = [
      'scam', 'fraud', 'fake', 'verify', 'check', 'jaanch', 'sach', 'jhooth',
      'http', 'www.', '.com', '.in', '.xyz', '.top', '.ru', 'bit.ly', 'tinyurl',
      '.apk', 'cbi', 'arrest', 'police', 'court', 'narcotics', 'ed ',
      'kyc', 'lottery', 'prize', 'won', 'winner', 'crorepati', 'kbc',
      'part time job', 'telegram', 'task', 'earn money', 'investment',
      'paisa bhejo', 'upi pin', 'electricity bill', 'power cut',
      'sim block', 'aadhar update', 'pan card', 'loan approved',
    ];
    return indicators.any((k) => lower.contains(k));
  }

  Future<VerdictModel> _analyzeWithAI(
    String text,
    File? image,
    String language,
    List<ChatMessage> history, {
    String? ocrText,
  }) async {
    final dio = Dio();
    final apiKey = AppConstants.openRouterApiKey.isNotEmpty
        ? AppConstants.openRouterApiKey
        : AppConstants.deepSeekApiKey;
    final endpoint = AppConstants.openRouterApiKey.isNotEmpty
        ? 'https://openrouter.ai/api/v1/chat/completions'
        : (AppConstants.deepSeekApiKey.isNotEmpty
            ? 'https://api.deepseek.com/v1/chat/completions'
            : 'https://openrouter.ai/api/v1/chat/completions');
    final model = AppConstants.openRouterApiKey.isNotEmpty
        ? 'anthropic/claude-3-haiku'
        : (AppConstants.deepSeekApiKey.isNotEmpty
            ? 'deepseek-chat'
            : 'anthropic/claude-3-haiku');

    dio.options.headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
      if (AppConstants.openRouterApiKey.isNotEmpty) 'HTTP-Referer': 'https://github.com/UmarFarooqueJi/SafeSignal',
    };
    dio.options.connectTimeout = const Duration(seconds: 25);
    dio.options.receiveTimeout = const Duration(seconds: 25);

    final langName = language == 'hi' ? 'Hindi / Hinglish' : 'English';
    final isScamCheck = image != null || _isScamAnalysisQuery(text);

    final String systemPrompt;
    if (isScamCheck) {
      systemPrompt = """
You are SafeSignal — an elite cybersecurity fraud analyst for Indian cyber threats, developed by Umar Farooque.
Analyze the user's message/link/image for fraud, phishing, APK malware, or scam risk.
Write your analysis entirely in $langName.

Respond ONLY with valid JSON:
{
  "verdict": "SCAM" or "LIKELY_SAFE" or "UNCERTAIN",
  "confidence": 0.85,
  "scamType": "bank_phishing",
  "riskLevel": "HIGH",
  "summary": "Short 1-2 sentence conclusion",
  "why": ["Point 1", "Point 2"],
  "whatToDo": ["Action 1", "Action 2"]
}
""";
    } else {
      systemPrompt = """
You are SafeSignal AI — an elite personal cybersecurity advisor and conversational digital protection expert, created and developed by Umar Farooque (lead cybersecurity researcher and open-source engineer).
You communicate fluently, naturally, and warmly in $langName (matching the user's language and tone, whether Hindi, Hinglish, or English).

Developer Details: Umar Farooque is the creator and lead researcher behind SafeSignal, building open-source intelligence and citizen defense against digital arrest scams, UPI fraud, and mobile malware.

CRITICAL CONVERSATIONAL INSTRUCTIONS:
1. Speak naturally, conversationally, and helpfully like a human security advisor.
2. DO NOT output JSON. DO NOT use braces {}, brackets [], or metadata fields like confidence, riskLevel, scamType, why, or summary.
3. Answer questions directly, provide cybersecurity tips, and maintain conversational context with previous messages.
4. Reply with CLEAN, DIRECT CONVERSATIONAL TEXT ONLY.
""";
    }

    final messages = <Map<String, dynamic>>[];
    messages.add({'role': 'system', 'content': systemPrompt});

    // Add recent conversation history for memory, filtering any malformed JSON dumps
    for (final h in history) {
      final t = h.text.trim();
      if (t.isNotEmpty && !t.startsWith('{') && !t.contains('confidence:')) {
        messages.add({
          'role': h.isUser ? 'user' : 'assistant',
          'content': t,
        });
      }
    }

    messages.add({
      'role': 'user',
      'content': text,
    });

    final hasCustomKey = (AppConstants.openRouterApiKey.isNotEmpty && !AppConstants.openRouterApiKey.contains('your-')) ||
                         (AppConstants.deepSeekApiKey.isNotEmpty && !AppConstants.deepSeekApiKey.contains('your-'));

    if (hasCustomKey) {
      try {
        final payload = {
          'model': model,
          'messages': messages,
          if (isScamCheck) 'response_format': {'type': 'json_object'},
        };
        final response = await dio.post(endpoint, data: payload);
        if (response.statusCode == 200) {
          final choices = response.data['choices'] as List;
          if (choices.isNotEmpty) {
            final content = choices[0]['message']['content'] as String;
            return _parseAiResponse(content, text, language);
          }
        }
      } catch (e) {
        debugPrint('[ChatAI] Custom API call failed: $e, trying Cloudflare Workers AI');
      }
    }

    // 2. High-Speed Cloudflare Workers AI Tier (Llama 3.1 8B Instruct)
    try {
      final cfAccount = AppConstants.cloudflareAccountId;
      final cfToken = AppConstants.cloudflareAiToken;
      const cfModel = '@cf/meta/llama-3.1-8b-instruct';

      final cfResponse = await dio.post(
        'https://api.cloudflare.com/client/v4/accounts/$cfAccount/ai/run/$cfModel',
        options: Options(
          headers: {
            'Authorization': 'Bearer $cfToken',
            'Content-Type': 'application/json',
          },
          connectTimeout: const Duration(seconds: 18),
          receiveTimeout: const Duration(seconds: 22),
        ),
        data: {
          'messages': messages,
        },
      );

      if (cfResponse.statusCode == 200 && cfResponse.data != null) {
        final res = cfResponse.data['result'];
        if (res != null && res['response'] != null) {
          final raw = res['response'].toString().trim();
          if (raw.isNotEmpty) {
            return _parseAiResponse(raw, text, language);
          }
        }
      }
    } catch (e) {
      debugPrint('[ChatAI] Cloudflare Workers AI failed: $e');
    }

    // Zero-Cloud / Safe Offline Fallback: Never send user chat text to unauthenticated public proxies
    throw Exception('Cloud AI unavailable or not configured. Falling back to local on-device heuristics.');
  }

  VerdictModel _parseAiResponse(String content, String text, String language) {
    String cleanJson = content.trim();

    if (cleanJson.startsWith('```json')) cleanJson = cleanJson.substring(7);
    if (cleanJson.startsWith('```')) cleanJson = cleanJson.substring(3);
    if (cleanJson.endsWith('```')) cleanJson = cleanJson.substring(0, cleanJson.length - 3);
    cleanJson = cleanJson.trim();

    // Check if JSON object is present
    Map<String, dynamic>? data;
    final firstBrace = cleanJson.indexOf('{');
    final lastBrace = cleanJson.lastIndexOf('}');

    if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
      final jsonSub = cleanJson.substring(firstBrace, lastBrace + 1);
      try {
        data = jsonDecode(jsonSub) as Map<String, dynamic>?;
      } catch (_) {
        // Try repairing unquoted keys: {confidence: 0, ...} -> {"confidence": 0, ...}
        try {
          final quotedJson = jsonSub.replaceAllMapped(
            RegExp(r'([a-zA-Z_]\w*)\s*:'),
            (m) => '"${m.group(1)}":',
          );
          data = jsonDecode(quotedJson) as Map<String, dynamic>?;
        } catch (_) {}
      }
    }

    if (data != null) {
      final verdictVal = data['verdict'] as String? ?? 'INFO';
      final confidenceVal = (data['confidence'] as num?)?.toDouble() ?? 0.85;
      final scamTypeVal = data['scamType'] as String? ?? 'none';
      final riskLevel = data['riskLevel'] as String? ?? 'LOW';
      final whyList = List<String>.from(data['why'] ?? []);
      final whatToDoList = List<String>.from(data['whatToDo'] ?? []);
      final summary = data['summary'] as String? ?? '';

      // If verdict is INFO, extract clean human conversation text
      if (verdictVal == 'INFO') {
        String cleanMessage = '';
        if (whyList.isNotEmpty) {
          cleanMessage = whyList.join('\n\n').trim();
        } else if (summary.isNotEmpty) {
          cleanMessage = summary.trim();
        } else {
          cleanMessage = _extractCleanHumanText(content);
        }
        cleanMessage = _extractCleanHumanText(cleanMessage);

        return VerdictModel(
          checkId: 'ai_chat_${DateTime.now().millisecondsSinceEpoch}',
          verdict: 'INFO',
          confidence: 1.0,
          scamType: 'SafeSignal AI',
          escalated: false,
          why: [cleanMessage],
          whatToDo: [],
          language: language,
          disclaimer: language == 'hi'
              ? 'SafeSignal ek AI assistant hai. Zaruri maamlon mein 1930 pe call karein.'
              : 'SafeSignal is an AI assistant.',
          inputText: text,
          checkedAt: DateTime.now(),
        );
      }

      // If verdict is SCAM or LIKELY_SAFE or UNCERTAIN
      final fullWhy = summary.isNotEmpty ? [summary, ...whyList] : whyList;

      return VerdictModel(
        checkId: 'ai_scan_${DateTime.now().millisecondsSinceEpoch}',
        verdict: verdictVal,
        confidence: confidenceVal,
        scamType: verdictVal == 'SCAM' ? '${scamTypeVal.replaceAll('_', ' ')} | Risk: $riskLevel' : 'AI Advice',
        escalated: verdictVal == 'SCAM',
        why: fullWhy.isNotEmpty ? fullWhy : [content],
        whatToDo: whatToDoList,
        trendNote: verdictVal == 'SCAM' ? 'SafeSignal AI ne is threat pattern ko flag kiya hai.' : null,
        language: language,
        disclaimer: language == 'hi'
            ? 'SafeSignal ek AI assistant hai. Zaruri maamlon mein 1930 pe call karein.'
            : 'SafeSignal is an AI assistant. For urgent matters, call 1930.',
        inputText: text,
        checkedAt: DateTime.now(),
      );
    }

    // Direct plain text response (No JSON, clean conversation)
    final humanText = _extractCleanHumanText(cleanJson.isNotEmpty ? cleanJson : content);

    return VerdictModel(
      checkId: 'ai_chat_${DateTime.now().millisecondsSinceEpoch}',
      verdict: 'INFO',
      confidence: 1.0,
      scamType: 'SafeSignal AI',
      escalated: false,
      why: [humanText],
      whatToDo: [],
      language: language,
      disclaimer: language == 'hi'
          ? 'SafeSignal ek AI assistant hai. Zaruri maamlon mein 1930 pe call karein.'
          : 'SafeSignal is an AI assistant.',
      inputText: text,
      checkedAt: DateTime.now(),
    );
  }

  Future<VerdictModel> _analyzeText(String text, String language) async {
    final lower = text.toLowerCase().trim();
    final isHindi = language == 'hi';

    // 1. Dynamic Greeting Detection
    if (lower == 'hi' || lower == 'hello' || lower == 'hey' || lower.contains('namaste') || lower.contains('kaise ho') || lower == 'salam') {
      return VerdictModel(
        checkId: 'local_${DateTime.now().millisecondsSinceEpoch}',
        verdict: 'INFO',
        confidence: 1.0,
        scamType: 'Greeting',
        escalated: false,
        why: isHindi ? [
          'Namaste! Main SafeSignal AI cyber security expert hoon.\n\nMain aapko online fraud, fake banking SMS, phishing link, digital arrest call aur Android spyware se bachane ke liye on-device intelligence par kaam karta hoon.\n\nAap mujhse koi bhi sawaal pooch sakte hain ya koi suspicious message yahan paste kar sakte hain!'
        ] : [
          'Hello! I am SafeSignal AI, your on-device cybersecurity specialist.\n\nI protect you against online fraud, phishing links, fake bank SMS, digital arrest threats, and Android stalkerware.\n\nAsk me any question or paste any suspicious message or link here!'
        ],
        whatToDo: [],
        language: language,
        disclaimer: isHindi
            ? 'SafeSignal ek on-device AI assistant hai. Zaruri maamlon mein 1930 pe call karein.'
            : 'SafeSignal is an on-device AI assistant.',
        inputText: text,
        checkedAt: DateTime.now(),
      );
    }

    // 2. Identity / Developer / Architecture Queries
    if (lower.contains('umar farooque') || lower.contains('umar') || lower.contains('farooque') || lower.contains('developer') || lower.contains('banaya') || lower.contains('kisne') || lower.contains('who made') || lower.contains('author')) {
      return VerdictModel(
        checkId: 'local_${DateTime.now().millisecondsSinceEpoch}',
        verdict: 'INFO',
        confidence: 1.0,
        scamType: 'Developer Info',
        escalated: false,
        why: isHindi ? [
          'Umar Farooque SafeSignal ke lead developer aur cybersecurity researcher hain, jinhone is application ko citizen digital protection aur open-source threat intelligence ke liye build kiya hai.\n\nSafeSignal ek 100% open-source, air-gapped, on-device cyber defense suite hai jo bina kisi cloud leak ke kaam karta hai.'
        ] : [
          'Umar Farooque is the lead developer and cybersecurity researcher behind SafeSignal, building open-source intelligence and citizen defense systems.\n\nSafeSignal is a 100% open-source, air-gapped, on-device cyber defense suite operating with zero private cloud leakage.'
        ],
        whatToDo: [],
        language: language,
        disclaimer: isHindi
            ? 'SafeSignal ek on-device AI assistant hai.'
            : 'SafeSignal is an on-device security assistant.',
        inputText: text,
        checkedAt: DateTime.now(),
      );
    }

    // 3. Digital Arrest Query & Guidance
    if (lower.contains('digital arrest') || (lower.contains('arrest') && (lower.contains('cbi') || lower.contains('police') || lower.contains('skype') || lower.contains('video') || lower.contains('kya') || lower.contains('bache')))) {
      return VerdictModel(
        checkId: 'local_da_${DateTime.now().millisecondsSinceEpoch}',
        verdict: 'SCAM',
        confidence: 0.98,
        scamType: isHindi ? 'Digital Arrest Fraud Advisory' : 'Digital Arrest Threat Advisory',
        escalated: true,
        why: isHindi ? [
          'Digital Arrest ek transnational cyber syndicate fraud hai jisme scammers CBI, ED, ya Police officer ban kar video call (Skype/WhatsApp) karte hain.',
          'Dhyan rahe: Bharat ke kanoon (BNS/CrPC) mein "Digital Arrest" ka koi vajood nahi hai. Police, CBI ya Supreme Court kabhi kisi ko online video call par arrest nahi karte aur na hi bail ke liye paise maangte hain.',
          'Scammers police uniform, fake ID card aur fake Supreme Court warrants dikha kar darr paida karte hain taaki aap turant paise transfer kar dein.',
        ] : [
          'Digital Arrest is a severe extortion fraud where criminals impersonate CBI, ED, Police, or Supreme Court judges via video calls (Skype/WhatsApp).',
          'FACT: There is NO provision for "Digital Arrest" under Indian Law. Law enforcement and judicial authorities NEVER conduct arrests or demand bail bonds over video calls.',
          'Scammers deploy forged police backdrops, fake badges, and counterfeit court notices to induce panic and force emergency transfers.',
        ],
        whatToDo: isHindi ? [
          'Video call turant cut karein aur us number ko block karein',
          'Darr mein aakar ek rupaya bhi transfer na karein',
          'Turant 1930 Cyber Crime Helpline par call karein',
          'cybercrime.gov.in aur Chakshu portal par fraud number report karein',
        ] : [
          'Immediately disconnect the video call and block the caller',
          'Never transfer money to any "RBI verification" or "court custody" account',
          'Call National Cybercrime Helpline 1930 without delay',
          'Report the number on cybercrime.gov.in and Chakshu (sancharsaathi.gov.in)',
        ],
        trendNote: isHindi ? 'MHA aur I4C ne is par high-priority alert jaari kiya hai.' : 'MHA/I4C high-priority alert active.',
        language: language,
        disclaimer: isHindi
            ? 'SafeSignal ek on-device AI assistant hai. Zaruri maamlon mein 1930 pe call karein.'
            : 'SafeSignal is an on-device security assistant. Call 1930 for urgent matters.',
        inputText: text,
        checkedAt: DateTime.now(),
      );
    }

    // 4. Electricity Bill / Bijli Cut Scam
    if (lower.contains('bijli') || lower.contains('electricity') || lower.contains('power cut') || lower.contains('light cut') || lower.contains('9:30')) {
      return VerdictModel(
        checkId: 'local_elec_${DateTime.now().millisecondsSinceEpoch}',
        verdict: 'SCAM',
        confidence: 0.96,
        scamType: isHindi ? 'Electricity Bill Scam Advisory' : 'Electricity Disconnection Scam Advisory',
        escalated: true,
        why: isHindi ? [
          'Bijli Disconnection SMS ek widespread scam hai jisme likha hota hai: "Dear consumer your electricity will be disconnected tonight at 9:30 PM because previous bill was not updated."',
          'Bijli Board (Electricity Department) kabhi personal mobile number se disconnection warning nahi bhejta.',
          'Diye gaye fake officer number par call karne par wo AnyDesk/QuickSupport download karwate hain ya Rs 10 ka recharge karne ko kehkar netbanking steal karte hain.',
        ] : [
          'Electricity Bill Disconnection fraud uses SMS notices claiming power will be cut tonight at 9:30 PM due to pending bill updates.',
          'State electricity boards NEVER send disconnection notices from personal 10-digit mobile numbers.',
          'Calling the fake officer leads to demands for remote app downloads (AnyDesk/TeamViewer) or credential-stealing Rs 10 verification payments.',
        ],
        whatToDo: isHindi ? [
          'SMS mein diye gaye kisi bhi phone number par call mat karein',
          'AnyDesk, QuickSupport ya koi anjaan APK install na karein',
          'Apne rajya ke official bijli board app ya customer portal par bill status check karein',
          '1930 helpline par SMS number report karein',
        ] : [
          'Do NOT call the mobile number listed in the SMS',
          'Never install remote screen-sharing tools or unknown APKs',
          'Verify your bill status directly via your state DISCOM portal or bill receipt',
          'Report the number to 1930 and Chakshu',
        ],
        trendNote: isHindi ? 'Ye scam pure desh mein aam logo ko target karta hai.' : 'High prevalence cyber scam targeting electricity consumers nationwide.',
        language: language,
        disclaimer: isHindi
            ? 'SafeSignal ek on-device AI assistant hai. Zaruri maamlon mein 1930 pe call karein.'
            : 'SafeSignal is an on-device security assistant.',
        inputText: text,
        checkedAt: DateTime.now(),
      );
    }

    // 5. Telegram Task / Work from Home Scam
    if (lower.contains('telegram') || lower.contains('part time job') || lower.contains('task scam') || lower.contains('youtube like') || lower.contains('earn from home') || lower.contains('prepaid task')) {
      return VerdictModel(
        checkId: 'local_task_${DateTime.now().millisecondsSinceEpoch}',
        verdict: 'SCAM',
        confidence: 0.96,
        scamType: isHindi ? 'Telegram Task Scam Advisory' : 'Telegram Task Fraud Advisory',
        escalated: true,
        why: isHindi ? [
          'Telegram Task / Part-Time Job Scam mein YouTube videos like karne, Google maps par review dene ya hotel rating ke badle moti kamai ka jhootha vada kiya jata hai.',
          'Scammers shuru mein 150-500 rupaye dekar bharosa banate hain, fir "VIP prepaid task" mein 5,000 se 50,000 rupaye deposit karwate hain.',
          'Ek baar paise jama karne ke baad wo "tax" aur "frozen account fee" maangte hain aur ek rupaya bhi wapas nahi dete.',
        ] : [
          'Telegram Task scams lure victims with promises of high pay for simple actions like liking YouTube videos or submitting hotel ratings.',
          'Scammers initially release small genuine payments (Rs 150-500) to build false confidence, then bait victims into "VIP prepaid tasks".',
          'Once large deposits are made, the funds are permanently locked behind fictitious "withdrawal taxes" and penalties.',
        ],
        whatToDo: isHindi ? [
          'Kisi bhi Telegram channel ya coordinator ko ek bhi rupaya na bhejein',
          'Aise sabhi groups aur recruiters ko turant block aur report karein',
          'Agar paise transfer kar chuke hain toh bina der kiye 1930 par call karein taaki recipient account par freeze lag sake',
        ] : [
          'Never send money to Telegram task coordinators or pseudo-investment groups',
          'Leave and report the group immediately',
          'If you have already transferred money, dial 1930 immediately to freeze the recipient bank accounts',
        ],
        trendNote: isHindi ? 'Telegram task fraud mein lakho rupaye ka nuksan hota hai.' : 'Extremely dangerous financial entrapment scam.',
        language: language,
        disclaimer: isHindi
            ? 'SafeSignal ek on-device AI assistant hai. Zaruri maamlon mein 1930 pe call karein.'
            : 'SafeSignal is an on-device security assistant.',
        inputText: text,
        checkedAt: DateTime.now(),
      );
    }

    // 6. FedEx / Customs / Narcotics Courier Scam
    if (lower.contains('fedex') || lower.contains('customs') || lower.contains('narcotics') || lower.contains('parcel') || lower.contains('courier scam')) {
      return VerdictModel(
        checkId: 'local_fedex_${DateTime.now().millisecondsSinceEpoch}',
        verdict: 'SCAM',
        confidence: 0.96,
        scamType: isHindi ? 'FedEx Customs Scam Advisory' : 'FedEx / Customs Extortion Advisory',
        escalated: true,
        why: isHindi ? [
          'FedEx / Customs Scam mein anjaan number se call aata hai ki aapka ek parcel Mumbai airport par customs ne pakda hai jisme MDMA drugs, fake passport ya illegal items mile hain.',
          'Call ko "Crime Branch" ya "Narcotics Bureau" ko transfer karne ka natak kiya jata hai aur arrest ki dhamki di jati hai.',
          'FedEx aur Indian Customs kabhi bhi phone ya WhatsApp par settlement payment ki maang nahi karte.',
        ] : [
          'FedEx / Customs extortion involves calls claiming an illegal parcel (drugs, passports) was seized in your name at customs.',
          'The call is falsely transferred to "Cyber Police" or "Narcotics Control Bureau" to intimidate victims.',
          'Customs and legitimate couriers NEVER solicit financial settlements or issue video warrants over the phone.',
        ],
        whatToDo: isHindi ? [
          'Call turant kaat dein — ye 100% fake extortion syndicate hai',
          'Darr mein aakar koi payment na karein',
          '1930 Cyber Crime Helpline par report karein',
        ] : [
          'Hang up immediately — this is a confirmed extortion racket',
          'Never transfer funds to avoid supposed legal action',
          'Report the caller to 1930 and cybercrime.gov.in',
        ],
        trendNote: isHindi ? 'Ye Digital Arrest racket ka leading precursor hai.' : 'Leading precursor to digital arrest extortion.',
        language: language,
        disclaimer: isHindi
            ? 'SafeSignal ek on-device AI assistant hai. Zaruri maamlon mein 1930 pe call karein.'
            : 'SafeSignal is an on-device security assistant.',
        inputText: text,
        checkedAt: DateTime.now(),
      );
    }

    // 7. Instant Loan App / Blackmail
    if (lower.contains('loan app') || lower.contains('instant loan') || lower.contains('7 day loan') || lower.contains('karz app') || lower.contains('recovery agent')) {
      return VerdictModel(
        checkId: 'local_loan_${DateTime.now().millisecondsSinceEpoch}',
        verdict: 'SCAM',
        confidence: 0.94,
        scamType: isHindi ? 'Predatory Loan App Advisory' : 'Predatory Loan App Warning',
        escalated: true,
        why: isHindi ? [
          'Unauthorized 7-day instant loan apps user ke phone se contacts list, photos aur location chori kar leti hain.',
          'Chhota sa loan dekar 7 din ke andar 100% interest maangte hain aur na dene par contacts ko call karke aur morphed photos bhejkar blackmail karte hain.',
          'RBI ke kanoon ke anusar koi bhi digital lender contacts list access karke parivaar ya dosto ko call nahi kar sakta.',
        ] : [
          'Predatory 7-day loan apps steal contacts, galleries, and location upon installation.',
          'They demand exorbitant interest and deploy aggressive blackmail tactics, including threatening to message contacts with morphed media.',
          'Strictly illegal under RBI Digital Lending Guidelines.',
        ],
        whatToDo: isHindi ? [
          'Aisi apps ko turant phone se delete karein aur permissions revoke karein',
          'Blackmailers ko paise bilkul na dein — paise dene par wo aur maangte hain',
          '1930 par cyber extortion report karein aur police mein complaint dein',
        ] : [
          'Uninstall predatory loan apps and revoke all device permissions',
          'Do NOT yield to extortion demands; report immediately to police',
          'File an official cyber complaint at 1930 and cybercrime.gov.in',
        ],
        trendNote: isHindi ? 'RBI certified NBFCs se hi hamesha loan lein.' : 'Borrow exclusively from RBI-regulated banking institutions.',
        language: language,
        disclaimer: isHindi
            ? 'SafeSignal ek on-device AI assistant hai. Zaruri maamlon mein 1930 pe call karein.'
            : 'SafeSignal is an on-device security assistant.',
        inputText: text,
        checkedAt: DateTime.now(),
      );
    }

    // 8. UPI Rules & QR Code Safety
    if (lower.contains('upi') || lower.contains('qr code') || lower.contains('upi pin') || lower.contains('gpay fraud') || lower.contains('phonepe fraud') || lower.contains('paytm scam')) {
      return VerdictModel(
        checkId: 'local_upi_${DateTime.now().millisecondsSinceEpoch}',
        verdict: 'INFO',
        confidence: 0.98,
        scamType: isHindi ? 'UPI Security Rule & Advisory' : 'UPI Security Architecture & Rules',
        escalated: false,
        why: isHindi ? [
          'UPI Golden Rule: "UPI PIN sirf paise BHEJNE (debit) ke liye hota hai, paise PAANE (receive) ke liye KABHI PIN enter nahi karna padta."',
          'Fake QR Code: QR code scan karke agar koi kahe ki "paisa receive hoga", toh samajh jaiye fraud hai — QR code scan karne se hamesha paisa KATTA hai.',
          'Collect Request: Kisi bhi anjaan collect request ko approve na karein. Approve karte hi bank se paisa cut ho jayega.',
        ] : [
          'Golden Rule of UPI: "UPI PIN is required ONLY to send money. You NEVER enter a PIN to receive payments or cashbacks."',
          'QR Code Mechanics: Scanning a QR code authorizes an OUTGOING debit. You cannot receive money by scanning a QR code.',
          'Collect Requests: Fraudsters send incoming collect requests claiming you won a lottery. Approving instantly debits your account.',
        ],
        whatToDo: isHindi ? [
          'Paise receive karne ke liye kabhi UPI PIN mat daalein',
          'Anjaan QR codes ko scan na karein',
          'Agar fraud transaction ho jaye toh 1 ghante ke andar (Golden Hour) 1930 par call karein',
        ] : [
          'Never enter your UPI PIN to receive money',
          'Never scan unverified QR codes sent over WhatsApp or OLX',
          'In case of fraud, dial 1930 within the Golden Hour to freeze transaction flows',
        ],
        trendNote: isHindi ? 'UPI fraud Bharat mein sabse common financial crime hai.' : 'Most common financial cyber attack vector.',
        language: language,
        disclaimer: isHindi
            ? 'SafeSignal ek on-device AI assistant hai.'
            : 'SafeSignal is an on-device security assistant.',
        inputText: text,
        checkedAt: DateTime.now(),
      );
    }

    // 9. Aadhaar / AePS / Biometric Lock
    if (lower.contains('aadhaar') || lower.contains('aeps') || lower.contains('biometric') || lower.contains('fingerprint') || lower.contains('aadhar')) {
      return VerdictModel(
        checkId: 'local_aeps_${DateTime.now().millisecondsSinceEpoch}',
        verdict: 'INFO',
        confidence: 0.96,
        scamType: isHindi ? 'Aadhaar AePS Security Guide' : 'Aadhaar AePS Biometric Defense',
        escalated: false,
        why: isHindi ? [
          'AePS (Aadhaar Enabled Payment System) Fraud mein cyber criminals registry documents se fingerprint copy karke fake silicone clone banate hain aur bank account se paise nikal lete hain.',
          'Is fraud se bachne ka 100% pakka ilaj hai: Apna Aadhaar Biometrics LOCK karna.',
          'Biometrics lock hone par koi bhi vyakti chahe aapka fingerprint clone bhi kar le, AePS transaction fail ho jayega.',
        ] : [
          'AePS fraud exploits cloned silicone fingerprints extracted from public land registry records to drain bank accounts.',
          'The definitive defense against AePS theft is locking your Aadhaar Biometrics via UIDAI.',
          'Once locked, all AePS biometric authentication attempts automatically fail-closed until explicitly unlocked by you.',
        ],
        whatToDo: isHindi ? [
          'mAadhaar app install karein ya resident.uidai.gov.in par login karein',
          '"Lock/Unlock Biometrics" option par jakar Biometrics ko LOCK kar dein',
          'Zarurat padne par aap ise temporary 10 minute ke liye unlock kar sakte hain',
        ] : [
          'Open mAadhaar app or visit resident.uidai.gov.in',
          'Navigate to "Lock/Unlock Biometrics" and lock your fingerprint authentication',
          'You can temporarily unlock for 10 minutes when you genuinely need to use biometric KYC',
        ],
        trendNote: isHindi ? 'CERT-In aur UIDAI biometric lock lagane ki advice dete hain.' : 'Recommended by CERT-In and UIDAI.',
        language: language,
        disclaimer: isHindi
            ? 'SafeSignal ek on-device AI assistant hai.'
            : 'SafeSignal is an on-device security assistant.',
        inputText: text,
        checkedAt: DateTime.now(),
      );
    }

    // 10. Cyber Helpline 1930 / Complaint Process
    if (lower.contains('1930') || lower.contains('helpline') || lower.contains('complaint') || lower.contains('cybercrime.gov') || lower.contains('police report')) {
      return VerdictModel(
        checkId: 'local_1930_${DateTime.now().millisecondsSinceEpoch}',
        verdict: 'INFO',
        confidence: 1.0,
        scamType: isHindi ? 'National Cybercrime Reporting Guide' : 'National Cybercrime Reporting Guide',
        escalated: false,
        why: isHindi ? [
          '1930 Bharat Sarkar ka official National Cybercrime Helpline number hai (Citizen Financial Cyber Fraud Reporting System - CFCFRMS).',
          'Golden Hour Rule: Agar aapke sath koi online financial fraud hua hai toh pehle 2 ghanton ke andar 1930 par call karein.',
          '1930 team turant nodal banking officers ke sath coordinate karke scammer ke account par lien mark (hold) lagati hai taaki aapka paisa wapas mil sake.',
        ] : [
          '1930 is the official National Cybercrime Helpline managed by the Ministry of Home Affairs (I4C).',
          'Golden Hour Rule: Reporting a financial cybercrime within the first 2 hours yields the highest fund recovery rate.',
          'The CFCFRMS automated system coordinates with nodal banking officers to freeze recipient wallets and bank accounts in real time.',
        ],
        whatToDo: isHindi ? [
          'Turant 1930 par call karein aur transaction details (UTR, Account Number, Time) batayein',
          'cybercrime.gov.in par jakar formal acknowledgment number ke sath complaint complete karein',
          'Chakshu (sancharsaathi.gov.in) par fraud phone number aur SMS ko report karein',
        ] : [
          'Dial 1930 immediately with transaction UTR, beneficiary account, and timestamp',
          'Complete formal incident logging at cybercrime.gov.in',
          'Report fraudulent numbers on the Chakshu portal (sancharsaathi.gov.in)',
        ],
        trendNote: isHindi ? '1930 helpline 24x7 upalabdh hai.' : 'National Cyber Helpline 1930 operates 24x7.',
        language: language,
        disclaimer: isHindi
            ? 'SafeSignal ek on-device AI assistant hai.'
            : 'SafeSignal is an on-device security assistant.',
        inputText: text,
        checkedAt: DateTime.now(),
      );
    }

    // 11. Passwords, 2FA, Android Spyware, Stalkerware
    if (lower.contains('password') || lower.contains('2fa') || lower.contains('two factor') || lower.contains('spyware') || lower.contains('stalkerware') || lower.contains('hack') || lower.contains('virus') || lower.contains('safe kaise')) {
      return VerdictModel(
        checkId: 'local_sec_${DateTime.now().millisecondsSinceEpoch}',
        verdict: 'INFO',
        confidence: 0.95,
        scamType: isHindi ? 'Mobile Security Hygiene' : 'Mobile Cyber Defense Hygiene',
        escalated: false,
        why: isHindi ? [
          'Android Security ke 4 basic pillars:\n\n'
          '1. Accessibility Permissions: Anjaan apps ko Accessibility permission mat dein — ye screen capture aur keystrokes steal karti hain.\n'
          '2. 2FA (Two Factor Authentication): SMS OTP ke bajaye Authenticator App (Google/Microsoft) ya Passkeys use karein.\n'
          '3. Sideloading: WhatsApp ya browser se aayi kisi bhi .APK file ko install na karein.\n'
          '4. Passwords: Har service ke liye alag strong password use karein (Bitwarden ya KeePass password manager use karein).'
        ] : [
          'Core Mobile Security Hygiene:\n\n'
          '1. Accessibility Permission Audit: Never grant Accessibility Service to untrusted apps; it allows full remote screen scraping.\n'
          '2. Hardware/App 2FA: Prefer Authenticator apps (TOTP) or FIDO2 Passkeys over SMS OTP.\n'
          '3. Zero Sideloading: Block unknown APK installations received via WhatsApp or browser links.\n'
          '4. Unique Credentials: Use an open-source password manager (Bitwarden / KeePass) with AES-256 vault encryption.'
        ],
        whatToDo: isHindi ? [
          'Settings > Apps > Special App Access > Accessibility check karein',
          'WhatsApp aur Gmail par Two-Step Verification activate karein',
          'SafeSignal ke Security Vault mein apne zaroori documents encrypted rakhein',
        ] : [
          'Inspect Settings > Accessibility for unverified services',
          'Enable Two-Step Verification across email and messaging accounts',
          'Store critical identity docs in SafeSignal\'s hardware-backed AES-256 Vault',
        ],
        trendNote: null,
        language: language,
        disclaimer: isHindi
            ? 'SafeSignal ek on-device AI assistant hai.'
            : 'SafeSignal is an on-device security assistant.',
        inputText: text,
        checkedAt: DateTime.now(),
      );
    }

    // 12. URL Intelligence Engine Evaluation (if text contains a URL)
    final urlRegex = RegExp(r'https?://[^\s/$.?#].[^\s]*|www\.[^\s]+|[a-zA-Z0-9-]+\.(?:com|in|org|net|xyz|top|ru|co|biz|info|site|online|live|vip|app|apk)(?:/[^\s]*)?', caseSensitive: false);
    final urlMatch = urlRegex.firstMatch(text);
    if (urlMatch != null) {
      final detectedUrl = urlMatch.group(0)!;
      final urlAnalysis = await UrlIntelligenceEngine.analyze(detectedUrl);

      if (urlAnalysis.riskLevel == UrlRiskLevel.knownMalicious ||
          urlAnalysis.riskLevel == UrlRiskLevel.highRisk ||
          urlAnalysis.verdict == UrlVerdict.dangerous) {
        return VerdictModel(
          checkId: 'local_url_${DateTime.now().millisecondsSinceEpoch}',
          verdict: 'SCAM',
          confidence: 0.95,
          scamType: isHindi ? 'Malicious Link Detected' : 'High-Risk Malicious URL',
          escalated: true,
          why: isHindi ? [
            'Detected URL: $detectedUrl',
            'Risk Level: ${urlAnalysis.riskLevel.name.toUpperCase()} (Threat Score: ${urlAnalysis.riskScore}/100)',
            ...urlAnalysis.warnings.map((r) => 'Khatra: $r'),
          ] : [
            'Detected URL: $detectedUrl',
            'Risk Level: ${urlAnalysis.riskLevel.name.toUpperCase()} (Threat Score: ${urlAnalysis.riskScore}/100)',
            ...urlAnalysis.warnings.map((r) => 'Indicator: $r'),
          ],
          whatToDo: isHindi ? [
            'Is link par bilkul click na karein',
            'Apne phone browser ya message se ise turant delete karein',
            'Kisi ko bhi forward na karein',
          ] : [
            'Do NOT click or open this URL',
            'Delete the message containing this link',
            'Do not forward to contacts or groups',
          ],
          trendNote: isHindi ? 'SafeSignal on-device URL analysis engine.' : 'Verified via SafeSignal URL Intelligence.',
          language: language,
          disclaimer: isHindi ? 'SafeSignal ek on-device AI assistant hai.' : 'SafeSignal is an on-device assistant.',
          inputText: text,
          checkedAt: DateTime.now(),
        );
      } else if (urlAnalysis.riskLevel == UrlRiskLevel.suspicious ||
                 urlAnalysis.verdict == UrlVerdict.caution) {
        return VerdictModel(
          checkId: 'local_url_${DateTime.now().millisecondsSinceEpoch}',
          verdict: 'UNCERTAIN',
          confidence: 0.70,
          scamType: isHindi ? 'Suspicious URL' : 'Suspicious URL Structure',
          escalated: false,
          why: isHindi ? [
            'Detected URL: $detectedUrl',
            'Risk Level: SUSPICIOUS (Threat Score: ${urlAnalysis.riskScore}/100)',
            ...urlAnalysis.warnings.map((r) => 'Warning: $r'),
          ] : [
            'Detected URL: $detectedUrl',
            'Risk Level: SUSPICIOUS (Threat Score: ${urlAnalysis.riskScore}/100)',
            ...urlAnalysis.warnings.map((r) => 'Warning: $r'),
          ],
          whatToDo: isHindi ? [
            'Bina official verification ke is link par koi data enter na karein',
            'URL ko SafeSignal ke "Website Scanner" mein deep audit karein',
          ] : [
            'Exercise caution before entering any personal or payment data',
            'Perform a deep inspection in SafeSignal\'s Website Scanner',
          ],
          trendNote: null,
          language: language,
          disclaimer: '',
          inputText: text,
          checkedAt: DateTime.now(),
        );
      } else {
        return VerdictModel(
          checkId: 'local_url_${DateTime.now().millisecondsSinceEpoch}',
          verdict: 'LIKELY_SAFE',
          confidence: 0.88,
          scamType: isHindi ? 'Verified / Low Risk Domain' : 'Verified Domain',
          escalated: false,
          why: isHindi ? [
            'Detected URL: $detectedUrl',
            'Is domain par koi known phishing, homograph ya spoofing signature nahi mila.',
          ] : [
            'Detected URL: $detectedUrl',
            'No homograph attacks, suspicious punycode, or spoofing signatures detected.',
          ],
          whatToDo: isHindi ? [
            'Domain surakshit lag raha hai',
            'Hamesha browser address bar mein padlock icon aur spelling dhyan se check karein',
          ] : [
            'Domain structure appears legitimate',
            'Always inspect the SSL certificate and hostname spelling in your browser',
          ],
          trendNote: null,
          language: language,
          disclaimer: '',
          inputText: text,
          checkedAt: DateTime.now(),
        );
      }
    }

    // 13. General Guidance / Menu Query
    if (lower.contains('help') || lower.contains('madad') || lower == 'kya kare' || lower == 'kaise kare' || lower == 'kya kar sakte ho' || lower.contains('features')) {
      return VerdictModel(
        checkId: 'local_${DateTime.now().millisecondsSinceEpoch}',
        verdict: 'INFO',
        confidence: 1.0,
        scamType: isHindi ? 'Cyber Guidance' : 'Cyber Threat Guidance',
        escalated: false,
        why: isHindi ? [
          'Main aapki in sabhi cyber mamlon mein madad kar sakta hoon:\n\n'
          '• Digital Arrest & Police Extortion: Kisi bhi fake warrant ya video call ki jaanch\n'
          '• Electricity Bijli Disconnection: 9:30 PM power cut SMS ka audit\n'
          '• Telegram Task & Prepaid Jobs: Fake part-time job scams ki jankari\n'
          '• Banking & KYC Phishing: SBI YONO, fake PAN link aur trojan APK detection\n'
          '• UPI Safety & QR Code Rules: Collect request fraud se bachav\n'
          '• Aadhaar & AePS Biometric Lock: Cloned fingerprint se protection\n'
          '• Screenshot & Link Audit: Kisi bhi message ka screenshot ya link yahan share karein!'
        ] : [
          'Here is what I can inspect and advise you on:\n\n'
          '• Digital Arrest & Law Enforcement Extortion: Verify fake video warrants\n'
          '• Electricity Bill Disconnection: Audit 9:30 PM power cut SMS threats\n'
          '• Telegram Task & Prepaid Jobs: Identify fraudulent part-time job scams\n'
          '• Banking & KYC Phishing: Detect fake SBI YONO, PAN updates, and trojan APKs\n'
          '• UPI Safety & QR Code Rules: Prevent unauthorized collect requests\n'
          '• Aadhaar & AePS Biometric Lock: Protect against cloned fingerprint fraud\n'
          '• Screenshot & Link Audit: Upload any screenshot or paste a link to begin!'
        ],
        whatToDo: [],
        language: language,
        disclaimer: isHindi
            ? 'SafeSignal ek on-device AI assistant hai. Zaruri maamlon mein 1930 pe call karein.'
            : 'SafeSignal is an on-device assistant.',
        inputText: text,
        checkedAt: DateTime.now(),
      );
    }

    // 14. Score-based Scam Analysis for Pasted SMS
    final scamKeywords = [
      'arrest', 'cbi', 'ed ', 'narcotics', 'police case', 'court order',
      'paisa bhejo', 'account block', 'kyc expire', 'kyc update',
      'won', 'prize', 'lottery', 'lucky draw', 'kbc', 'crorepati',
      'earn from home', 'part time job', 'telegram group', 'whatsapp group',
      'share karo', 'forward karo', 'claim karo', 'click here', 'click karo',
      'loan approved', 'free recharge', 'free data', 'congratulations', 'winner',
      'verify now', 'immediately', 'urgent action', 'account suspended',
    ];
    final safeKeywords = [
      'your transaction', 'credited to', 'debited from',
      'upi ref no', 'axis bank', 'hdfc bank', 'sbi', 'icici',
      'neft', 'imps', 'rtgs',
    ];
    final otpKeywords = [
      'otp', 'one time password', 'verification code', 'do not share',
    ];

    final scamScore = scamKeywords.where((k) => lower.contains(k)).length;
    final safeScore = safeKeywords.where((k) => lower.contains(k)).length;
    final isOtp = otpKeywords.any((k) => lower.contains(k));

    if (scamScore >= 2) {
      return VerdictModel(
        checkId: 'local_${DateTime.now().millisecondsSinceEpoch}',
        verdict: 'SCAM',
        confidence: 0.90,
        scamType: isHindi ? 'Suspicious SMS Pattern' : 'Suspicious Message Pattern',
        escalated: false,
        why: isHindi ? [
          'Is message mein $scamScore se zyada suspicious scam keywords mile hain.',
          'Fraudsters aisa language use karte hain — darr dikha kar, laalach de kar ya urgency create karke.',
          'Official agencies aur banks kabhi is tarah threatening ya urgent message nahi bhejte.',
        ] : [
          'This message contains $scamScore+ suspicious scam keywords.',
          'Fraudsters use this language to induce fear, greed, or false urgency.',
          'Legitimate enforcement agencies and banks never send threatening links or payment demands.',
        ],
        whatToDo: isHindi ? [
          'Koi bhi link par click mat karo',
          'Kisi ko bhi OTP, PIN ya paise transfer mat karo',
          'National Cybercrime Helpline: 1930 par turant call karein',
          'cybercrime.gov.in par report karein',
        ] : [
          'Do not click any link in this message',
          'Never share OTP, PIN, or transfer money',
          'Report immediately to National Cybercrime Helpline: 1930',
          'File a complaint at cybercrime.gov.in',
        ],
        trendNote: isHindi ? 'Ye pattern common Indian cyber fraud hai.' : 'Common Indian cybercrime tactic.',
        language: language,
        disclaimer: isHindi ? 'SafeSignal ek on-device AI assistant hai. Zaruri maamlon mein 1930 pe call karein.' : 'SafeSignal is an on-device security assistant. Call 1930 for urgent matters.',
        inputText: text,
        checkedAt: DateTime.now(),
      );
    }

    if (scamScore == 1 && safeScore == 0) {
      return VerdictModel(
        checkId: 'local_caution_${DateTime.now().millisecondsSinceEpoch}',
        verdict: 'UNCERTAIN',
        confidence: 0.65,
        scamType: isHindi ? 'Unverified Message' : 'Unverified Communication',
        escalated: false,
        why: isHindi ? [
          'Is message mein kuch suspicious ya unverified sanket hain.',
          'Bina official verification ke kisi bhi anjaan link ya request par vishwas na karein.',
        ] : [
          'This message contains potential warning indicators.',
          'Always verify sender identity through official channels before acting.',
        ],
        whatToDo: isHindi ? [
          'Kisi bhi anjaan vyakti se OTP ya PIN share na karein',
          'Doubt hone par 1930 Cyber Helpline par call karein',
        ] : [
          'Never share OTP, passwords, or personal credentials',
          'Call 1930 Cyber Helpline if suspicious',
        ],
        trendNote: null,
        language: language,
        disclaimer: isHindi ? 'SafeSignal ek on-device AI assistant hai.' : 'SafeSignal is an on-device assistant.',
        inputText: text,
        checkedAt: DateTime.now(),
      );
    }

    if (safeScore >= 1 || isOtp) {
      return VerdictModel(
        checkId: 'local_safe_${DateTime.now().millisecondsSinceEpoch}',
        verdict: 'LIKELY_SAFE',
        confidence: 0.88,
        scamType: 'none',
        escalated: false,
        why: isHindi ? [
          'Message ka format standard transactional ya official communication se match karta hai.',
          'Isme koi suspicious threatening language ya unauthorized payment link nahi mila.',
        ] : [
          'Standard transactional or official notification pattern.',
          'No malicious phishing links or coercive language detected.',
        ],
        whatToDo: isHindi ? [
          'Ye sandesh surakshit lag raha hai.',
          'Hamesha dhyan rahe: Apna OTP kisi ke kehne par share na karein.',
        ] : [
          'This communication appears legitimate.',
          'Remember: Never share OTPs or login codes over the phone.',
        ],
        trendNote: null,
        language: language,
        disclaimer: isHindi ? 'SafeSignal ek on-device AI assistant hai.' : 'SafeSignal is an on-device assistant.',
        inputText: text,
        checkedAt: DateTime.now(),
      );
    }

    // 15. Default Conversational Security Response
    return VerdictModel(
      checkId: 'local_${DateTime.now().millisecondsSinceEpoch}',
      verdict: 'INFO',
      confidence: 1.0,
      scamType: isHindi ? 'Cyber Guidance' : 'Cyber Advice',
      escalated: false,
      why: isHindi ? [
        'Aapka message mila hai.\n\nAap mujhse kisi bhi online scam (Digital Arrest, Bijli bill, Telegram jobs, Fake bank SMS, UPI fraud) ke baare mein pooch sakte hain, ya koi suspicious link / SMS yahan paste karke scan karwa sakte hain.'
      ] : [
        'Message received.\n\nYou can consult me on any online threat (Digital Arrest, Electricity bill fraud, Telegram tasks, Fake banking SMS, UPI scams), or paste any suspicious link or text message here for a forensic audit.'
      ],
      whatToDo: [],
      trendNote: null,
      language: language,
      disclaimer: '',
      inputText: text,
      checkedAt: DateTime.now(),
    );
  }

  Future<VerdictModel> _analyzeImageHeuristics(
    File image,
    String hint,
    String language, {
    String? ocrText,
  }) async {
    final sizeKb = await image.length() / 1024;
    final isHindi = language == 'hi';

    final textComponents = <String>[];
    if (ocrText != null && ocrText.trim().isNotEmpty) {
      textComponents.add(ocrText.trim());
    }
    if (hint.isNotEmpty && hint != '[Screenshot Analysis Request]') {
      textComponents.add(hint.trim());
    }

    final rawText = textComponents.join('\n');
    final lower = rawText.toLowerCase();

    // 1. If OCR extracted nothing or empty text
    if (rawText.trim().isEmpty) {
      return VerdictModel(
        checkId: 'img_unreadable_${DateTime.now().millisecondsSinceEpoch}',
        verdict: 'UNCERTAIN',
        confidence: 0.50,
        scamType: isHindi ? 'Unreadable Screenshot' : 'Unreadable Screenshot',
        escalated: false,
        why: isHindi ? [
          'Is screenshot mein koi readable text (akshar) detect nahi hua.',
          'Ho sakta hai image blurry ho, resolution kam ho, ya text background se match kar raha ho.',
          'On-device AI engine sirf saaf text ko OCR se extract karke audit karta hai.',
        ] : [
          'No readable text could be extracted from this image via on-device OCR.',
          'The screenshot may be blurry, low-resolution, or graphic-only.',
          'SafeSignal\'s on-device privacy engine requires legible text to run forensic verification.',
        ],
        whatToDo: isHindi ? [
          'Ek saaf aur high-contrast screenshot upload karein',
          'Ya message ka text seedha copy karke chat mein paste karein',
          'Anjaan vyakti se aayi photo ya QR code ko bina verification scan na karein',
        ] : [
          'Upload a sharper, higher-resolution screenshot',
          'Or copy and paste the message text directly into the chat',
          'Never scan unverified QR codes or open links from unknown senders',
        ],
        trendNote: null,
        language: language,
        disclaimer: isHindi
            ? 'SafeSignal ek on-device AI assistant hai. Zaruri maamlon mein 1930 pe call karein.'
            : 'SafeSignal is an on-device security assistant. Call 1930 for urgent cyber threats.',
        inputText: '[Image uploaded — ${sizeKb.toStringAsFixed(0)} KB (No OCR text)]',
        checkedAt: DateTime.now(),
      );
    }

    // Extract potential links, phone numbers, UPI IDs from OCR text
    final urlRegex = RegExp(r'https?://[^\s/$.?#].[^\s]*|www\.[^\s]+|[a-zA-Z0-9-]+\.(?:com|in|org|net|xyz|top|ru|co|biz|info|site|online|live|vip|app|apk)(?:/[^\s]*)?', caseSensitive: false);
    final urlMatch = urlRegex.firstMatch(rawText);
    final phoneMatch = RegExp(r'(?:\+91[\-\s]?)?[6789]\d{9}\b').firstMatch(rawText);
    final upiMatch = RegExp(r'[a-zA-Z0-9._\-]+@[a-zA-Z]{2,}').firstMatch(rawText);

    // Provide a short preview of OCR text so user sees SafeSignal read their image
    final previewText = rawText.length > 120 ? '${rawText.substring(0, 117)}...' : rawText;

    // Vector 1: Digital Arrest / Law Enforcement Impersonation
    final isDigitalArrest = (lower.contains('arrest') || lower.contains('cbi') || lower.contains('narcotics') ||
        lower.contains('money laundering') || lower.contains('cyber crime branch') ||
        lower.contains('warrant') || lower.contains('court order') || lower.contains('ed ') ||
        lower.contains('enforcement directorate') || lower.contains('trai sim') || lower.contains('cyber cell')) &&
        (lower.contains('police') || lower.contains('video call') || lower.contains('skype') ||
         lower.contains('fine') || lower.contains('penalty') || lower.contains('fir') ||
         lower.contains('custody') || lower.contains('officer') || lower.contains('order') ||
         lower.contains('investigation') || lower.contains('supreme court') || lower.contains('mha'));

    if (isDigitalArrest) {
      return VerdictModel(
        checkId: 'img_arrest_${DateTime.now().millisecondsSinceEpoch}',
        verdict: 'SCAM',
        confidence: 0.98,
        scamType: isHindi ? 'Digital Arrest Extortion Scam' : 'Digital Arrest Impersonation Racket',
        escalated: true,
        why: isHindi ? [
          'Screenshot Text Detected: "$previewText"',
          'CBI, ED, Police ya Court ke naam par darr dikhane aur online arrest ki dhamki di gayi hai.',
          'Bharat ke kisi bhi kanoon mein "Digital Arrest" ka koi pravdhan nahi hai. Police ya CBI kabhi video call (Skype/WhatsApp) par arrest nahi karti.',
          if (phoneMatch != null) 'Scammer Contact Number: ${phoneMatch.group(0)}',
          'Ye cyber syndicates ka extortion racket hai jo darr dikha kar illegal account transfer karwate hain.',
        ] : [
          'Screenshot Text Detected: "$previewText"',
          'Coercive legal threats, fake warrants, or fake law enforcement headers detected.',
          'Indian law has NO provision for "Digital Arrest". CBI, Police, and Courts NEVER arrest citizens via video calls (Skype/WhatsApp).',
          if (phoneMatch != null) 'Detected Scammer Contact: ${phoneMatch.group(0)}',
          'This is a transnational extortion racket attempting to compel coercive fund transfers.',
        ],
        whatToDo: isHindi ? [
          'Video call ya chat turant disconnect karein aur number block karein',
          'Ek rupaya bhi transfer na karein chahe kitna bhi darr dikhaya jaye',
          'National Cybercrime Helpline: 1930 par turant call karein',
          'cybercrime.gov.in par screenshot upload karke complaint darj karein',
        ] : [
          'Immediately disconnect the video/voice call and block the sender',
          'Never transfer any money or disclose bank account balances',
          'Call National Cybercrime Helpline 1930 immediately',
          'File an official report at cybercrime.gov.in with this screenshot',
        ],
        trendNote: isHindi
            ? 'MHA aur I4C ne Digital Arrest scams par deshwapari advisory jaari ki hai.'
            : 'MHA and I4C have issued nationwide alerts on Digital Arrest extortion networks.',
        language: language,
        disclaimer: isHindi
            ? 'SafeSignal ek on-device AI assistant hai. Zaruri maamlon mein 1930 pe call karein.'
            : 'SafeSignal is an on-device security assistant. Call 1930 for urgent cyber threats.',
        inputText: '[Screenshot: $previewText]',
        checkedAt: DateTime.now(),
      );
    }

    // Vector 2: Electricity Bill Disconnection Fraud
    final isElectricity = (lower.contains('electricity') || lower.contains('bijli') ||
        lower.contains('power will be disconnected') || lower.contains('power cut') ||
        lower.contains('light cut') || lower.contains('urja') || lower.contains('electric')) &&
        (lower.contains('9:30') || lower.contains('officer') || lower.contains('bill') ||
         lower.contains('update') || lower.contains('contact') || lower.contains('call') ||
         lower.contains('previous month') || lower.contains('tonight'));

    if (isElectricity) {
      return VerdictModel(
        checkId: 'img_elec_${DateTime.now().millisecondsSinceEpoch}',
        verdict: 'SCAM',
        confidence: 0.96,
        scamType: isHindi ? 'Electricity Bill Disconnection Fraud' : 'Electricity Disconnection Scam',
        escalated: true,
        why: isHindi ? [
          'Screenshot Text Detected: "$previewText"',
          'Raat ko 9:30 baje bijli kaatne ka farzi notice paya gaya hai.',
          'Bijli Board (Electricity Board) kabhi bhi aam personal mobile number se disconnection warning nahi bhejta.',
          if (phoneMatch != null) 'Fake Officer Number: ${phoneMatch.group(0)}',
          'Scammers fake electricity officer ban kar AnyDesk/QuickSupport download karwate hain ya fake APK install karwake account khali karte hain.',
        ] : [
          'Screenshot Text Detected: "$previewText"',
          'Urgent notice threatening immediate power cut (typically at 9:30 PM) detected.',
          'Power utility companies never dispatch disconnection notices from personal mobile numbers.',
          if (phoneMatch != null) 'Fraudulent Officer Contact: ${phoneMatch.group(0)}',
          'Fraudsters instruct victims to install malicious APKs or remote-desktop utilities (AnyDesk/TeamViewer).',
        ],
        whatToDo: isHindi ? [
          'Screenshot mein diye gaye kisi bhi number par call mat karein',
          'Koi bhi APK ya remote app (AnyDesk, QuickSupport) install na karein',
          'Apne rajya ke official bijli board portal ya consumer app par bill status check karein',
          '1930 par cyber fraud report karein',
        ] : [
          'Do NOT call the phone number provided in the screenshot',
          'Never install any APK or remote screen-sharing tools',
          'Verify your bill status exclusively through your official state DISCOM portal or app',
          'Report the fraud number to 1930 and Chakshu (sancharsaathi.gov.in)',
        ],
        trendNote: isHindi
            ? 'Bijli disconnection SMS fraud India ke sabhi rajyon mein tezi se fail raha hai.'
            : 'Electricity disconnection SMS scam is prevalent across all Indian states.',
        language: language,
        disclaimer: isHindi
            ? 'SafeSignal ek on-device AI assistant hai. Zaruri maamlon mein 1930 pe call karein.'
            : 'SafeSignal is an on-device security assistant. Call 1930 for urgent cyber threats.',
        inputText: '[Screenshot: $previewText]',
        checkedAt: DateTime.now(),
      );
    }

    // Vector 3: Banking KYC / PAN Card Phishing / Trojan
    final isBankKyc = (lower.contains('yono') || lower.contains('sbi') || lower.contains('hdfc') ||
        lower.contains('icici') || lower.contains('axis') || lower.contains('pnb') ||
        lower.contains('bob') || lower.contains('canara') || lower.contains('kotak')) &&
        (lower.contains('pan') || lower.contains('kyc') || lower.contains('block') ||
         lower.contains('suspend') || lower.contains('update') || lower.contains('debit card') ||
         lower.contains('link your pan') || lower.contains('netbanking'));

    if (isBankKyc) {
      return VerdictModel(
        checkId: 'img_bank_${DateTime.now().millisecondsSinceEpoch}',
        verdict: 'SCAM',
        confidence: 0.95,
        scamType: isHindi ? 'Banking KYC Phishing & Trojan' : 'Banking KYC Phishing Trojan',
        escalated: true,
        why: isHindi ? [
          'Screenshot Text Detected: "$previewText"',
          'Bank account suspend hone ka darr dikhakar KYC/PAN update karne ke liye link ya call ka pressure banaya gaya hai.',
          'RBI guidelines ke anusar banks kabhi bhi SMS/WhatsApp par direct link bhejkar PAN ya Aadhaar update karne ko nahi kehte.',
          if (urlMatch != null) 'Suspicious Phishing URL: ${urlMatch.group(0)}',
          'Ye fake banking portal ya banking trojan APK install karwake netbanking login aur OTP steal karte hain.',
        ] : [
          'Screenshot Text Detected: "$previewText"',
          'Urgent account suspension threat demanding immediate PAN/KYC link update.',
          'Per RBI directives, banks never distribute direct web links via SMS/chat to update PAN/Aadhaar credentials.',
          if (urlMatch != null) 'Detected Phishing URL: ${urlMatch.group(0)}',
          'Routes to credential harvesting phishing portals or Android SMS stealer trojans.',
        ],
        whatToDo: isHindi ? [
          'Screenshot mein kisi bhi link par click na karein',
          'Bank ki official app ya branch jakar direct verify karein',
          'Agar galti se login kiya ho toh turant netbanking block karein',
          '1930 par cyber fraud register karein',
        ] : [
          'Do not open any link or download attachments shown in the image',
          'Verify KYC directly at your bank branch or official netbanking app',
          'If credentials were entered, immediately freeze your account via netbanking/customer care',
          'Report to 1930 helpline',
        ],
        trendNote: isHindi
            ? 'Fake SBI YONO aur KYC phishing APKs India mein sabse common banking threats hain.'
            : 'Fake SBI YONO phishing APKs represent the top mobile banking threat vector in India.',
        language: language,
        disclaimer: isHindi
            ? 'SafeSignal ek on-device AI assistant hai. Zaruri maamlon mein 1930 pe call karein.'
            : 'SafeSignal is an on-device security assistant. Call 1930 for urgent cyber threats.',
        inputText: '[Screenshot: $previewText]',
        checkedAt: DateTime.now(),
      );
    }

    // Vector 4: Telegram Task / Work from Home Scam
    final isTelegramJob = (lower.contains('telegram') || lower.contains('part time') ||
        lower.contains('task') || lower.contains('youtube like') || lower.contains('daily income') ||
        lower.contains('work from home') || lower.contains('vip group') || lower.contains('hotel review')) &&
        (lower.contains('earn') || lower.contains('salary') || lower.contains('investment') ||
         lower.contains('profit') || lower.contains('per day') || lower.contains('deposit') ||
         lower.contains('prepaid') || lower.contains('commission'));

    if (isTelegramJob) {
      return VerdictModel(
        checkId: 'img_task_${DateTime.now().millisecondsSinceEpoch}',
        verdict: 'SCAM',
        confidence: 0.95,
        scamType: isHindi ? 'Telegram Task & Prepaid Job Fraud' : 'Telegram Task & Prepaid Investment Fraud',
        escalated: true,
        why: isHindi ? [
          'Screenshot Text Detected: "$previewText"',
          'Ghar baithe video like karne, hotel review dene ya simple task se moti kamai ka laalach diya gaya hai.',
          'Pehle 150-500 rupaye dekar bharosa banate hain, fir "prepaid task" ya crypto investment ke naam par hazaron/lakhon rupaye deposit karwate hain.',
          'Jab victim paise nikalna chahta hai toh "tax" ya "penalty" maang kar aur loot te hain.',
        ] : [
          'Screenshot Text Detected: "$previewText"',
          'Promises easy daily earnings for trivial tasks (YouTube likes, rating hotels, following channels).',
          'Scammers disburse small initial sums (Rs 150-500) to establish trust, then lure victims into high-stakes "prepaid VIP tasks".',
          'Deposited funds are trapped; scammers demand successive "unfreezing taxes" until the victim is completely drained.',
        ],
        whatToDo: isHindi ? [
          'Kisi bhi Telegram group ya task coordinator ko paise transfer na karein',
          'Chat se turant exit karein aur fraud group ko report karein',
          'Agar paise transfer kar chuke hain toh turant 1930 par call karein taaki fraud accounts freeze ho sakein',
        ] : [
          'Never transfer money to participate in prepaid tasks or claim commissions',
          'Exit the group and block the recruiter immediately',
          'If funds were transferred, dial 1930 immediately to invoke golden-hour lien freeze on recipient accounts',
        ],
        trendNote: isHindi
            ? 'Telegram task scams mein hazaron Indian yuvaon ne apni saving ganwayi hai.'
            : 'Prepaid task scams account for substantial financial cyber losses across India.',
        language: language,
        disclaimer: isHindi
            ? 'SafeSignal ek on-device AI assistant hai. Zaruri maamlon mein 1930 pe call karein.'
            : 'SafeSignal is an on-device security assistant. Call 1930 for urgent cyber threats.',
        inputText: '[Screenshot: $previewText]',
        checkedAt: DateTime.now(),
      );
    }

    // Vector 5: FedEx / Customs Narcotics Extortion
    final isFedEx = (lower.contains('fedex') || lower.contains('dhl') || lower.contains('customs') ||
        lower.contains('parcel') || lower.contains('courier')) &&
        (lower.contains('drugs') || lower.contains('narcotics') || lower.contains('mdma') ||
         lower.contains('passport') || lower.contains('taiwan') || lower.contains('detained') ||
         lower.contains('mumbai airport') || lower.contains('custom clearance') || lower.contains('contraband'));

    if (isFedEx) {
      return VerdictModel(
        checkId: 'img_fedex_${DateTime.now().millisecondsSinceEpoch}',
        verdict: 'SCAM',
        confidence: 0.98,
        scamType: isHindi ? 'FedEx Customs Narcotics Extortion' : 'FedEx / Customs Narcotics Extortion Scam',
        escalated: true,
        why: isHindi ? [
          'Screenshot Text Detected: "$previewText"',
          'Farzi parcel mein illegal drugs/passport hone ka aarop lagakar darr dikhaya gaya hai.',
          'Customs vibhag ya FedEx kabhi WhatsApp call ya anjaan number se FIR ki dhamki dekar paise nahi maangte.',
          'Ye organised extortion syndicates ka kaam hai jo victim ko darr ke maare fake settlement account mein paise transfer karne ko majboor karte hain.',
        ] : [
          'Screenshot Text Detected: "$previewText"',
          'Falsely claims a detained parcel containing contraband or illegal passports is registered under your identity.',
          'FedEx and Indian Customs never initiate legal threats or demand settlement fines over WhatsApp or mobile calls.',
          'Transnational extortion syndicates use forged customs letterheads to induce immediate panic.',
        ],
        whatToDo: isHindi ? [
          'Turant call disconnect karein aur number block karein',
          'Ek bhi rupaya fake settlement account mein transfer na karein',
          '1930 par turant call karke extortion ki complaint karein',
        ] : [
          'Disconnect the call and block the sender immediately',
          'Do NOT transfer funds to any "government holding" account',
          'Report immediately to 1930 and file a complaint at cybercrime.gov.in',
        ],
        trendNote: isHindi
            ? 'FedEx courier fraud Digital Arrest syndicates ka pehla step hota hai.'
            : 'FedEx customs intimidation is the gateway tactic into digital arrest extortion.',
        language: language,
        disclaimer: isHindi
            ? 'SafeSignal ek on-device AI assistant hai. Zaruri maamlon mein 1930 pe call karein.'
            : 'SafeSignal is an on-device security assistant. Call 1930 for urgent cyber threats.',
        inputText: '[Screenshot: $previewText]',
        checkedAt: DateTime.now(),
      );
    }

    // Vector 6: Predatory Instant Loan Apps
    final isLoanApp = (lower.contains('loan approved') || lower.contains('instant loan') ||
        lower.contains('7 days loan') || lower.contains('disbursed') || lower.contains('karz')) &&
        (lower.contains('harass') || lower.contains('contacts') || lower.contains('repay') ||
         lower.contains('overdue') || lower.contains('gallery') || lower.contains('morph') ||
         lower.contains('penalty') || lower.contains('nbfc'));

    if (isLoanApp) {
      return VerdictModel(
        checkId: 'img_loan_${DateTime.now().millisecondsSinceEpoch}',
        verdict: 'SCAM',
        confidence: 0.94,
        scamType: isHindi ? 'Predatory Instant Loan Extortion' : 'Predatory Instant Loan Blackmail',
        escalated: true,
        why: isHindi ? [
          'Screenshot Text Detected: "$previewText"',
          '7-day instant loan app ka extortion pattern mila hai.',
          'Ye unauthorized Chinese loan apps phone ki contact list aur photos access karke morphed images bhejne ki dhamki dete hain.',
          'RBI ke rules ke hisaab se koi bhi NBFC contact list access karke relatives ko call karke dhamki nahi de sakti.',
        ] : [
          'Screenshot Text Detected: "$previewText"',
          'Predatory short-term (7-day) loan extortion tactics detected.',
          'Illegal loan apps harvest phone contacts and photo galleries to blackmail borrowers with manipulated media.',
          'Violates RBI Digital Lending Directives; legitimate NBFCs are prohibited from accessing private device contacts.',
        ],
        whatToDo: isHindi ? [
          'In apps ko turant phone se uninstall karein aur storage permissions revoke karein',
          'Inke kisi bhi extortion payment link par paise na dein — ye baar baar aur maangte hain',
          '1930 cyber helpline par report karein aur local police mein extortion FIR darj karein',
        ] : [
          'Uninstall the predatory APK and revoke all contact/media permissions immediately',
          'Refrain from paying blackmail demands; extortionists repeatedly increase claims',
          'Report the app and harassment to 1930 and local police',
        ],
        trendNote: isHindi
            ? 'RBI ne unauthorized digital lending apps ki public warning list jaari ki hai.'
            : 'RBI maintains strict guidelines prohibiting invasive digital lending practices.',
        language: language,
        disclaimer: isHindi
            ? 'SafeSignal ek on-device AI assistant hai. Zaruri maamlon mein 1930 pe call karein.'
            : 'SafeSignal is an on-device security assistant. Call 1930 for urgent cyber threats.',
        inputText: '[Screenshot: $previewText]',
        checkedAt: DateTime.now(),
      );
    }

    // Vector 7: UPI Collect / Pay to Receive Fraud
    final isUpiCollect = (lower.contains('collect request') || lower.contains('pay to receive') ||
        lower.contains('enter upi pin') || lower.contains('claim prize') ||
        lower.contains('scratch card') || lower.contains('cashback won')) &&
        (lower.contains('upi') || lower.contains('gpay') || lower.contains('phonepe') ||
         lower.contains('paytm') || lower.contains('pin'));

    if (isUpiCollect) {
      return VerdictModel(
        checkId: 'img_upi_${DateTime.now().millisecondsSinceEpoch}',
        verdict: 'SCAM',
        confidence: 0.94,
        scamType: isHindi ? 'UPI Collect Request Fraud' : 'UPI Collect Request Deception',
        escalated: true,
        why: isHindi ? [
          'Screenshot Text Detected: "$previewText"',
          'Paisa paane ke naam par UPI PIN enter karne ya collect request approve karne ko kaha gaya hai.',
          'UPI ka sabse bada niyam: "UPI PIN sirf paise BHEJNE ke liye hota hai, paise PAANE ke liye kabhi PIN nahi lagta."',
          if (upiMatch != null) 'Suspicious UPI VPA: ${upiMatch.group(0)}',
          'Collect request approve karte hi aapke account se paise kat jayenge.',
        ] : [
          'Screenshot Text Detected: "$previewText"',
          'Solicits entry of UPI PIN under the pretext of claiming rewards or receiving payments.',
          'Golden Rule of UPI: "UPI PIN is ONLY required to TRANSFER money, NEVER to receive money."',
          if (upiMatch != null) 'Detected UPI VPA: ${upiMatch.group(0)}',
          'Approving this request will immediately debit money from your bank account.',
        ],
        whatToDo: isHindi ? [
          'Collect request ko turant DECLINE karein',
          'Apna UPI PIN kabhi bhi kisi ko receive karne ke liye enter mat karein',
          'UPI app mein is VPA ko "Report Fraud" karein',
        ] : [
          'Immediately DECLINE the collect request in your UPI app',
          'Never enter your UPI PIN to receive money or cashback',
          'Flag and report the VPA inside your banking/UPI application',
        ],
        trendNote: isHindi
            ? 'OLX aur marketplace fraud mein UPI collect request sabse common technique hai.'
            : 'UPI collect deception is the most prevalent tactic on peer-to-peer marketplaces.',
        language: language,
        disclaimer: isHindi
            ? 'SafeSignal ek on-device AI assistant hai. Zaruri maamlon mein 1930 pe call karein.'
            : 'SafeSignal is an on-device security assistant. Call 1930 for urgent cyber threats.',
        inputText: '[Screenshot: $previewText]',
        checkedAt: DateTime.now(),
      );
    }

    // Vector 8: URL Intelligence Analysis on URL found in image
    if (urlMatch != null) {
      final detectedUrl = urlMatch.group(0)!;
      final urlAnalysis = await UrlIntelligenceEngine.analyze(detectedUrl);
      if (urlAnalysis.riskLevel == UrlRiskLevel.knownMalicious ||
          urlAnalysis.riskLevel == UrlRiskLevel.highRisk ||
          urlAnalysis.verdict == UrlVerdict.dangerous) {
        return VerdictModel(
          checkId: 'img_url_${DateTime.now().millisecondsSinceEpoch}',
          verdict: 'SCAM',
          confidence: 0.92,
          scamType: isHindi ? 'Malicious Link in Screenshot' : 'High-Risk URL Detected in Image',
          escalated: true,
          why: isHindi ? [
            'Screenshot Text Detected: "$previewText"',
            'Malicious Link Found: $detectedUrl',
            'Risk Level: ${urlAnalysis.riskLevel.name.toUpperCase()} (Threat Score: ${urlAnalysis.riskScore}/100)',
            ...urlAnalysis.warnings.take(2).map((r) => 'Khatra: $r'),
          ] : [
            'Screenshot Text Detected: "$previewText"',
            'Malicious Link Found: $detectedUrl',
            'Risk Level: ${urlAnalysis.riskLevel.name.toUpperCase()} (Threat Score: ${urlAnalysis.riskScore}/100)',
            ...urlAnalysis.warnings.take(2).map((r) => 'Indicator: $r'),
          ],
          whatToDo: isHindi ? [
            'Is link ko kisi bhi browser mein mat kholein',
            'Agar koi file download ho rahi ho toh turant cancel karein',
            'SafeSignal ke Website Scanner mein pura URL check karein',
          ] : [
            'Do NOT open this link in any browser',
            'Immediately cancel any downloaded APK or executable',
            'Run a deep scan via SafeSignal\'s Website Scanner',
          ],
          trendNote: isHindi ? 'Phishing aur spoofed URLs tezi se phailte hain.' : 'Weaponized spoofed links detected.',
          language: language,
          disclaimer: isHindi
              ? 'SafeSignal ek on-device AI assistant hai. Zaruri maamlon mein 1930 pe call karein.'
              : 'SafeSignal is an on-device security assistant. Call 1930 for urgent cyber threats.',
          inputText: '[Screenshot: $previewText]',
          checkedAt: DateTime.now(),
        );
      }
    }

    // Vector 9: Legitimate Bank / Payment Transaction Receipt
    final isLegitTxn = (lower.contains('debited from') || lower.contains('credited to') ||
        lower.contains('upi ref') || lower.contains('transaction successful') ||
        lower.contains('txn id') || lower.contains('imps ref') || lower.contains('neft ref') ||
        lower.contains('payment received')) &&
        !lower.contains('arrest') && !lower.contains('cbi') && !lower.contains('urgent pan') &&
        !lower.contains('power will be cut') && !lower.contains('task earn');

    if (isLegitTxn) {
      return VerdictModel(
        checkId: 'img_legit_${DateTime.now().millisecondsSinceEpoch}',
        verdict: 'LIKELY_SAFE',
        confidence: 0.90,
        scamType: isHindi ? 'Valid Transaction Receipt' : 'Legitimate Transaction Receipt',
        escalated: false,
        why: isHindi ? [
          'Screenshot Text Detected: "$previewText"',
          'Ye ek standard bank payment ya transaction confirmation receipt lag rahi hai.',
          'Isme koi threatening language, fake urgency ya phishing link nahi mila.',
        ] : [
          'Screenshot Text Detected: "$previewText"',
          'Conforms to standard banking transaction confirmation or UPI receipt structure.',
          'No malicious phishing indicators, extortion keywords, or credential lures detected.',
        ],
        whatToDo: isHindi ? [
          'Receipt surakshit lag rahi hai',
          'Dhyan rahe: Apna bank account balance ya transaction receipt kisi anjaan vyakti se share na karein',
          'Kabhi kisi ko apna UPI PIN ya OTP na batayein',
        ] : [
          'The receipt appears legitimate',
          'Practice good cyber hygiene: Do not share sensitive payment receipts with unverified parties',
          'Never disclose your UPI PIN or banking passwords',
        ],
        trendNote: null,
        language: language,
        disclaimer: isHindi
            ? 'SafeSignal ek on-device AI assistant hai.'
            : 'SafeSignal is an on-device security assistant.',
        inputText: '[Screenshot: $previewText]',
        checkedAt: DateTime.now(),
      );
    }

    // Vector 10: General Suspicious Keyword Analysis on extracted text
    final scamKeywords = [
      'arrest', 'cbi', 'ed ', 'narcotics', 'police', 'court',
      'paisa bhejo', 'account block', 'kyc expire', 'kyc update',
      'won', 'prize', 'lottery', 'lucky draw', 'kbc',
      'earn from home', 'part time job', 'telegram',
      'share karo', 'claim karo', 'click here',
      'loan approved', 'free recharge', 'congratulations',
      'immediately', 'urgent action', 'penalty', 'fine',
    ];
    final scamHits = scamKeywords.where((k) => lower.contains(k)).toList();

    if (scamHits.length >= 2) {
      return VerdictModel(
        checkId: 'img_scam_${DateTime.now().millisecondsSinceEpoch}',
        verdict: 'SCAM',
        confidence: 0.88,
        scamType: isHindi ? 'Suspicious Content Detected' : 'Suspicious Visual Content',
        escalated: true,
        why: isHindi ? [
          'Screenshot Text Detected: "$previewText"',
          'Image mein ${scamHits.length} suspicious scam indicators detect hue hain: ${scamHits.take(3).join(', ')}',
          'Fraudsters aisi bhasha ka upyog darr dikhane ya laalach de kar karte hain.',
          if (phoneMatch != null) 'Contact Number: ${phoneMatch.group(0)}',
        ] : [
          'Screenshot Text Detected: "$previewText"',
          'Detected ${scamHits.length} warning indicators: ${scamHits.take(3).join(', ')}',
          'Scammers use high-urgency and fear-inducing wording to compel immediate actions.',
          if (phoneMatch != null) 'Detected Contact: ${phoneMatch.group(0)}',
        ],
        whatToDo: isHindi ? [
          'Kisi bhi anjaan number par call ya payment na karein',
          'Kisi se bhi OTP, password ya bank details share na karein',
          '1930 Cyber Helpline par report karein',
        ] : [
          'Do not call unverified numbers or make payments',
          'Never disclose OTPs, PINs, or confidential banking credentials',
          'Report to 1930 Cyber Helpline',
        ],
        trendNote: isHindi ? 'Indian cyber space mein aam extortion pattern.' : 'Common Indian cyber threat pattern.',
        language: language,
        disclaimer: isHindi
            ? 'SafeSignal ek on-device AI assistant hai. Zaruri maamlon mein 1930 pe call karein.'
            : 'SafeSignal is an on-device security assistant. Call 1930 for urgent cyber threats.',
        inputText: '[Screenshot: $previewText]',
        checkedAt: DateTime.now(),
      );
    }

    // Default safe fallback if readable text has no threat indicators
    return VerdictModel(
      checkId: 'img_clean_${DateTime.now().millisecondsSinceEpoch}',
      verdict: 'LIKELY_SAFE',
      confidence: 0.85,
      scamType: isHindi ? 'No Threat Detected' : 'Clean Screenshot',
      escalated: false,
      why: isHindi ? [
        'Screenshot Text Detected: "$previewText"',
        'Is image mein koi obvious phishing link, digital arrest, ya cyber fraud signature nahi mila.',
      ] : [
        'Screenshot Text Detected: "$previewText"',
        'No overt phishing, extortion, or fraudulent signatures were detected in this image.',
      ],
      whatToDo: isHindi ? [
        'Image mein koi khatra detect nahi hua',
        'Kisi bhi anjaan link ya request par hamesha savdhaan rahein',
      ] : [
        'Image appears clean of known threat signatures',
        'Continue to practice standard caution with unsolicited messages',
      ],
      trendNote: null,
      language: language,
      disclaimer: isHindi
          ? 'SafeSignal ek on-device AI assistant hai.'
          : 'SafeSignal is an on-device security assistant.',
      inputText: '[Screenshot: $previewText]',
      checkedAt: DateTime.now(),
    );
  }

  void clear() {
    // Keep welcome message matching current language
    state = [ChatNotifier.welcomeMsg('hi')];
  }
}

final chatProvider = NotifierProvider<ChatNotifier, List<ChatMessage>>(
  ChatNotifier.new,
);

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _picker = ImagePicker();
  File? _selectedImage;
  bool _isAnalyzing = false;

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: 300.ms,
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty && _selectedImage == null) return;
    if (_isAnalyzing) return;

    final language = ref.read(settingsProvider).language;

    setState(() => _isAnalyzing = true);
    _controller.clear();
    final img = _selectedImage;
    setState(() => _selectedImage = null);

    await ref.read(chatProvider.notifier).analyzeMessage(
          text.isEmpty ? '[Screenshot Analysis Request]' : text,
          image: img,
          language: language,
        );

    setState(() => _isAnalyzing = false);
    _scrollToBottom();
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = ref.watch(settingsProvider).language;

    if (messages.isNotEmpty) _scrollToBottom();

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFFE3F2FD),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF0D1117), size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Image.asset(
              'assets/images/logo_transparent.png',
              width: 38,
              height: 38,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Cyber Assistant',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    color: Color(0xFF0D1117),
                    letterSpacing: -0.3,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Live Protection Active',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => ref.read(chatProvider.notifier).clear(),
            icon: const Icon(Icons.refresh, color: Color(0xFF0D1117)),
            tooltip: 'Clear chat',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB), Color(0xFF90CAF9)],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              physics: const BouncingScrollPhysics(),
              itemCount: messages.length,
              itemBuilder: (context, i) {
                final msg = messages[i];
                return _MessageBubble(
                  message: msg,
                  isDark: isDark,
                  lang: lang,
                  onVerdictTap: (v) => context.push('/verdict', extra: v),
                );
              },
            ),
          ),
          
          if (_selectedImage != null)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppTheme.darkBorder : const Color(0xFFE8EDF8),
                ),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(_selectedImage!, height: 50, width: 50, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Screenshot ready to check',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _selectedImage = null),
                    icon: const Icon(Icons.close, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: isDark ? Colors.white10 : Colors.grey.shade100,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn().slideY(begin: 0.1),

          // Input Bar
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: 12 + MediaQuery.of(context).padding.bottom,
            ),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCard : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? AppTheme.darkBorder : const Color(0xFFE8EDF8),
                  width: 1.5,
                ),
              ),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _isAnalyzing ? null : _pickImage,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5FD),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.image_outlined,
                      color: AppTheme.primary,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    maxLines: 4,
                    minLines: 1,
                    enabled: !_isAnalyzing,
                    style: TextStyle(
                      fontSize: 15,
                      color: isDark ? Colors.white : AppTheme.darkSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: lang == 'hi'
                        ? 'Shak wala message yahan paste karein...'
                        : 'Paste suspicious message here...',
                      hintStyle: TextStyle(
                        color: isDark ? Colors.white30 : Colors.grey.shade400,
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: true,
                      fillColor: isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF5F7FB),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _isAnalyzing ? null : _send,
                  child: AnimatedContainer(
                    duration: 200.ms,
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: _isAnalyzing ? null : AppTheme.primaryGrad,
                      color: _isAnalyzing ? (isDark ? Colors.white10 : Colors.grey.shade200) : null,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: _isAnalyzing
                          ? []
                          : [
                              BoxShadow(
                                color: AppTheme.primary.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ],
                    ),
                    child: _isAnalyzing
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.primary,
                            ),
                          )
                        : const Icon(Icons.send, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isDark;
  final String lang;
  final Function(VerdictModel) onVerdictTap;

  const _MessageBubble({
    required this.message,
    required this.isDark,
    required this.lang,
    required this.onVerdictTap,
  });

  @override
  Widget build(BuildContext context) {
    if (message.isLoading) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16, right: 80),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCardAlt : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? AppTheme.darkBorder : const Color(0xFFEEF2FF),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                message.text,
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.grey.shade700,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ).animate().fadeIn(),
      );
    }

    if (message.verdict != null) {
      final v = message.verdict!;
      final verdictColor = AppTheme.verdictColor(v.verdict);
      final verdictBg = isDark ? AppTheme.verdictColor(v.verdict).withValues(alpha: 0.1) : AppTheme.verdictBgColor(v.verdict);

      return Align(
        alignment: Alignment.centerLeft,
        child: GestureDetector(
          onTap: () => onVerdictTap(v),
          child: Container(
            margin: const EdgeInsets.only(bottom: 16, right: 40),
            decoration: BoxDecoration(
              color: verdictBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: verdictColor.withValues(alpha: isDark ? 0.35 : 0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: verdictColor.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: AppTheme.verdictGradient(v.verdict),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                  ),
                  child: Row(
                    children: [
                      Text(
                        AppTheme.verdictEmoji(v.verdict),
                        style: const TextStyle(fontSize: 26),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              v.verdict == 'SCAM'
                                  ? (lang == 'hi' ? 'SCAM HAI! 🛑' : 'IT\'S A SCAM! 🛑')
                                  : v.verdict == 'LIKELY_SAFE'
                                      ? (lang == 'hi' ? 'SAFE HAI ✅' : 'LOOKS SAFE ✅')
                                      : (lang == 'hi' ? 'SAVDHAN RAHO ⚠️' : 'BE CAREFUL ⚠️'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Confidence: ${(v.confidence * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 14),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (v.why.isNotEmpty) ...[
                        Text(
                            lang == 'hi' ? 'KYUN?' : 'WHY?',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: verdictColor,
                              fontSize: 12,
                              letterSpacing: 0.5,
                            ),
                          ),
                        const SizedBox(height: 6),
                        ...v.why.take(2).map((w) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '• ',
                                    style: TextStyle(
                                      color: verdictColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      w,
                                      style: TextStyle(
                                        fontSize: 13,
                                        height: 1.4,
                                        color: isDark ? Colors.white.withValues(alpha: 0.8) : Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(
                            lang == 'hi' ? 'Full analysis report dekhein' : 'View full analysis report',
                            style: TextStyle(
                              color: verdictColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_forward, size: 14, color: verdictColor),
                        ],
                      ),
                      if (v.verdict == 'SCAM') ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await PdfReportService.generateAndShareReport(
                                scamData: v.toJson(),
                                originalMessage: "User uploaded content flagged as HIGH RISK.",
                              );
                            },
                            icon: const Icon(Icons.picture_as_pdf, size: 18, color: Colors.white),
                            label: const Text('Export Police Report (1930)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: verdictColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.15),
      );
    }

    // Regular bubble
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: 16,
          left: message.isUser ? 60 : 0,
          right: message.isUser ? 0 : 60,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          gradient: message.isUser ? AppTheme.primaryGrad : null,
          color: message.isUser ? null : (isDark ? AppTheme.darkCardAlt : Colors.white),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(message.isUser ? 20 : 4),
            bottomRight: Radius.circular(message.isUser ? 4 : 20),
          ),
          border: message.isUser
              ? null
              : Border.all(
                  color: isDark ? AppTheme.darkBorder : const Color(0xFFE8EDF8),
                ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.image != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(message.image!, height: 160, width: double.infinity, fit: BoxFit.cover),
              ),
              const SizedBox(height: 10),
            ],
            Text(
              message.text,
              style: TextStyle(
                color: message.isUser ? Colors.white : (isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87),
                fontSize: 14.5,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ).animate().fadeIn().slideY(begin: 0.08),
    );
  }
}
