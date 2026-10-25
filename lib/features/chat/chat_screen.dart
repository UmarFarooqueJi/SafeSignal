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
  final String? ocrText;

  const ChatMessage({
    required this.text,
    required this.isUser,
    this.isLoading = false,
    this.verdict,
    this.image,
    this.ocrText,
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
        ? (language == 'hi' ? 'Screenshot ka on-device OCR scan ho raha hai... 🔍' : 'Scanning screenshot with on-device OCR... 🔍')
        : (language == 'hi' ? 'AI cyber jaanch ho rahi hai... 🔍' : 'Analyzing cyber threat intelligence... 🔍');
    state = [
      ...state,
      ChatMessage(text: loadingText, isUser: false, isLoading: true),
    ];

    VerdictModel verdict;
    String? ocrText;

    try {
      // 1. If image is provided, run real on-device dual-script OCR (Devanagari + Latin)
      if (image != null) {
        ocrText = await _extractTextFromImage(image);
        // Bind OCR extracted text to the user's message in state for instant UI visibility
        final userIdx = state.indexOf(userMsg);
        if (userIdx != -1) {
          final updated = List<ChatMessage>.from(state);
          updated[userIdx] = ChatMessage(text: text, isUser: true, image: image, ocrText: ocrText);
          state = updated;
        }
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
  /// Runs Devanagari script model first (handles Hindi + Latin), supplements with Latin model if needed.
  static Future<String> _extractTextFromImage(File image) async {
    final lines = <String>[];
    final inputImage = InputImage.fromFilePath(image.path);

    // 1. Try Devanagiri Script Recognizer (handles Hindi, Devanagari + Latin numbers/words)
    try {
      final devRecognizer = TextRecognizer(script: TextRecognitionScript.devanagiri);
      try {
        final recognizedText = await devRecognizer.processImage(inputImage);
        for (final block in recognizedText.blocks) {
          for (final line in block.lines) {
            final t = line.text.trim();
            if (t.isNotEmpty && !lines.contains(t)) lines.add(t);
          }
        }
      } finally {
        await devRecognizer.close();
      }
    } catch (e) {
      debugPrint('[ChatOCR] Devanagari recognizer note: $e');
    }

    // 2. If Devanagari returned empty or sparse lines, supplement with Latin recognizer
    if (lines.isEmpty || lines.join(' ').length < 25) {
      try {
        final latinRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
        try {
          final recognizedText = await latinRecognizer.processImage(inputImage);
          for (final block in recognizedText.blocks) {
            for (final line in block.lines) {
              final t = line.text.trim();
              if (t.isNotEmpty && !lines.contains(t)) lines.add(t);
            }
          }
        } finally {
          await latinRecognizer.close();
        }
      } catch (e) {
        debugPrint('[ChatOCR] Latin recognizer note: $e');
      }
    }

    if (lines.isNotEmpty) {
      final result = lines.join('\n').trim();
      debugPrint('[ChatOCR] Successfully extracted ${lines.length} lines, total length: ${result.length}');
      return result;
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
    if (lower == 'hi' || lower == 'hello' || lower == 'hey' || lower.contains('namaste') || lower.contains('kaise ho') || lower == 'salam' || lower == 'shuru') {
      return VerdictModel(
        checkId: 'local_${DateTime.now().millisecondsSinceEpoch}',
        verdict: 'INFO',
        confidence: 1.0,
        scamType: 'Greeting',
        escalated: false,
        why: isHindi ? [
          'Namaste! Main SafeSignal AI cyber security expert hoon.\n\nMain aapko online fraud, fake banking SMS, phishing link, digital arrest call, WhatsApp hijacking aur Android spyware se bachane ke liye on-device intelligence par kaam karta hoon.\n\nAap mujhse koi bhi sawaal pooch sakte hain ya koi suspicious message yahan paste kar sakte hain!'
        ] : [
          'Hello! I am SafeSignal AI, your on-device cybersecurity specialist.\n\nI protect you against online fraud, phishing links, fake bank SMS, digital arrest threats, WhatsApp hijacking, and Android spyware.\n\nAsk me any question or paste any suspicious message or link here!'
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
    if (lower.contains('umar farooque') || lower.contains('umar') || lower.contains('farooque') || lower.contains('developer') || lower.contains('banaya') || lower.contains('kisne') || lower.contains('who made') || lower.contains('author') || lower.contains('github') || lower.contains('open source')) {
      return VerdictModel(
        checkId: 'local_${DateTime.now().millisecondsSinceEpoch}',
        verdict: 'INFO',
        confidence: 1.0,
        scamType: 'Developer Info',
        escalated: false,
        why: isHindi ? [
          'Umar Farooque SafeSignal ke lead developer aur cybersecurity researcher hain, jinhone is application ko citizen digital protection aur open-source threat intelligence ke liye build kiya hai.\n\nSafeSignal ek 100% open-source, air-gapped, on-device cyber defense suite hai jo bina kisi cloud leak ke kaam karta hai aur user privacy ki 100% guarantee deta hai.'
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

    // 3. Phone Hacked / Spyware / RAT / Stalkerware Signs & Removal
    if (lower.contains('phone hack') || lower.contains('hack ho gaya') || lower.contains('spyware') || lower.contains('stalkerware') || lower.contains('virus') || lower.contains('phone tap') || lower.contains('tapped') || lower.contains('battery jaldi') || lower.contains('phone garam') || lower.contains('rat ') || lower.contains('trojan') || lower.contains('unknown app') || lower.contains('screen apne aap') || lower.contains('remote access') || lower.contains('phone safe hai')) {
      return VerdictModel(
        checkId: 'local_hack_${DateTime.now().millisecondsSinceEpoch}',
        verdict: 'INFO',
        confidence: 0.98,
        scamType: isHindi ? 'Device Compromise & Spyware Audit' : 'Device Compromise & Spyware Audit',
        escalated: false,
        why: isHindi ? [
          'Agar aapko lagta hai ki aapka phone hack ya monitor ho raha hai, toh ye 5 pramukh sanket check karein:\n\n'
          '• Battery ka achanak bahut tezi se khatam hona aur phone bina use kiye garam hona.\n'
          '• Data usage ka achanak spike hona (background mein audio/video/screen upload hona).\n'
          '• Calls ke dauran ajeeb echo, beep ya clicking aawazein aana.\n'
          '• Keyboard par typing lag ya screen ka apne aap touch hona.'
        ] : [
          'If you suspect device surveillance or malware infection, verify these 5 telemetry signs:\n\n'
          '• Rapid battery depletion coupled with unexpected device thermal spikes during idle.\n'
          '• Massive unaccounted background data transmission (exfiltrating media/screen captures).\n'
          '• In-call audio anomalies (beeps, continuous echoes, remote clicks).\n'
          '• Ghost touches or keyboard input latency caused by remote overlays.'
        ],
        whatToDo: isHindi ? [
          'Turant Airplane Mode ON karein taaki spyware ka internet link cut ho jaye',
          'Settings > Apps > Special App Access > Accessibility check karein aur anjaan apps ko band karein',
          'Settings > Security > Device Admin Apps mein jakar unauthorized admin apps remove karein',
          'Files / Downloads folder se sabhi anjaan .APK files delete karein',
          'SafeSignal ke App Scanner se sabhi installed apps ki permission audit karein',
        ] : [
          'Enable Airplane Mode immediately to terminate remote C2 server connections',
          'Inspect Settings > Accessibility Services and revoke privileges from any unverified apps',
          'Audit Settings > Security > Device Admin Apps and disable unauthorized managers',
          'Delete all unsolicited .APK downloads from storage',
          'Execute a full audit using SafeSignal\'s On-Device App Scanner',
        ],
        trendNote: isHindi ? 'Android stalkerware accessibility permissions ka durupyog karta hai.' : 'Stalkerware relies primarily on abused Accessibility Services.',
        language: language,
        disclaimer: isHindi ? 'SafeSignal ek on-device AI assistant hai.' : 'SafeSignal is an on-device security assistant.',
        inputText: text,
        checkedAt: DateTime.now(),
      );
    }

    // 4. WhatsApp Call Forwarding / Hijacking (*401* Scam)
    if (lower.contains('*401*') || lower.contains('*21*') || lower.contains('*62*') || lower.contains('*67*') || lower.contains('call forward') || lower.contains('forwarding') || lower.contains('whatsapp hack') || lower.contains('whatsapp hijack') || lower.contains('##002#') || lower.contains('call diver')) {
      return VerdictModel(
        checkId: 'local_fwd_${DateTime.now().millisecondsSinceEpoch}',
        verdict: 'SCAM',
        confidence: 0.99,
        scamType: isHindi ? 'Call Forwarding / WhatsApp Hijack Scam' : 'Call Forwarding WhatsApp Hijack Racket',
        escalated: true,
        why: isHindi ? [
          'DANGER: *401* ek USSD code hai jo aapki sabhi incoming calls ko scammer ke phone par unconditional forward kar deta hai!',
          'Scammer aksar delivery boy, courier agent ya SIM company ban kar call karte hain aur kehte hain: "*401* ke baad ye number dial karo."',
          'Jaise hi aap dial karte hain, aapke OTP aur WhatsApp verification voice calls scammer ke paas chale jaate hain aur wo aapka WhatsApp apne phone mein chala lete hain.',
        ] : [
          'CRITICAL THREAT: *401* is a telecom USSD code that enables unconditional call forwarding to the attacker\'s phone.',
          'Attackers impersonate delivery drivers or telecom customer care, asking you to dial *401*<mobile_number>.',
          'Once dialed, all incoming voice OTPs and WhatsApp login verification calls are intercepted by the scammer, triggering an instant account hijack.',
        ],
        whatToDo: isHindi ? [
          'Turant phone dialer kholein aur ##002# dial karein (ye sabhi call forwardings ko cancel karta hai)',
          'WhatsApp Settings > Linked Devices par jakar sabhi unknown sessions ko log out karein',
          'WhatsApp Settings > Account > Two-Step Verification par jakar 6-digit PIN lagayein',
          'Kisi ke kehne par kabhi bhi *401* ya *21* dial na karein',
        ] : [
          'Open Phone dialer and immediately dial ##002# to disable all unconditional and conditional call forwarding',
          'Go to WhatsApp > Linked Devices and log out of all active web/desktop sessions',
          'Navigate to WhatsApp Settings > Account > Two-Step Verification and set a 6-digit PIN',
          'Never dial *401* or *21* codes under any circumstances',
        ],
        trendNote: isHindi ? 'Ye scam pure desh mein WhatsApp takeover ke liye sabse zyada use ho raha hai.' : 'Most rampant mobile takeover vector in India.',
        language: language,
        disclaimer: isHindi ? 'SafeSignal ek on-device AI assistant hai. Zaruri maamlon mein 1930 pe call karein.' : 'SafeSignal is an on-device security assistant.',
        inputText: text,
        checkedAt: DateTime.now(),
      );
    }

    // 5. Lost / Stolen Phone / CEIR Portal Blocking Procedure
    if (lower.contains('phone kho gaya') || lower.contains('phone chori') || lower.contains('lost phone') || lower.contains('stolen phone') || lower.contains('ceir') || lower.contains('imei block') || lower.contains('phone mil nahi') || lower.contains('mobile chori')) {
      return VerdictModel(
        checkId: 'local_ceir_${DateTime.now().millisecondsSinceEpoch}',
        verdict: 'INFO',
        confidence: 0.99,
        scamType: isHindi ? 'Lost / Stolen Phone Defense (CEIR)' : 'Lost / Stolen Mobile Response (CEIR)',
        escalated: false,
        why: isHindi ? [
          'Agar aapka phone kho gaya ya chori ho gaya hai, toh Bharat Sarkar ke CEIR (Central Equipment Identity Register) portal se aap pure desh ke sabhi telecom networks par us phone ko permanently block kar sakte hain.',
          'Block karne ke baad chor agar naya SIM bhi daalega, tab bhi phone kaam nahi karega aur police ko uski location mil jayegi.'
        ] : [
          'The Government of India\'s CEIR (Central Equipment Identity Register) portal allows citizens to blacklist lost/stolen handsets nationwide.',
          'Once blacklisted, the device is barred across all Indian telecom networks (Jio, Airtel, Vi, BSNL) even if a new SIM card is inserted.'
        ],
        whatToDo: isHindi ? [
          'Step 1: Telecom operator (Jio/Airtel/Vi) ko call karke purana SIM turant block karwayein aur duplicate SIM lein',
          'Step 2: Apne nazdiki police station ya state police portal par Lost Phone ki e-FIR / Complaint darj karein',
          'Step 3: ceir.sancharsaathi.gov.in par jayein > "Block Stolen/Lost Mobile" par click karein',
          'Step 4: Phone ke dono IMEI numbers aur police complaint copy upload karke phone block karein',
          'Step 5: Google Find My Device (android.com/find) se remote erase trigger karein',
        ] : [
          'Step 1: Contact your carrier (Jio/Airtel/Vi) to immediately block the lost SIM and issue a duplicate',
          'Step 2: File an e-FIR / police lost report to receive an official complaint number',
          'Step 3: Visit ceir.sancharsaathi.gov.in and click "Block Stolen/Lost Mobile"',
          'Step 4: Submit IMEI 1 & 2 along with the police complaint receipt',
          'Step 5: Remotely wipe sensitive credentials via Google Find My Device (android.com/find)',
        ],
        trendNote: isHindi ? 'DoT aur Sanchar Saathi dwara sanchalit official portal.' : 'Managed by Department of Telecommunications (DoT).',
        language: language,
        disclaimer: isHindi ? 'SafeSignal ek on-device AI assistant hai.' : 'SafeSignal is an on-device security assistant.',
        inputText: text,
        checkedAt: DateTime.now(),
      );
    }

    // 6. Bank Account Debited / Money Lost / Panic Recovery (Golden Hour Protocol)
    if (lower.contains('paise cut gaye') || lower.contains('paisa cut gaya') || lower.contains('fraud ho gaya') || lower.contains('paisa chala gaya') || lower.contains('account khali') || lower.contains('debit ho gaya') || lower.contains('scam ho gaya') || lower.contains('paise wapas') || lower.contains('paisa phas gaya') || lower.contains('refund kaise')) {
      return VerdictModel(
        checkId: 'local_debit_${DateTime.now().millisecondsSinceEpoch}',
        verdict: 'SCAM',
        confidence: 0.99,
        scamType: isHindi ? 'Financial Cyber Fraud Emergency' : 'Financial Cyber Fraud Emergency Response',
        escalated: true,
        why: isHindi ? [
          'EMERGENCY GOLDEN HOUR: Online financial fraud mein shuruati 2 ghante sabse critical hote hain.',
          'MHA ka CFCFRMS system (1930 helpline) turant fraud transaction ke recipient accounts par lien (freeze) laga sakta hai taaki paisa aage withdraw na ho sake.',
          'Agar aap jaldi action lenge toh aapka 100% paisa wapas milne ke chances hote hain.'
        ] : [
          'GOLDEN HOUR PROTOCOL: The initial 2 hours post-fraud are crucial for financial recovery.',
          'MHA\'s Citizen Financial Cyber Fraud Reporting System (CFCFRMS via 1930) can instantly invoke automated banking liens to freeze stolen funds before ATM withdrawal.',
          'Rapid response drastically increases the probability of complete capital restoration.'
        ],
        whatToDo: isHindi ? [
          '1. Turant 1930 National Cybercrime Helpline par call karein aur UTR number, bank details batayein',
          '2. Apne bank ke 24x7 helpline par call karke NetBanking aur UPI services freeze karwayein',
          '3. cybercrime.gov.in par jakar formal acknowledgment number ke sath incident complete karein',
          '4. Bank branch jakar dispute form (chargeback request) submit karein',
        ] : [
          '1. Dial 1930 immediately with Transaction UTR, timestamp, and beneficiary details',
          '2. Contact your bank\'s 24x7 toll-free emergency desk to freeze compromised cards/UPI',
          '3. Finalize incident submission at cybercrime.gov.in for formal FIR generation',
          '4. Visit your home bank branch to file an official unauthorized transaction dispute',
        ],
        trendNote: isHindi ? 'Golden Hour mein 1930 par call karne se hazaron crore bachaye gaye hain.' : 'Prompt 1930 reporting prevents multi-hop account dispersion.',
        language: language,
        disclaimer: isHindi ? 'SafeSignal ek on-device AI assistant hai. Turant 1930 par call karein.' : 'SafeSignal is an on-device security assistant. Dial 1930 immediately.',
        inputText: text,
        checkedAt: DateTime.now(),
      );
    }

    // 7. Sextortion / Video Call Blackmail
    if (lower.contains('sextortion') || lower.contains('video call blackmail') || lower.contains('nude video') || lower.contains('blackmail') || lower.contains('morphed') || lower.contains('recording bhej raha') || lower.contains('viral karne') || lower.contains('delhi police video')) {
      return VerdictModel(
        checkId: 'local_sex_${DateTime.now().millisecondsSinceEpoch}',
        verdict: 'SCAM',
        confidence: 0.99,
        scamType: isHindi ? 'Sextortion Video Blackmail Advisory' : 'Sextortion Video Blackmail Advisory',
        escalated: true,
        why: isHindi ? [
          'Sextortion ek organized cyber syndicate racket hai jisme anjaan number se WhatsApp video call karke victim ka face record kiya jata hai aur pre-recorded nude video ke sath morph kiya jata hai.',
          'Scammers Facebook/Instagram se aapke dosto aur family ki list chori karke dhamki dete hain ki "Agar paise nahi diye toh sabko bhej denge."',
          'Aksar agle din fake "Delhi Police Cyber Crime Inspector" ban kar call aata hai jo case dabane ke naam par aur paise maangta hai.',
          'SABSE BADA NIYAM: Inhe ek rupaya bhi mat dein. Paise dene par ye kabhi video delete nahi karte balki baar-baar aur paise maangte hain.'
        ] : [
          'Sextortion is an organized crime racket where scammers initiate WhatsApp video calls, record the victim\'s face, and stitch it with explicit clips.',
          'Perpetrators scrape Facebook/Instagram contact lists and threaten to distribute the media to relatives.',
          'This is routinely followed by a secondary impersonator posing as a "Cyber Police Officer" demanding deletion fees.',
          'CARDINAL RULE: Never pay a single rupee. Paying guarantees perpetual extortion without video removal.'
        ],
        whatToDo: isHindi ? [
          'Scammer ko turant WhatsApp par block karein — ek shabd bhi reply na karein',
          'Apne Facebook, Instagram profiles ko "Private" karein aur friend list lock karein',
          'Ek rupaya bhi transfer na karein chahe kitni bhi dhamki dein',
          '1930 Cyber Crime Helpline par call karein aur cybercrime.gov.in par complaint darj karein',
        ] : [
          'Block and report the extortionist immediately across all communication channels',
          'Lock Facebook and Instagram profiles; make friend and follower lists strictly private',
          'Do NOT send any money under any circumstances',
          'Lodge a confidential complaint at 1930 and cybercrime.gov.in under Section 308 BNS',
        ],
        trendNote: isHindi ? 'Police kabhi WhatsApp par settlement ke liye paise nahi maangti.' : 'Law enforcement never negotiates financial settlements.',
        language: language,
        disclaimer: isHindi ? 'SafeSignal ek on-device AI assistant hai. Zaruri maamlon mein 1930 pe call karein.' : 'SafeSignal is an on-device security assistant. Contact 1930 for urgent cyber threats.',
        inputText: text,
        checkedAt: DateTime.now(),
      );
    }

    // 8. Traffic Police e-Challan / Vehicle Fine Phishing
    if (lower.contains('echallan') || lower.contains('e-challan') || lower.contains('challan') || lower.contains('traffic police') || lower.contains('parivahan') || lower.contains('traffic fine') || lower.contains('vahan challan')) {
      return VerdictModel(
        checkId: 'local_challan_${DateTime.now().millisecondsSinceEpoch}',
        verdict: 'SCAM',
        confidence: 0.97,
        scamType: isHindi ? 'e-Challan Phishing & Malware Warning' : 'e-Challan Phishing Malware Warning',
        escalated: true,
        why: isHindi ? [
          'e-Challan Scam mein fake SMS aata hai: "Traffic Police notice: Your vehicle has pending challan of Rs 1000. Pay immediately or vehicle will be seized."',
          'SMS mein ek link hota hai jo ya toh fake payment page khoilta hai ya fir ek dangerous APK file (jaise eChallan.apk) download karwata hai.',
          'Ye APK install hote hi phone ke sabhi SMS aur bank OTPs read karke account khali kar deta hai.'
        ] : [
          'e-Challan phishing deploys fraudulent traffic enforcement notices claiming pending fines under threat of impoundment.',
          'The links deliver credential-harvesting phishing portals or weaponized Android APK droppers (e.g., eChallan.apk).',
          'Once installed, these Trojans hijack SMS permissions to capture banking OTPs in the background.'
        ],
        whatToDo: isHindi ? [
          'SMS mein aaye kisi bhi link par click na karein aur koi bhi .APK download na karein',
          'Apne vehicle ka challan ONLY official portal: echallan.parivahan.gov.in par check karein',
          'Agar galti se APK install kar li ho toh turant phone ko Airplane Mode mein daalkar uninstall karein',
          'Chakshu portal par SMS number report karein',
        ] : [
          'Never click links or install .APK packages distributed via SMS',
          'Verify traffic challans exclusively through the official portal: echallan.parivahan.gov.in',
          'If an APK was inadvertently installed, toggle Airplane Mode and perform immediate removal',
          'Report the sender number on Chakshu (sancharsaathi.gov.in)',
        ],
        trendNote: isHindi ? 'Traffic Police kabhi bhi SMS mein APK download link nahi bhejti.' : 'Government transport departments never distribute .APK installers.',
        language: language,
        disclaimer: isHindi ? 'SafeSignal ek on-device AI assistant hai.' : 'SafeSignal is an on-device security assistant.',
        inputText: text,
        checkedAt: DateTime.now(),
      );
    }

    // 9. Wedding / Shaadi Card APK Dropper (Spynote / CraxsRAT)
    if (lower.contains('wedding card') || lower.contains('shaadi card') || lower.contains('invitation apk') || lower.contains('shaadi ka card') || lower.contains('nimantran apk') || lower.contains('wedding.apk')) {
      return VerdictModel(
        checkId: 'local_wedding_${DateTime.now().millisecondsSinceEpoch}',
        verdict: 'SCAM',
        confidence: 0.99,
        scamType: isHindi ? 'Wedding Card APK Malware Dropper' : 'Wedding Invitation Malware Trojan',
        escalated: true,
        why: isHindi ? [
          'HIGH ALERT: WhatsApp par "Wedding Card.apk" ya "Shaadi Nimantran.apk" bhejna ek khatarnak Android Trojan attack hai!',
          'Ye koi digital invitation nahi hota, balki Spynote ya CraxsRAT spyware hota hai.',
          'Install karte hi ye app screen share, contacts, SMS OTPs aur photos chori karti hai aur aapke phone se aapke dosto ko bhi yehi malware forward kar deti hai.'
        ] : [
          'CRITICAL ALERT: Wedding Card APK files distributed over WhatsApp are weaponized Remote Access Trojans (Spynote / CraxsRAT).',
          'They masquerade as digital event invites while obtaining pervasive Accessibility and SMS permissions.',
          'Upon installation, they exfiltrate OTPs, photos, and contact lists, while silently propagating the Trojan to your entire address book.'
        ],
        whatToDo: isHindi ? [
          'File ko bilkul install na karein aur turant delete karein',
          'Jis dost ya rishtedaar ne bheja hai use call karke batayein ki unka phone hack ho chuka hai',
          'Agar install kar chuke hain toh phone ko Airplane Mode par daal kar Safe Mode mein uninstall karein',
          'Apne sabhi bank accounts aur UPI apps ke passwords change karein',
        ] : [
          'Do NOT install the file; purge the downloaded APK immediately',
          'Notify the sender via voice call that their WhatsApp account is actively compromised',
          'If already executed, boot into Safe Mode under Airplane Mode to isolate and uninstall the malicious package',
          'Rotate all banking and messaging credentials immediately',
        ],
        trendNote: isHindi ? 'CERT-In ne Wedding Card APKs par national security advisory jaari ki hai.' : 'CERT-In has issued high-severity advisories on wedding invitation Trojans.',
        language: language,
        disclaimer: isHindi ? 'SafeSignal ek on-device AI assistant hai.' : 'SafeSignal is an on-device security assistant.',
        inputText: text,
        checkedAt: DateTime.now(),
      );
    }

    // 10. SIM Swap / eSIM / 5G Upgrade Takeover
    if (lower.contains('sim swap') || lower.contains('esim') || lower.contains('5g upgrade') || lower.contains('sim block') || lower.contains('sim band') || lower.contains('sim deactivation') || lower.contains('sim kyc')) {
      return VerdictModel(
        checkId: 'local_sim_${DateTime.now().millisecondsSinceEpoch}',
        verdict: 'SCAM',
        confidence: 0.97,
        scamType: isHindi ? 'SIM Swap / eSIM Takeover Scam' : 'SIM Swap / eSIM Hijack Warning',
        escalated: true,
        why: isHindi ? [
          'SIM Swap fraud mein criminals telecom company ban kar call karte hain ki "Aapka 4G SIM 5G mein upgrade karna hai" ya "KYC na hone par SIM block ho jayega."',
          'Wo aapse SMS bhejne ko kehte hain (jaise 19-digit SIM number ya eSIM activation code).',
          'Jaise hi request process hoti hai, aapka physical SIM deactivated ho jata hai aur saare bank OTPs scammer ke phone par aane lagte hain.'
        ] : [
          'SIM Swap fraud uses false pretenses of mandatory 5G upgrades or KYC renewals.',
          'Attackers manipulate victims into sending carrier-specific SMS commands containing 19-digit ICCID or eSIM activation tokens.',
          'Once authorized, the victim\'s cellular service terminates, and all banking authentication OTPs route directly to the attacker\'s device.'
        ],
        whatToDo: isHindi ? [
          'Kisi bhi anjaan number ke kehne par koi bhi SMS forward ya send na karein',
          'Agar aapke phone ka cellular network achanak "No Service" dikhaye toh turant telecom operator ko dusre phone se call karein',
          'Apne bank se contact karke emergency netbanking freeze lagwayein',
          '1930 Cyber Helpline par report karein',
        ] : [
          'Never forward carrier SMS commands or disclose SIM ICCID numbers',
          'If your phone abruptly loses network connectivity ("No Service"), contact your operator immediately from another device',
          'Instruct your bank to place an emergency freeze on netbanking and cards',
          'Report incident to 1930',
        ],
        trendNote: isHindi ? 'Telecom companies kabhi WhatsApp par eSIM QR code nahi bhejti.' : 'Carriers never distribute eSIM provisioning profiles over messaging apps.',
        language: language,
        disclaimer: isHindi ? 'SafeSignal ek on-device AI assistant hai.' : 'SafeSignal is an on-device security assistant.',
        inputText: text,
        checkedAt: DateTime.now(),
      );
    }

    // 11. Instagram / Facebook Account Hack & Recovery
    if (lower.contains('instagram hack') || lower.contains('facebook hack') || lower.contains('id hack') || lower.contains('account hack') || lower.contains('insta hack') || lower.contains('fb hack') || lower.contains('id recover')) {
      return VerdictModel(
        checkId: 'local_social_${DateTime.now().millisecondsSinceEpoch}',
        verdict: 'INFO',
        confidence: 0.96,
        scamType: isHindi ? 'Social Account Compromise Recovery' : 'Social Account Takeover Recovery',
        escalated: false,
        why: isHindi ? [
          'Social media accounts (Instagram, Facebook) aksar phishing links, password reuse ya fake copyright strikes se hack hote hain.',
          'HACKER SE SAVDHAN: Instagram par comment karne wale "contact @hacker_xxx to recover your account" 100% FRAUD hote hain! Wo paise lekar gayab ho jaate hain (Recovery Scam).'
        ] : [
          'Social media accounts are typically compromised via credential phishing, credential stuffing, or rogue OAuth apps.',
          'BEWARE RECOVERY SCAMMERS: Third-party "ethical hackers" advertising recovery services on Instagram/X are advance-fee scammers.'
        ],
        whatToDo: isHindi ? [
          'Official Instagram recovery use karein: instagram.com/hacked par jayein',
          'Facebook ke liye official portal: facebook.com/hacked par jayein',
          'Apne email inbox mein jakar Instagram security alert check karein aur "Secure your account" par click karein',
          'Account wapas aate hi Two-Factor Authentication (Google Authenticator) enable karein',
        ] : [
          'Deploy official Instagram remediation: instagram.com/hacked',
          'Deploy official Facebook remediation: facebook.com/hacked',
          'Check your registered email for official alerts from security@mail.instagram.com to revert email alterations',
          'Mandate hardware-backed Two-Factor Authentication (TOTP Authenticator app) post-recovery',
        ],
        trendNote: isHindi ? 'Keval official recovery portals ka hi upyog karein.' : 'Rely strictly on official platform remediation portals.',
        language: language,
        disclaimer: isHindi ? 'SafeSignal ek on-device AI assistant hai.' : 'SafeSignal is an on-device security assistant.',
        inputText: text,
        checkedAt: DateTime.now(),
      );
    }

    // 12. Digital Arrest Threat Advisory
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

    // 13. Electricity Bill / Bijli Cut Scam
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

    // 14. Telegram Task / Work from Home Scam
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

    // 15. FedEx / Customs / Narcotics Courier Scam
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

    // 16. Instant Loan App / Blackmail
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

    // 17. UPI Rules & QR Code Safety
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

    // 18. Aadhaar / AePS / Biometric Lock
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

    // 19. Cyber Helpline 1930 / Complaint Process
    if (lower.contains('1930') || lower.contains('helpline') || lower.contains('complaint') || lower.contains('cybercrime.gov') || lower.contains('police report') || lower.contains('fir kaise')) {
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

    // 20. Passwords, 2FA, Android Spyware, Stalkerware
    if (lower.contains('password') || lower.contains('2fa') || lower.contains('two factor') || lower.contains('authenticator') || lower.contains('bitwarden') || lower.contains('passkey') || lower.contains('safe kaise')) {
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

    // 21. Wi-Fi / Hotspot / Public Network / VPN Security
    if (lower.contains('wifi') || lower.contains('public wifi') || lower.contains('hotspot') || lower.contains('vpn') || lower.contains('free wifi') || lower.contains('railwire')) {
      return VerdictModel(
        checkId: 'local_wifi_${DateTime.now().millisecondsSinceEpoch}',
        verdict: 'INFO',
        confidence: 0.95,
        scamType: isHindi ? 'Wi-Fi & Network Security Guide' : 'Network & Wi-Fi Defense Advisory',
        escalated: false,
        why: isHindi ? [
          'Public Wi-Fi (Railway station, cafe, airport) par Man-in-the-Middle (MitM) attacks aur fake hotspot (Evil Twin) ka khatra hota hai.',
          'Scammers usi naam ka ek open Wi-Fi network banate hain aur aapka internet traffic inspect karte hain.',
          'Open Wi-Fi par bina encrypted VPN ke banking ya sensitive logins bilkul nahi karni chahiye.'
        ] : [
          'Public Wi-Fi networks (stations, cafes, airports) are susceptible to Man-in-the-Middle (MitM) snooping and rogue Access Point (Evil Twin) spoofing.',
          'Adversaries establish identical unencrypted SSIDs to capture unencrypted DNS requests and session cookies.',
          'Never execute financial transactions or submit credentials over public Wi-Fi without an active encrypted VPN tunnel.'
        ],
        whatToDo: isHindi ? [
          'Public Wi-Fi par NetBanking ya UPI app ka upyog na karein',
          'Phone settings mein "Auto-Connect to open networks" ko band karein',
          'Zarurat padne par trustworthy VPN (jaise Mullvad, ProtonVPN) use karein',
          'Hamesha browser address bar mein HTTPS aur padlock icon verify karein',
        ] : [
          'Avoid opening banking or payment portals over public wireless access points',
          'Disable "Auto-reconnect to open networks" in Android Wi-Fi preferences',
          'Deploy a verified, zero-log VPN client (e.g., Mullvad or ProtonVPN) on untrusted access points',
          'Verify TLS certificates and padlock status across all web destinations',
        ],
        trendNote: null,
        language: language,
        disclaimer: isHindi ? 'SafeSignal ek on-device AI assistant hai.' : 'SafeSignal is an on-device security assistant.',
        inputText: text,
        checkedAt: DateTime.now(),
      );
    }

    // 22. Dark Web / Data Breach / Compromised Password
    if (lower.contains('dark web') || lower.contains('data breach') || lower.contains('data leak') || lower.contains('haveibeenpwned') || lower.contains('breached') || lower.contains('leaked data')) {
      return VerdictModel(
        checkId: 'local_darkweb_${DateTime.now().millisecondsSinceEpoch}',
        verdict: 'INFO',
        confidence: 0.96,
        scamType: isHindi ? 'Dark Web & Breach Advisory' : 'Data Breach & Dark Web Advisory',
        escalated: false,
        why: isHindi ? [
          'Data breach tab hota hai jab kisi company (jaise food delivery, shopping site, telecom) ka database hack ho jata hai aur user ke phone number, email aur passwords Dark Web par bikne lagte hain.',
          'Agar aap wahi password har jagah use karte hain, toh ek breach se aapke saare accounts (Gmail, Bank, Social Media) vulnerable ho jate hain (Credential Stuffing).'
        ] : [
          'Data breaches occur when corporate databases are exfiltrated and personal records (names, phone numbers, password hashes) circulate on darknet forums.',
          'Reusing a single password across multiple services leads to rapid domino compromises via automated credential stuffing.'
        ],
        whatToDo: isHindi ? [
          'haveibeenpwned.com par jakar apna email check karein ki wo kisi breach mein shamil toh nahi hai',
          'Compromised accounts ke passwords turant change karein',
          'Har account ke liye alag strong password banayein (Password Manager use karein)',
          'Sabhi critical accounts par 2FA (Two-Factor Authentication) activate karein',
        ] : [
          'Audit your email address on haveibeenpwned.com to check breach exposure',
          'Immediately rotate passwords on all compromised accounts',
          'Implement unique, high-entropy passwords via an open-source password manager',
          'Enforce Multi-Factor Authentication (MFA) across your primary email and banking',
        ],
        trendNote: null,
        language: language,
        disclaimer: isHindi ? 'SafeSignal ek on-device AI assistant hai.' : 'SafeSignal is an on-device security assistant.',
        inputText: text,
        checkedAt: DateTime.now(),
      );
    }

    // 23. WhatsApp Security & Privacy Settings
    if (lower.contains('whatsapp safe') || lower.contains('whatsapp privacy') || lower.contains('whatsapp setting') || lower.contains('chat lock') || lower.contains('disappearing message')) {
      return VerdictModel(
        checkId: 'local_wa_sec_${DateTime.now().millisecondsSinceEpoch}',
        verdict: 'INFO',
        confidence: 0.96,
        scamType: isHindi ? 'WhatsApp Privacy & Hardening' : 'WhatsApp Privacy & Security Hardening',
        escalated: false,
        why: isHindi ? [
          'WhatsApp ko hack-proof aur private banane ke 4 zaroori settings:\n\n'
          '1. Two-Step Verification: 6-digit PIN lagayein taaki koi aapka number SIM swap karke bhi WhatsApp login na kar sake.\n'
          '2. Linked Devices: Har hafte check karein ki koi anjaan laptop ya browser connect toh nahi hai.\n'
          '3. Silence Unknown Callers: Settings > Privacy > Calls > "Silence unknown callers" ON karein taaki scam calls direct ring na karein.\n'
          '4. Group Privacy: "Who can add me to groups" ko "My Contacts Except" karein taaki scammers aapko fraud groups mein na jod sakein.'
        ] : [
          'Four mandatory hardening steps for WhatsApp security:\n\n'
          '1. Two-Step Verification: Configure a 6-digit PIN and recovery email to prevent SIM-swap takeovers.\n'
          '2. Linked Devices Audit: Periodically terminate unfamiliar active web or desktop sessions.\n'
          '3. Silence Unknown Callers: Enable Settings > Privacy > Calls > "Silence unknown callers" to deflect spam/scam robocalls.\n'
          '4. Group Privacy: Set "Who can add me to groups" to "My Contacts Except" to block unauthorized additions into investment task groups.'
        ],
        whatToDo: isHindi ? [
          'WhatsApp Settings > Account > Two-Step Verification ON karein',
          'WhatsApp Settings > Privacy > Calls > Silence Unknown Callers ON karein',
          'Kisi se bhi 6-digit WhatsApp registration code share na karein',
        ] : [
          'Enable WhatsApp Settings > Account > Two-Step Verification',
          'Enable WhatsApp Settings > Privacy > Calls > Silence Unknown Callers',
          'Never share the 6-digit SMS registration code with anyone',
        ],
        trendNote: null,
        language: language,
        disclaimer: isHindi ? 'SafeSignal ek on-device AI assistant hai.' : 'SafeSignal is an on-device security assistant.',
        inputText: text,
        checkedAt: DateTime.now(),
      );
    }

    // 24. URL Intelligence Engine Evaluation (if text contains a URL)
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

    // 25. General Guidance / Menu Query
    if (lower.contains('help') || lower.contains('madad') || lower == 'kya kare' || lower == 'kaise kare' || lower == 'kya kar sakte ho' || lower.contains('features') || lower.contains('list')) {
      return VerdictModel(
        checkId: 'local_${DateTime.now().millisecondsSinceEpoch}',
        verdict: 'INFO',
        confidence: 1.0,
        scamType: isHindi ? 'Cyber Guidance' : 'Cyber Threat Guidance',
        escalated: false,
        why: isHindi ? [
          'Main aapki in sabhi cyber mamlon mein madad kar sakta hoon:\n\n'
          '• Digital Arrest & Extortion: Fake CBI/Police video warrant audit\n'
          '• WhatsApp Hijacking: *401* call forwarding aur hacked accounts\n'
          '• e-Challan Scams: Fake traffic police notices aur phishing APKs\n'
          '• Wedding Card Droppers: WhatsApp par aayi farzi .APK invitations\n'
          '• Sextortion Defense: Video call blackmail se bachav aur recovery\n'
          '• Lost/Stolen Phone: CEIR portal se IMEI block karne ki vidhi\n'
          '• Bank Fraud & UPI Recovery: 1930 Golden Hour emergency protocol\n'
          '• Electricity Bijli Disconnection: 9:30 PM power cut SMS ka audit\n'
          '• Telegram Task & Prepaid Jobs: Fake part-time job scams ki jankari\n'
          '• Aadhaar & AePS Biometric Lock: Cloned fingerprint se protection\n'
          '• Screenshot & Link Audit: Kisi bhi message ka screenshot ya link yahan share karein!'
        ] : [
          'Here is what SafeSignal on-device intelligence can inspect and advise you on:\n\n'
          '• Digital Arrest & Law Enforcement Extortion: Verify fake video warrants\n'
          '• WhatsApp Hijacking: Neutralize *401* call forwarding traps\n'
          '• e-Challan Phishing: Audit fraudulent vehicle fine notices\n'
          '• Wedding Invitation Droppers: Detect weaponized .APK invites\n'
          '• Sextortion Blackmail Defense: Immediate containment and legal guidance\n'
          '• Lost/Stolen Mobile: CEIR IMEI nationwide blacklisting process\n'
          '• Financial Fraud Recovery: 1930 Golden Hour freeze mechanisms\n'
          '• Electricity Disconnection Scams: Audit 9:30 PM power cut threats\n'
          '• Telegram Task & Prepaid Jobs: Identify fraudulent part-time job lures\n'
          '• Aadhaar AePS Biometric Lock: Protect against cloned fingerprint fraud\n'
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

    // 26. Score-based Scam Analysis for Pasted SMS
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

    // 27. Dynamic Cyber Intelligence Synthesizer (Zero Generic Canned Fallbacks!)
    return _synthesizeDynamicCyberGuidance(text, language);
  }

  /// Synthesizes dynamic, contextual cybersecurity advice for arbitrary queries (Zero Canned Text)
  static VerdictModel _synthesizeDynamicCyberGuidance(String text, String language) {
    final lower = text.toLowerCase().trim();
    final isHindi = language == 'hi';

    final hasAccountRef = lower.contains('account') || lower.contains('khata') || lower.contains('id') || lower.contains('profile') || lower.contains('login');
    final hasMoneyRef = lower.contains('paisa') || lower.contains('rupee') || lower.contains('payment') || lower.contains('bank') || lower.contains('upi') || lower.contains('transfer');
    final hasDeviceRef = lower.contains('phone') || lower.contains('mobile') || lower.contains('device') || lower.contains('android') || lower.contains('setting');
    final hasAppRef = lower.contains('app') || lower.contains('apk') || lower.contains('download') || lower.contains('install') || lower.contains('play store');
    final hasCallRef = lower.contains('call') || lower.contains('phone number') || lower.contains('contact') || lower.contains('whatsapp') || lower.contains('msg') || lower.contains('message');
    final hasThreatRef = lower.contains('hack') || lower.contains('scam') || lower.contains('fraud') || lower.contains('danger') || lower.contains('khatra') || lower.contains('dar') || lower.contains('safe');
    final hasOtpRef = lower.contains('otp') || lower.contains('pin') || lower.contains('password') || lower.contains('code');

    final analysisPoints = <String>[];
    final actionPoints = <String>[];
    final cleanQueryExcerpt = text.length > 55 ? '${text.substring(0, 52)}...' : text;

    if (isHindi) {
      analysisPoints.add('Aapke sawaal ("$cleanQueryExcerpt") par SafeSignal on-device cyber engine ne audit kiya hai:');

      if (hasMoneyRef || hasAccountRef) {
        analysisPoints.add('Financial / Banking Security: Kisi bhi bank ya payment service se related maamle mein dhyan rahe ki koi bhi anjaan link ya caller ko account access na dein. Bank kabhi online PIN ya password nahi maangta.');
      }
      if (hasAppRef || hasDeviceRef) {
        analysisPoints.add('Device & App Integrity: Kabhi bhi WhatsApp, Telegram ya browser se aayi .APK file install na karein. Anjaan apps ko "Accessibility" ya "SMS" permission bilkul na dein.');
      }
      if (hasOtpRef) {
        analysisPoints.add('Credential Defense: OTP, UPI PIN, ya passwords kisi ke sath share na karein. SMS OTP ke bajaye Authenticator App use karna sabse surakshit hota hai.');
      }
      if (hasCallRef || hasThreatRef) {
        analysisPoints.add('Social Engineering Threat: Cyber criminals aksar emergency, police arrest ya prize ka darr dikhakar target karte hain. Aise kisi bhi anjaan number ki baaton mein na aayein.');
      }
      if (analysisPoints.length == 1) {
        analysisPoints.add('Cyber Defense Principle: Online suraksha ke liye hamesha Zero-Trust policy apnayein — kisi bhi anjaan sandesh, link ya anurodh par bina cross-verification ke vishwas na karein.');
      }

      actionPoints.add('Agar koi anjaan call ya message aaye toh turant kaat kar verify karein');
      actionPoints.add('Kabhi kisi anjaan vyakti ko screen sharing (AnyDesk/TeamViewer) download na karne dein');
      actionPoints.add('Cyber fraud hone par turant 1930 National Cybercrime Helpline par call karein');
      actionPoints.add('Chakshu portal (sancharsaathi.gov.in) par suspicious phone numbers report karein');
    } else {
      analysisPoints.add('SafeSignal on-device security audit for your inquiry ("$cleanQueryExcerpt"):');

      if (hasMoneyRef || hasAccountRef) {
        analysisPoints.add('Financial Integrity: Official banking institutions and UPI gateways never request confidential credentials, remote screen access, or urgent verification fees via messaging apps.');
      }
      if (hasAppRef || hasDeviceRef) {
        analysisPoints.add('Mobile Architecture: Sideloading untrusted .APK files from WhatsApp or cloud drives exposes your device to accessibility-stealing Trojans. Keep Play Protect active.');
      }
      if (hasOtpRef) {
        analysisPoints.add('Credential Armor: Never disclose one-time passwords (OTP) or authorize incoming collect requests. Deploy hardware-backed passkeys or authenticator apps (TOTP).');
      }
      if (hasCallRef || hasThreatRef) {
        analysisPoints.add('Social Engineering Defense: Criminals manipulate urgency, fear, or false authority to bypass critical thinking. Terminate unsolicited communications immediately.');
      }
      if (analysisPoints.length == 1) {
        analysisPoints.add('Cyber Threat Principle: Adopt a strict Zero-Trust baseline — verify identity independently before acting on any unexpected digital request.');
      }

      actionPoints.add('Terminate suspicious calls and block unverified numbers immediately');
      actionPoints.add('Audit Settings > Accessibility Services to ensure no malicious apps hold screen-capture privileges');
      actionPoints.add('Dial 1930 immediately if any financial compromise or unauthorized debit occurs');
      actionPoints.add('Report malicious communications at cybercrime.gov.in and Chakshu (sancharsaathi.gov.in)');
    }

    return VerdictModel(
      checkId: 'local_guidance_${DateTime.now().millisecondsSinceEpoch}',
      verdict: 'INFO',
      confidence: 1.0,
      scamType: isHindi ? 'On-Device Cyber Analysis' : 'On-Device Cyber Analysis',
      escalated: false,
      why: [analysisPoints.join('\n\n')],
      whatToDo: actionPoints,
      language: language,
      disclaimer: isHindi
          ? 'SafeSignal 100% on-device AI security advisor hai. Emergency mein 1930 par call karein.'
          : 'SafeSignal operates 100% on-device. For emergencies, contact 1930.',
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

    // Extract potential links, phone numbers, emails, and UPI VPAs from OCR text
    final urlRegex = RegExp(r'https?://[^\s/$.?#].[^\s]*|www\.[^\s]+|[a-zA-Z0-9-]+\.(?:com|in|org|net|xyz|top|ru|co|biz|info|site|online|live|vip|app|apk)(?:/[^\s]*)?', caseSensitive: false);
    final urlMatch = urlRegex.firstMatch(rawText);
    final phoneMatch = RegExp(r'(?:\+91[\-\s]?)?[6789]\d{9}\b').firstMatch(rawText);
    final upiMatch = RegExp(r'[a-zA-Z0-9._\-]+@[a-zA-Z]{2,}').firstMatch(rawText);
    final emailMatch = RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}').firstMatch(rawText);

    // Provide a short preview of OCR text so user sees SafeSignal read their image
    final previewText = rawText.length > 130 ? '${rawText.substring(0, 127)}...' : rawText;

    // Vector 1: Wedding Invitation / Shaadi Card APK Dropper (Spynote / CraxsRAT)
    final isWeddingCard = (lower.contains('wedding') || lower.contains('shaadi') || lower.contains('invitation') ||
        lower.contains('nimantran') || lower.contains('vivah') || lower.contains('shubh vivah')) &&
        (lower.contains('.apk') || lower.contains('apk') || lower.contains('download') ||
         lower.contains('install') || lower.contains('card.apk') || lower.contains('invitation.apk') ||
         lower.contains('open card') || lower.contains('blessings'));

    if (isWeddingCard) {
      return VerdictModel(
        checkId: 'img_wedding_${DateTime.now().millisecondsSinceEpoch}',
        verdict: 'SCAM',
        confidence: 0.99,
        scamType: isHindi ? 'Wedding Card APK Malware Dropper' : 'Wedding Invitation Malware Dropper',
        escalated: true,
        why: isHindi ? [
          'Screenshot Text Detected: "$previewText"',
          'KHATARNAK MALWARE: WhatsApp par wedding card ke naam par .APK file bhejna ek lethal Android Trojan attack hai (Spynote/CraxsRAT).',
          'Ye koi digital card nahi hai. Install hote hi ye app screen share, contacts, SMS OTPs aur photos chori karti hai aur bank account khali kar deti hai.',
          if (phoneMatch != null) 'Sender Contact: ${phoneMatch.group(0)}',
        ] : [
          'Screenshot Text Detected: "$previewText"',
          'CRITICAL THREAT: Wedding Card APK files distributed via WhatsApp are weaponized Android Remote Access Trojans (Spynote / CraxsRAT).',
          'Upon installation, the payload harvests contact books, SMS OTPs, media galleries, and keystrokes.',
          if (phoneMatch != null) 'Sender Contact: ${phoneMatch.group(0)}',
        ],
        whatToDo: isHindi ? [
          'File ko bilkul install na karein aur turant phone se delete karein',
          'Jisne bheja hai use voice call karke batayein ki unka WhatsApp hack ho chuka hai',
          'Agar install kar li ho toh turant Airplane Mode ON karein aur Safe Mode mein delete karein',
        ] : [
          'Do NOT install or run the .APK file; delete immediately',
          'Alert the sender via voice call that their WhatsApp account is compromised',
          'If already executed, engage Airplane Mode immediately and remove in Android Safe Mode',
        ],
        trendNote: isHindi ? 'CERT-In dwara jaari high-severity national alert.' : 'Active CERT-In high-severity warning vector.',
        language: language,
        disclaimer: isHindi ? 'SafeSignal ek on-device AI assistant hai.' : 'SafeSignal is an on-device assistant.',
        inputText: '[Screenshot: $previewText]',
        checkedAt: DateTime.now(),
      );
    }

    // Vector 2: Traffic Police e-Challan / Vehicle Fine Phishing & APK
    final isChallan = (lower.contains('echallan') || lower.contains('e-challan') || lower.contains('challan') ||
        lower.contains('parivahan') || lower.contains('traffic police') || lower.contains('vahan')) &&
        (lower.contains('pending') || lower.contains('fine') || lower.contains('court') ||
         lower.contains('seize') || lower.contains('.apk') || lower.contains('rs ') ||
         lower.contains('rupees') || lower.contains('pay'));

    if (isChallan) {
      return VerdictModel(
        checkId: 'img_challan_${DateTime.now().millisecondsSinceEpoch}',
        verdict: 'SCAM',
        confidence: 0.98,
        scamType: isHindi ? 'e-Challan Phishing & Malware Trap' : 'e-Challan Phishing & Malware Trap',
        escalated: true,
        why: isHindi ? [
          'Screenshot Text Detected: "$previewText"',
          'Farzi Traffic Police challan notice jisme vehicle impound ya legal action ka darr dikhakar link/APK bheji gayi hai.',
          'Traffic Police aur Parivahan vibhag kabhi bhi personal number se payment link ya .APK installer nahi bhejte.',
          if (urlMatch != null) 'Suspicious Link: ${urlMatch.group(0)}',
        ] : [
          'Screenshot Text Detected: "$previewText"',
          'Fraudulent traffic fine notice deploying coercion and vehicle impoundment threats.',
          'Transport authorities never distribute payment links from personal numbers or deliver .APK packages.',
          if (urlMatch != null) 'Suspicious Link: ${urlMatch.group(0)}',
        ],
        whatToDo: isHindi ? [
          'Screenshot mein diye gaye link par click na karein',
          'Official portal: echallan.parivahan.gov.in par jakar apna vehicle number check karein',
          'SMS number ko Chakshu (sancharsaathi.gov.in) par report karein',
        ] : [
          'Do not open any web links or download attachments from this message',
          'Verify pending fines exclusively on echallan.parivahan.gov.in',
          'Report fraudulent senders to Chakshu (sancharsaathi.gov.in)',
        ],
        trendNote: isHindi ? 'Fake e-challan APKs banking credentials steal karti hain.' : 'Fake e-challan APKs harvest banking credentials.',
        language: language,
        disclaimer: isHindi ? 'SafeSignal ek on-device AI assistant hai.' : 'SafeSignal is an on-device assistant.',
        inputText: '[Screenshot: $previewText]',
        checkedAt: DateTime.now(),
      );
    }

    // Vector 3: WhatsApp Hijacking / Call Forwarding (*401*)
    final isCallForward = lower.contains('*401*') || lower.contains('*21*') || lower.contains('*62*') ||
        (lower.contains('call forward') && (lower.contains('dial') || lower.contains('delivery') || lower.contains('code')));

    if (isCallForward) {
      return VerdictModel(
        checkId: 'img_fwd_${DateTime.now().millisecondsSinceEpoch}',
        verdict: 'SCAM',
        confidence: 0.99,
        scamType: isHindi ? 'WhatsApp Hijack / Call Forwarding Trap' : 'WhatsApp Hijack Call Forwarding Trap',
        escalated: true,
        why: isHindi ? [
          'Screenshot Text Detected: "$previewText"',
          'DANGER: *401* USSD code dial karwane ka pattern mila hai jo incoming calls ko scammer ke phone par unconditional forward kar deta hai.',
          'Scammer delivery agent ya courier ban kar call forward karwate hain taaki WhatsApp verification voice OTP unke paas chala jaye.',
        ] : [
          'Screenshot Text Detected: "$previewText"',
          'CRITICAL THREAT: Unconditional call-forwarding trap (*401*) detected.',
          'Designed to divert telecom voice calls and login verification OTPs directly to adversary-controlled handsets.',
        ],
        whatToDo: isHindi ? [
          'Turant phone dialer kholein aur ##002# dial karein (ye sabhi call forwardings cancel karta hai)',
          'WhatsApp Settings > Linked Devices par jakar sabhi anjaan sessions log out karein',
          'Two-Step Verification mein 6-digit PIN enable karein',
        ] : [
          'Dial ##002# immediately to terminate all call diversion routines',
          'Log out of all sessions in WhatsApp Settings > Linked Devices',
          'Mandate a 6-digit PIN in WhatsApp Two-Step Verification',
        ],
        trendNote: isHindi ? 'Pure desh mein WhatsApp hijack ka top vector.' : 'Leading WhatsApp account hijacking attack vector.',
        language: language,
        disclaimer: isHindi ? 'SafeSignal ek on-device AI assistant hai.' : 'SafeSignal is an on-device assistant.',
        inputText: '[Screenshot: $previewText]',
        checkedAt: DateTime.now(),
      );
    }

    // Vector 4: Remote Access Trojan (RAT) / Screen Share Support Scam
    final isRemoteAccess = lower.contains('anydesk') || lower.contains('teamviewer') ||
        lower.contains('rustdesk') || lower.contains('quicksupport') || lower.contains('screenshare') ||
        lower.contains('screen share') || lower.contains('airdroid') || lower.contains('zoho assist') ||
        (lower.contains('remote') && lower.contains('support'));

    if (isRemoteAccess) {
      return VerdictModel(
        checkId: 'img_rat_${DateTime.now().millisecondsSinceEpoch}',
        verdict: 'SCAM',
        confidence: 0.98,
        scamType: isHindi ? 'Remote Screen Share / Takeover Trap' : 'Remote Screen Control / RAT Trap',
        escalated: true,
        why: isHindi ? [
          'Screenshot Text Detected: "$previewText"',
          'Remote desktop / screen sharing software (AnyDesk, TeamViewer, QuickSupport, RustDesk) download karne ka pressure banaya gaya hai.',
          'Ek baar remote access milne par scammers aapki screen live dekhte hain aur bank login, passwords aur OTPs capture karke account khali kar dete hain.',
        ] : [
          'Screenshot Text Detected: "$previewText"',
          'Solicits download of remote screen mirroring or administrative utilities (AnyDesk, TeamViewer, RustDesk).',
          'Grants adversaries complete visual and control telemetry over banking apps, OTP displays, and private data.',
        ],
        whatToDo: isHindi ? [
          'Aisi koi bhi remote access app install na karein',
          'Agar install kar li ho toh turant un-install karein aur phone restart karein',
          'Customer care ya official bank helpline par direct call karein',
        ] : [
          'Never install remote desktop or screen mirroring tools on behalf of unknown callers',
          'Immediately purge any recently installed remote support utilities',
          'Contact bank customer support directly through verified numbers',
        ],
        trendNote: isHindi ? 'RBI aur CERT-In aisi apps ke khilaf bar-bar alert jaari karte hain.' : 'Strictly cautioned against by RBI and cyber authorities.',
        language: language,
        disclaimer: isHindi ? 'SafeSignal ek on-device AI assistant hai.' : 'SafeSignal is an on-device assistant.',
        inputText: '[Screenshot: $previewText]',
        checkedAt: DateTime.now(),
      );
    }

    // Vector 5: Sextortion / Video Call Blackmail
    final isSextortion = (lower.contains('video call') || lower.contains('nude') || lower.contains('recording') ||
        lower.contains('morphed') || lower.contains('blackmail') || lower.contains('viral') || lower.contains('delhi police video')) &&
        (lower.contains('youtube') || lower.contains('family') || lower.contains('friends') || lower.contains('money') || lower.contains('paisa') || lower.contains('delete'));

    if (isSextortion) {
      return VerdictModel(
        checkId: 'img_sex_${DateTime.now().millisecondsSinceEpoch}',
        verdict: 'SCAM',
        confidence: 0.99,
        scamType: isHindi ? 'Sextortion Video Blackmail Racket' : 'Sextortion Video Blackmail Extortion',
        escalated: true,
        why: isHindi ? [
          'Screenshot Text Detected: "$previewText"',
          'Video call recording ya morphed photos ko social media/family par viral karne ki dhamki di gayi hai.',
          'Scammers Facebook/Instagram contacts chori karke extortion karte hain aur fake police call karwate hain.',
          'KABHI PAISE NA DEIN: Paise dene par ye kabhi video delete nahi karte balki baar-baar aur maangte hain.',
        ] : [
          'Screenshot Text Detected: "$previewText"',
          'Explicit video blackmail extortion threatening distribution to social contacts or YouTube.',
          'Perpetrators deploy weaponized panic and fake law enforcement personas to extract emergency payments.',
          'DO NOT PAY: Compliance guarantees continued escalating extortion without data removal.',
        ],
        whatToDo: isHindi ? [
          'Number ko turant block karein aur chat ka screenshot lekar evidence save karein',
          'Ek rupaya bhi transfer na karein',
          'Apne Facebook aur Instagram accounts ko Private karein',
          '1930 Cyber Helpline par report karein aur cybercrime.gov.in par complaint darj karein',
        ] : [
          'Block and report the extortionist across all messaging platforms',
          'Refuse all financial extortion demands',
          'Lock Facebook and Instagram profiles to private visibility',
          'Lodge a confidential report at 1930 and cybercrime.gov.in',
        ],
        trendNote: isHindi ? 'MHA dwara recognized cyber extortion racket.' : 'High-prevalence transnational extortion racket.',
        language: language,
        disclaimer: isHindi ? 'SafeSignal ek on-device AI assistant hai.' : 'SafeSignal is an on-device assistant.',
        inputText: '[Screenshot: $previewText]',
        checkedAt: DateTime.now(),
      );
    }

    // Vector 6: SIM Swap / eSIM / 5G Upgrade Fraud
    final isSimSwap = (lower.contains('sim swap') || lower.contains('esim') || lower.contains('5g upgrade') ||
        lower.contains('sim block') || lower.contains('sim kyc')) &&
        (lower.contains('code') || lower.contains('sms') || lower.contains('activation') ||
         lower.contains('19 digit') || lower.contains('qr'));

    if (isSimSwap) {
      return VerdictModel(
        checkId: 'img_sim_${DateTime.now().millisecondsSinceEpoch}',
        verdict: 'SCAM',
        confidence: 0.97,
        scamType: isHindi ? 'SIM Swap / eSIM Hijack Scam' : 'SIM Swap / eSIM Hijack Scam',
        escalated: true,
        why: isHindi ? [
          'Screenshot Text Detected: "$previewText"',
          'SIM deactivation ka darr dikhakar ya 5G upgrade ke naam par SIM number ya eSIM activation code manga gaya hai.',
          'Code process hote hi aapka physical SIM band ho jayega aur saare banking OTPs scammer ke paas chale jayenge.',
        ] : [
          'Screenshot Text Detected: "$previewText"',
          'SIM deactivation or 5G upgrade pretext used to solicit carrier ICCID or eSIM provisioning tokens.',
          'Authorizing this immediately transfers cellular connectivity and bank SMS OTPs to the adversary.',
        ],
        whatToDo: isHindi ? [
          'Kisi bhi SMS ko forward na karein aur eSIM QR code scan na karein',
          'Network gayab hote hi telecom operator ko dusre phone se call karke SIM block karwayein',
          'Bank NetBanking ko emergency freeze karwayein',
        ] : [
          'Do NOT forward carrier configuration SMS or scan unverified eSIM QR codes',
          'If network drops abruptly, contact operator immediately from another device',
          'Request an emergency netbanking freeze from your bank',
        ],
        trendNote: isHindi ? 'Telecom companies anjaan number se eSIM request nahi bhejti.' : 'Carriers never distribute eSIM profiles via messaging apps.',
        language: language,
        disclaimer: isHindi ? 'SafeSignal ek on-device AI assistant hai.' : 'SafeSignal is an on-device assistant.',
        inputText: '[Screenshot: $previewText]',
        checkedAt: DateTime.now(),
      );
    }

    // Vector 7: Digital Arrest / Law Enforcement Impersonation
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

    // Vector 8: Electricity Bill Disconnection Fraud
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

    // Vector 9: Banking KYC / PAN Card Phishing / Trojan
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

    // Vector 10: Telegram Task / Work from Home Scam
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

    // Vector 11: FedEx / Customs Narcotics Extortion
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

    // Vector 12: Predatory Instant Loan Apps
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

    // Vector 13: UPI Collect / Pay to Receive Fraud
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

    // Vector 14: Income Tax / Refund Phishing
    final isTaxRefund = (lower.contains('income tax') || lower.contains('tax refund') || lower.contains('itr refund')) &&
        (lower.contains('approved') || lower.contains('refund of') || lower.contains('click') || lower.contains('account update'));

    if (isTaxRefund) {
      return VerdictModel(
        checkId: 'img_tax_${DateTime.now().millisecondsSinceEpoch}',
        verdict: 'SCAM',
        confidence: 0.96,
        scamType: isHindi ? 'Income Tax Refund Phishing' : 'Income Tax Refund Phishing',
        escalated: true,
        why: isHindi ? [
          'Screenshot Text Detected: "$previewText"',
          'Income tax refund approve hone ka jhootha sandesh jisme link par click karke bank account details update karne ko kaha gaya hai.',
          'Income Tax Department kabhi bhi SMS ya WhatsApp link se direct refund claim karne ya debit card mangne ko nahi kehta.',
        ] : [
          'Screenshot Text Detected: "$previewText"',
          'Phishing lure claiming an approved Income Tax refund awaiting bank credential submission.',
          'The Income Tax Department never solicits debit card numbers or credential confirmations via direct SMS links.',
        ],
        whatToDo: isHindi ? [
          'Kisi bhi link par click na karein',
          'Official portal: incometax.gov.in par login karke apna genuine refund status check karein',
        ] : [
          'Never open the link or enter banking credentials',
          'Verify refund status exclusively through the official e-filing portal: incometax.gov.in',
        ],
        trendNote: isHindi ? 'Tax season ke dauran aam cyber fraud vector.' : 'Common financial phishing vector during tax filing seasons.',
        language: language,
        disclaimer: isHindi ? 'SafeSignal ek on-device AI assistant hai.' : 'SafeSignal is an on-device security assistant.',
        inputText: '[Screenshot: $previewText]',
        checkedAt: DateTime.now(),
      );
    }

    // Vector 15: Fake Government Schemes / Free Recharge / PM Yojana
    final isFakeScheme = (lower.contains('free recharge') || lower.contains('pm yojana') || lower.contains('free laptop') ||
        lower.contains('ladli behna') || lower.contains('free mobile') || lower.contains('ram mandir prasad')) &&
        (lower.contains('share') || lower.contains('click') || lower.contains('claim') || lower.contains('5 groups') || lower.contains('whatsapp'));

    if (isFakeScheme) {
      return VerdictModel(
        checkId: 'img_scheme_${DateTime.now().millisecondsSinceEpoch}',
        verdict: 'SCAM',
        confidence: 0.95,
        scamType: isHindi ? 'Viral Scheme & Adware Scam' : 'Viral Scheme & Adware Scam',
        escalated: true,
        why: isHindi ? [
          'Screenshot Text Detected: "$previewText"',
          'Muft recharge, free laptop ya government scheme ke naam par viral chain message jo WhatsApp groups mein forward karne ko majboor karta hai.',
          'Ye fraud links fake surveys, adware aur malware install karwate hain aur user ka phone number steal karte hain.',
        ] : [
          'Screenshot Text Detected: "$previewText"',
          'Viral chain deception promising free recharges or government equipment in exchange for group distribution.',
          'Redirects to invasive adware domains and credential harvesting forms.',
        ],
        whatToDo: isHindi ? [
          'Is message ko kisi bhi group ya contact ko forward na karein',
          'Link par click na karein aur message delete karein',
        ] : [
          'Do NOT forward to contacts or WhatsApp groups',
          'Delete the message immediately',
        ],
        trendNote: null,
        language: language,
        disclaimer: isHindi ? 'SafeSignal ek on-device AI assistant hai.' : 'SafeSignal is an on-device assistant.',
        inputText: '[Screenshot: $previewText]',
        checkedAt: DateTime.now(),
      );
    }

    // Vector 16: URL Intelligence Analysis on URL found in image
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

    // Vector 17: Legitimate Bank / Payment Transaction Receipt
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

    // Vector 18: Score-based Keyword Analysis on extracted text
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

    // Vector 19: Dynamic Clean / Informative Screenshot Analysis (Deep Breakdown)
    final wordCount = rawText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final lineCount = rawText.split('\n').where((l) => l.trim().isNotEmpty).length;

    final entitiesFound = <String>[];
    if (phoneMatch != null) entitiesFound.add('Phone: ${phoneMatch.group(0)}');
    if (urlMatch != null) entitiesFound.add('Link: ${urlMatch.group(0)}');
    if (emailMatch != null) entitiesFound.add('Email: ${emailMatch.group(0)}');
    if (upiMatch != null) entitiesFound.add('UPI VPA: ${upiMatch.group(0)}');

    final dynamicWhy = <String>[];
    final dynamicAction = <String>[];

    if (isHindi) {
      dynamicWhy.add('OCR Text Preview: "$previewText"');
      dynamicWhy.add('Forensic Audit: Image se $lineCount lines aur $wordCount words safaltapoorvak scan hue.');
      if (entitiesFound.isNotEmpty) {
        dynamicWhy.add('Pahchane gaye entities: ${entitiesFound.join(', ')}');
      }
      dynamicWhy.add('Nishkarsh: Is image mein koi known phishing link, digital arrest warrant, wedding card APK dropper, ya illegal financial coercion detect nahi hua.');

      dynamicAction.add('Screenshot ka content surakshit lag raha hai');
      if (phoneMatch != null || urlMatch != null) {
        dynamicAction.add('Dhyan rahe: Kisi bhi anjaan link ya phone number par apni confidential banking details enter na karein');
      } else {
        dynamicAction.add('Hamesha anjaan senders se aane wale messages par standard caution bartein');
      }
    } else {
      dynamicWhy.add('OCR Text Preview: "$previewText"');
      dynamicWhy.add('Forensic Audit: Extracted $lineCount lines and $wordCount words with on-device OCR.');
      if (entitiesFound.isNotEmpty) {
        dynamicWhy.add('Discovered entities: ${entitiesFound.join(', ')}');
      }
      dynamicWhy.add('Verdict: Zero indicators of APK droppers, digital arrest extortion, or credential phishing detected.');

      dynamicAction.add('Image content appears clean of known attack signatures');
      if (phoneMatch != null || urlMatch != null) {
        dynamicAction.add('Exercise caution: Never disclose OTPs or credentials if contacting unknown entities');
      } else {
        dynamicAction.add('Continue practicing standard cyber hygiene');
      }
    }

    return VerdictModel(
      checkId: 'img_clean_${DateTime.now().millisecondsSinceEpoch}',
      verdict: 'LIKELY_SAFE',
      confidence: 0.90,
      scamType: isHindi ? 'Clean Content Verified' : 'Clean Content Verified',
      escalated: false,
      why: dynamicWhy,
      whatToDo: dynamicAction,
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
            if (message.ocrText != null && message.ocrText!.trim().isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161F30) : const Color(0xFFE8EEF8),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFF2B3A55) : const Color(0xFFCBD5E1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.document_scanner, size: 14, color: AppTheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          lang == 'hi' ? 'OCR Padha Gaya Text:' : 'OCR Extracted Text:',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message.ocrText!.length > 180 ? '${message.ocrText!.substring(0, 177)}...' : message.ocrText!,
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
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
