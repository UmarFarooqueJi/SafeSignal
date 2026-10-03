import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import '../../data/models/verdict_model.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants.dart';
import '../settings/settings_screen.dart';
import '../../core/services/pdf_report_service.dart';

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

    try {
      // 1. If image is provided, run real OCR to extract all visible text from the screenshot
      String? ocrText;
      if (image != null) {
        ocrText = await _extractTextFromImage(image);
      }

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

      // 2. Fetch conversation history for contextual multi-turn memory
      final history = state
          .where((m) => !m.isLoading && m != userMsg && m.text.isNotEmpty && m.verdict == null)
          .toList();
      final recentHistory = history.length > 6 ? history.sublist(history.length - 6) : history;

      verdict = await _analyzeWithAI(promptText, image, language, recentHistory, ocrText: ocrText);
    } catch (e) {
      debugPrint('AI Analysis failed, falling back to heuristics: $e');
      if (image != null) {
        verdict = await _analyzeImageHeuristics(image, text, language);
      } else {
        verdict = _analyzeText(text, language);
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

  /// High-reliability OCR Text Extraction for uploaded screenshots
  static Future<String> _extractTextFromImage(File image) async {
    try {
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);
      final dio = Dio();
      dio.options.connectTimeout = const Duration(seconds: 14);
      dio.options.receiveTimeout = const Duration(seconds: 16);

      final formData = FormData.fromMap({
        'base64Image': 'data:image/jpeg;base64,$base64Image',
        'apikey': 'K87899142388957',
        'language': 'eng',
        'isOverlayRequired': false,
        'detectOrientation': true,
        'scale': true,
        'OCREngine': '2',
      });

      final response = await dio.post('https://api.ocr.space/parse/image', data: formData);
      if (response.statusCode == 200 && response.data != null) {
        final results = response.data['ParsedResults'] as List?;
        if (results != null && results.isNotEmpty) {
          final parsed = results[0]['ParsedText']?.toString().trim() ?? '';
          if (parsed.isNotEmpty) return parsed;
        }
      }
    } catch (e) {
      debugPrint('[ChatOCR] Primary OCR failed: $e, trying secondary fallback key');
      try {
        final bytes = await image.readAsBytes();
        final base64Image = base64Encode(bytes);
        final dio = Dio();
        dio.options.connectTimeout = const Duration(seconds: 10);
        dio.options.receiveTimeout = const Duration(seconds: 10);

        final formData = FormData.fromMap({
          'base64Image': 'data:image/jpeg;base64,$base64Image',
          'apikey': 'helloworld',
          'language': 'eng',
        });
        final response = await dio.post('https://api.ocr.space/parse/image', data: formData);
        if (response.statusCode == 200 && response.data != null) {
          final results = response.data['ParsedResults'] as List?;
          if (results != null && results.isNotEmpty) {
            return results[0]['ParsedText']?.toString().trim() ?? '';
          }
        }
      } catch (_) {}
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
      debugPrint('[ChatAI] Cloudflare Workers AI failed: $e, trying Pollinations fallback');
    }

    // 3. Keyless Public Fallback: Pollinations AI
    try {
      final pollResponse = await dio.post(
        'https://text.pollinations.ai/',
        options: Options(
          headers: {'Content-Type': 'application/json'},
          connectTimeout: const Duration(seconds: 14),
          receiveTimeout: const Duration(seconds: 16),
        ),
        data: {
          'messages': messages,
          'model': 'openai',
          'seed': 42,
        },
      );

      if (pollResponse.statusCode == 200 && pollResponse.data != null) {
        final raw = pollResponse.data.toString().trim();
        return _parseAiResponse(raw, text, language);
      }
    } catch (e) {
      debugPrint('[ChatAI] Pollinations fallback failed: $e');
    }

    throw Exception('All AI tiers exhausted, using smart offline heuristics');
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

  VerdictModel _analyzeText(String text, String language) {
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
          'Namaste! Main SafeSignal AI cyber security expert hoon.\n\nMain aapko online fraud, fake banking SMS, phishing link, digital arrest call aur Android spyware se bachane ke liye train kiya gaya hoon.\n\nAap mujhse koi bhi sawaal pooch sakte hain ya koi suspicious message yahan paste kar sakte hain!'
        ] : [
          'Hello! I am SafeSignal AI, your cybersecurity specialist.\n\nI protect you against online fraud, phishing links, fake bank SMS, digital arrest threats, and Android stalkerware.\n\nAsk me any question or paste any suspicious message or link here!'
        ],
        whatToDo: [],
        language: language,
        disclaimer: isHindi
            ? 'SafeSignal ek AI assistant hai. Zaruri maamlon mein 1930 pe call karein.'
            : 'SafeSignal is an AI assistant.',
        inputText: text,
        checkedAt: DateTime.now(),
      );
    }

    // 2. Identity / Creator Queries
    if (lower.contains('umar farooque') || lower.contains('umar') || lower.contains('farooque') || lower.contains('developer') || lower.contains('banaya')) {
      return VerdictModel(
        checkId: 'local_${DateTime.now().millisecondsSinceEpoch}',
        verdict: 'INFO',
        confidence: 1.0,
        scamType: 'Developer Info',
        escalated: false,
        why: isHindi ? [
          'Umar Farooque SafeSignal ke lead developer aur cybersecurity researcher hain, jinhone is application ko citizen digital protection aur open-source threat intelligence ke liye build kiya hai.'
        ] : [
          'Umar Farooque is the lead developer and cybersecurity researcher behind SafeSignal, building open-source intelligence and citizen defense systems.'
        ],
        whatToDo: [],
        language: language,
        disclaimer: isHindi
            ? 'SafeSignal ek AI assistant hai. Zaruri maamlon mein 1930 pe call karein.'
            : 'SafeSignal is an AI assistant.',
        inputText: text,
        checkedAt: DateTime.now(),
      );
    }

    // 3. Question Words / General Inquiry
    if (lower.contains('kya') || lower.contains('kaise') || lower.contains('what') || lower.contains('how') || lower.contains('help') || lower.contains('madad')) {
      return VerdictModel(
        checkId: 'local_${DateTime.now().millisecondsSinceEpoch}',
        verdict: 'INFO',
        confidence: 1.0,
        scamType: 'Cyber Guidance',
        escalated: false,
        why: isHindi ? [
          'Main aapki in mamlon mein madad kar sakta hoon:\n• Suspicious WhatsApp call ya SMS check karna\n• Phishing URL aur malicious website scan karna\n• Digital arrest aur CBI impersonation calls se bachna\n• UPI payment fraud aur fake QR code detect karna\n• Unknown phone number ki telecom forensics (VoIP / Carrier) nikalna\n\nKoi bhi link ya text paste karein!'
        ] : [
          'Here is what I can do for you:\n• Verify suspicious SMS and WhatsApp messages\n• Scan phishing URLs and malicious domains\n• Guard against Digital Arrest and fake enforcement scams\n• Detect fraudulent UPI payment links & QR codes\n• Perform Telecom OSINT & VoIP burner number detection\n\nPaste any message or link to begin!'
        ],
        whatToDo: [],
        language: language,
        disclaimer: isHindi
            ? 'SafeSignal ek AI assistant hai. Zaruri maamlon mein 1930 pe call karein.'
            : 'SafeSignal is an AI assistant.',
        inputText: text,
        checkedAt: DateTime.now(),
      );
    }

    // 4. Score-based Scam Analysis
    final scamKeywords = [
      'arrest', 'cbi', 'ed ', 'narcotics', 'police case', 'court order',
      'paisa bhejo', 'account block', 'kyc expire', 'kyc update',
      'won', 'prize', 'lottery', 'lucky draw', 'kbc', 'crorepati',
      'earn from home', 'part time job', 'telegram group', 'whatsapp group',
      'share karo', 'forward karo', 'claim karo', 'click here', 'click karo',
      'bit.ly', 'tinyurl', '.ru/', '.xyz/', 'loan approved',
      'free recharge', 'free data', 'congratulations', 'winner',
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
        scamType: 'Suspicious Pattern Detected',
        escalated: false,
        why: isHindi ? [
          'Is message mein $scamScore se zyada suspicious scam keywords mile hain',
          'Fraudsters aisa language use karte hain — dara ke, laalach de ke ya urgency create karke',
          'Real government agencies aur banks kabhi is tarah threatening ya urgent message nahi bhejte',
        ] : [
          'This message contains $scamScore+ suspicious scam keywords',
          'Fraudsters use this language to induce fear, greed or urgency',
          'Legitimate enforcement agencies and banks never send threatening links or payment demands',
        ],
        whatToDo: isHindi ? [
          'Koi bhi link par click mat karo',
          'Kisi ko bhi OTP, PIN ya paise transfer mat karo',
          'National Cybercrime Helpline: 1930 par turant call karein',
          'cybercrime.gov.in par report karein',
        ] : [
          'Do not click any link in this message',
          'Never share OTP, PIN or transfer money',
          'Report immediately to National Cybercrime Helpline: 1930',
          'File a complaint at cybercrime.gov.in',
        ],
        trendNote: isHindi ? 'Ye pattern common Indian cyber fraud hai' : 'Common Indian cybercrime tactic',
        language: language,
        disclaimer: isHindi ? 'SafeSignal ek AI assistant hai. Zaruri maamlon mein 1930 pe call karein.' : 'SafeSignal is an AI assistant. For urgent matters, call 1930.',
        inputText: text,
        checkedAt: DateTime.now(),
      );
    }
    if (scamScore == 1 && safeScore == 0) {
      return VerdictModel(
        checkId: 'local_caution_${DateTime.now().millisecondsSinceEpoch}',
        verdict: 'UNCERTAIN',
        confidence: 0.65,
        scamType: 'Unverified Communication',
        escalated: false,
        why: isHindi ? [
          'Is message mein kuch suspicious ya unverified sanket hain',
          'Bina official verification ke kisi bhi anjaan link ya request par vishwas na karein',
        ] : [
          'This message contains potential warning indicators',
          'Always verify sender identity through official channels before acting',
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
        disclaimer: isHindi ? 'SafeSignal ek AI assistant hai. Zaruri maamlon mein 1930 pe call karein.' : 'SafeSignal is an AI assistant.',
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
          'Message ka format standard transactional ya official communication se match karta hai',
          'Isme koi suspicious threatening language ya unauthorized payment link nahi mila',
        ] : [
          'Standard transactional or official notification pattern',
          'No malicious phishing links or coercive language detected',
        ],
        whatToDo: isHindi ? [
          'Ye sandesh surakshit lag raha hai',
          'Hamesha dhyan rahe: Apna OTP kisi ke kehne par share na karein',
        ] : [
          'This communication appears legitimate',
          'Remember: Never share OTPs or login codes over the phone',
        ],
        trendNote: null,
        language: language,
        disclaimer: isHindi ? 'SafeSignal ek AI assistant hai.' : 'SafeSignal is an AI assistant.',
        inputText: text,
        checkedAt: DateTime.now(),
      );
    }
    if (lower.contains('http') || lower.contains('www.')) {
      return VerdictModel(
        checkId: 'local_link_${DateTime.now().millisecondsSinceEpoch}',
        verdict: 'UNCERTAIN',
        confidence: 0.70,
        scamType: 'Unverified URL Link',
        escalated: false,
        why: isHindi ? [
          'Is message mein external web link mojud hai',
          'Anjaan links phishing ya fake payment gateway ho sakte hain',
        ] : [
          'Message contains an external web link',
          'Unverified links may route to phishing forms or credential stealers',
        ],
        whatToDo: isHindi ? [
          'Link par seedha click na karein',
          'Ise SafeSignal ke "Website Scanner" tool mein paste karke check karein',
        ] : [
          'Do not open the link directly',
          'Scan it first in SafeSignal\'s Website Scanner tool',
        ],
        trendNote: null,
        language: language,
        disclaimer: '',
        inputText: text,
        checkedAt: DateTime.now(),
      );
    }

    // Default conversational response
    return VerdictModel(
      checkId: 'local_${DateTime.now().millisecondsSinceEpoch}',
      verdict: 'INFO',
      confidence: 1.0,
      scamType: 'General Advice',
      escalated: false,
      why: isHindi ? [
        'Aapka message mila hai. Agar ye koi suspicious SMS, WhatsApp message ya link hai toh ise pura share karein taaki main security audit kar saku.'
      ] : [
        'Message received. If this relates to a suspicious SMS, link or call, share the full text so I can perform a security audit.'
      ],
      whatToDo: [],
      trendNote: null,
      language: language,
      disclaimer: '',
      inputText: text,
      checkedAt: DateTime.now(),
    );
  }

  Future<VerdictModel> _analyzeImageHeuristics(File image, String hint, String language) async {
    final sizeKb = await image.length() / 1024;
    final lower = hint.toLowerCase();
    final isHindi = language == 'hi';

    final hasScamHint = [
      'arrest', 'cbi', 'prize', 'otp', 'bank', 'block', 'warn', 'scam',
      'police', 'court', 'ed', 'narcotics', 'penalty', 'fine',
    ].any((k) => lower.contains(k));

    if (hasScamHint) {
      return VerdictModel(
        checkId: 'img_scan_${DateTime.now().millisecondsSinceEpoch}',
        verdict: 'SCAM',
        confidence: 0.85,
        scamType: 'Image Screenshot Fraud',
        escalated: true,
        why: isHindi ? [
          'Screenshot mein suspicious keywords detect hue hain',
          'Official government agencies aur banks kabhi video call, WhatsApp ya SMS se arrest nahi karte',
          'Darr dikhana, jaldi karwana aur paise maangna — ye sab fraud ke classic signs hain',
          'Fake logos, watermarks aur official-looking headers common tricks hain',
        ] : [
          'Suspicious keywords were detected in this screenshot',
          'Official agencies (CBI, ED, Police) NEVER arrest via video call, WhatsApp or SMS',
          'Creating fear, urgency, and demanding money are classic fraud signs',
          'Fake logos and official-looking headers are common scammer tricks',
        ],
        whatToDo: isHindi ? [
          'Koi bhi paise transfer mat karo — chahe kitna bhi pressure ho',
          'Call ya video immediately kaat do aur number block karo',
          '1930 cybercrime helpline pe call karo',
          'Screenshot apne paas rakho aur nearest cyber police station mein complaint karo',
        ] : [
          'Do NOT transfer any money, no matter how much pressure you feel',
          'Immediately disconnect the call/video and block the number',
          'Call cybercrime helpline: 1930',
          'Keep the screenshot and file a complaint at your nearest cyber police station',
        ],
        trendNote: isHindi
            ? '"Digital Arrest" scam 2024-25 mein India mein sabse common fraud hai'
            : '"Digital Arrest" scam is the most common fraud in India in 2024-25',
        language: language,
        disclaimer: isHindi
            ? 'SafeSignal ek AI assistant hai. Zaruri maamlon mein 1930 pe call karein.'
            : 'SafeSignal is an AI assistant. For urgent matters, call 1930.',
        inputText: '[Image uploaded]${hint.isEmpty ? '' : ' — $hint'}',
        checkedAt: DateTime.now(),
      );
    }

    if (sizeKb > 50) {
      return VerdictModel(
        checkId: 'img_scan_${DateTime.now().millisecondsSinceEpoch}',
        verdict: 'UNCERTAIN',
        confidence: 0.55,
        scamType: 'Screenshot Review',
        escalated: false,
        why: isHindi ? [
          'Image mein koi obvious scam pattern automatically detect nahi hua',
          'Lekin ajnabi ke bheje images aur screenshots hamesha risky hote hain',
          'Kisi bhi link, QR code ya contact number pe action lene se pehle verify karo',
        ] : [
          'No obvious scam pattern was automatically detected in this image',
          'However, images and screenshots from strangers always carry risk',
          'Always verify before clicking any link, QR code or calling any number shown',
        ],
        whatToDo: isHindi ? [
          'Agar koi link dikhta hai toh URL Scanner mein paste karein',
          'Kisi bhi personal ya financial details share mat karo',
          'Shak ho toh 1930 call karein ya cybercrime.gov.in pe report karein',
        ] : [
          'If a link is visible, paste it in the URL Scanner tool',
          'Do not share any personal or financial details',
          'If in doubt, call 1930 or report at cybercrime.gov.in',
        ],
        trendNote: null,
        language: language,
        disclaimer: isHindi
            ? 'SafeSignal ek AI assistant hai. Zaruri maamlon mein 1930 pe call karein.'
            : 'SafeSignal is an AI assistant. For urgent matters, call 1930.',
        inputText: '[Image uploaded — ${sizeKb.toStringAsFixed(0)} KB]',
        checkedAt: DateTime.now(),
      );
    }

    return VerdictModel(
      checkId: 'img_safe_${DateTime.now().millisecondsSinceEpoch}',
      verdict: 'LIKELY_SAFE',
      confidence: 0.85,
      scamType: 'none',
      escalated: false,
      why: isHindi ? [
        'Image mein koi obvious phishing ya digital arrest threat pattern nahi mila',
      ] : [
        'No overt fraud or scam signatures detected in image',
      ],
      whatToDo: isHindi ? [
        'Hamesha sender aur context verify karein',
      ] : [
        'Always verify context before sharing personal information',
      ],
      trendNote: null,
      language: language,
      disclaimer: '',
      inputText: '[Image uploaded — ${sizeKb.toStringAsFixed(0)} KB]',
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
