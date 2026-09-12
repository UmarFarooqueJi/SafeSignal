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
    state = [...state, ChatMessage(text: text, isUser: true, image: image)];

    // Loading indicator
    final loadingText = language == 'hi' ? 'AI jaanch ho rahi hai... 🔍' : 'AI is analyzing... 🔍';
    state = [
      ...state,
      ChatMessage(text: loadingText, isUser: false, isLoading: true),
    ];

    VerdictModel verdict;

    try {
      verdict = await _analyzeWithAI(text, image, language);
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
      final infoText = verdict.why.isNotEmpty ? verdict.why.join('\n\n') : 'Kuch samajh nahi aaya, kripya dobara likhein.';
      state = [...state, ChatMessage(text: infoText, isUser: false, verdict: null)];
    } else {
      state = [...state, ChatMessage(text: '', isUser: false, verdict: verdict)];
    }
  }

  Future<VerdictModel> _analyzeWithAI(String text, File? image, String language) async {
    final dio = Dio();
    // Use OpenRouter as primary — key is always available
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
      if (AppConstants.openRouterApiKey.isNotEmpty) 'HTTP-Referer': 'https://safesignal.app',
    };
    dio.options.connectTimeout = const Duration(seconds: 25);
    dio.options.receiveTimeout = const Duration(seconds: 25);

    final messages = <Map<String, dynamic>>[];

    final langName = language == 'hi' ? 'Hindi (Devanagari script preferred, or Hinglish is acceptable)' : 'English';

    final systemPrompt = """
You are SafeSignal — an elite cybersecurity expert and digital safety advisor specializing in Indian cyber threats.

You have deep expertise in:
- Detecting Indian cyber frauds: Digital Arrest, OTP scam, KYC fraud, loan app fraud, investment fraud, phishing, SIM swapping, WhatsApp hijacking, UPI fraud
- Android & iOS mobile security, app permissions, privacy settings
- Password security, 2FA, VPN, secure DNS
- Network security, data breaches, dark web monitoring
- Govt cybercrime reporting (1930 helpline, cybercrime.gov.in, CERT-In)
- Text extraction and OCR (Optical Character Recognition) from uploaded images/screenshots.

When analyzing a message or an uploaded image:
1. If the user is just having a normal conversation, asking who you are, or asking a general question about an uploaded image (e.g., "What is written in this image?", "Is this a real bill?"):
   - DO NOT analyze it as a scam report. 
   - Respond with verdict "INFO".
   - Provide a highly detailed, conversational, and helpful reply in the "why" array (as a single item).
   - If an image is provided and they ask to read it, extract the text and explain it clearly.

2. ONLY analyze a message or image as a SCAM or SAFE if the user explicitly shares a suspicious link, message, or asks you to check for fraud/scam.

RESPOND ONLY WITH A VALID JSON OBJECT — no markdown, no code blocks, just raw JSON:
{
  "verdict": "SCAM" or "LIKELY_SAFE" or "UNCERTAIN" or "INFO",
  "confidence": 0.0 to 1.0,
  "scamType": one of ["digital_arrest", "lottery_prize", "job_fraud", "bank_phishing", "otp_theft", "investment_fraud", "fake_news", "malware_link", "impersonation", "romance_scam", "loan_app", "upi_fraud", "sim_swap", "none"],
  "riskLevel": "HIGH" or "MEDIUM" or "LOW",
  "why": [
    "For INFO verdicts, put your full conversational, helpful, and detailed answer here as a single string item in the array.",
    "For SCAM/SAFE, put specific red flags and evidence here."
  ],
  "whatToDo": [
    "Immediate actionable step 1",
    "Step 2"
  ],
  "summary": "2-3 sentence plain language summary of the verdict and main risk (or a summary of your advice for INFO)"
}

IMPORTANT: Write ALL text fields ENTIRELY in $langName. Be specific, educational, and practical.
Mention real Indian fraud tactics, actual reporting channels (1930, cybercrime.gov.in).
If an image is uploaded, scan it for text (OCR), fake logos, official headers, bank seals, QR codes, or suspicious URLs.
""";

    messages.add({'role': 'system', 'content': systemPrompt});

    if (image != null) {
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);
      final mimeType = image.path.endsWith('.png') ? 'image/png' : 'image/jpeg';

      messages.add({
        'role': 'user',
        'content': [
          {
            'type': 'text',
            'text': text.isEmpty || text == '[Screenshot Analysis Request]'
                ? 'Analyze this screenshot for scams, phishing or fraud.'
                : 'Analyze this screenshot. User context: $text'
          },
          {
            'type': 'image_url',
            'image_url': {
              'url': 'data:$mimeType;base64,$base64Image'
            }
          }
        ]
      });
    } else {
      messages.add({
        'role': 'user',
        'content': text
      });
    }

    final payload = {
      'model': model,
      'messages': messages,
      'response_format': {'type': 'json_object'},
    };

    final response = await dio.post(endpoint, data: payload);

    if (response.statusCode == 200) {
      final choices = response.data['choices'] as List;
      if (choices.isNotEmpty) {
        final content = choices[0]['message']['content'] as String;
        String cleanJson = content.trim();
        if (cleanJson.startsWith('```json')) {
          cleanJson = cleanJson.substring(7);
        }
        if (cleanJson.endsWith('```')) {
          cleanJson = cleanJson.substring(0, cleanJson.length - 3);
        }
        cleanJson = cleanJson.trim();

        final Map<String, dynamic> data = jsonDecode(cleanJson);
        final verdictVal = data['verdict'] as String? ?? 'UNCERTAIN';
        final confidenceVal = (data['confidence'] as num?)?.toDouble() ?? 0.6;
        final scamTypeVal = data['scamType'] as String? ?? 'unknown';
        final riskLevel = data['riskLevel'] as String? ?? 'MEDIUM';
        final whyList = List<String>.from(data['why'] ?? []);
        final whatToDoList = List<String>.from(data['whatToDo'] ?? []);
        final summary = data['summary'] as String? ?? '';

        // Prepend summary as first why item if present
        final fullWhy = summary.isNotEmpty ? [summary, ...whyList] : whyList;

        return VerdictModel(
          checkId: 'ai_scan_${DateTime.now().millisecondsSinceEpoch}',
          verdict: verdictVal,
          confidence: confidenceVal,
          scamType: '${scamTypeVal.replaceAll('_', ' ')} | Risk: $riskLevel',
          escalated: true,
          why: fullWhy,
          whatToDo: whatToDoList,
          trendNote: verdictVal == 'SCAM' ? 'SafeSignal AI ne is pattern ko flag kiya hai.' : null,
          language: language,
          disclaimer: language == 'hi'
              ? 'SafeSignal ek AI assistant hai. Zaruri maamlon mein 1930 pe call karein.'
              : 'SafeSignal is an AI assistant. For urgent matters, call 1930.',
          inputText: text,
          checkedAt: DateTime.now(),
        );
      }
    }

    throw Exception('Failed to get valid AI response');
  }

  VerdictModel _analyzeText(String text, String language) {
    final lower = text.toLowerCase();

    // Score-based analysis — extended keyword sets
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

    final isHindi = language == 'hi';

    if (scamScore >= 2) {
      return VerdictModel(
        checkId: 'local_${DateTime.now().millisecondsSinceEpoch}',
        verdict: 'SCAM',
        confidence: 0.88,
        scamType: 'Suspicious Pattern Detected',
        escalated: false,
        why: isHindi ? [
          'Is message mein $scamScore se zyada suspicious keywords mile hain',
          'Fraudsters aisa language use karte hain — dara ke, laalach de ke ya urgency create karke',
          'Real government agencies aur banks kabhi is tarah message nahi karte',
        ] : [
          'This message contains $scamScore+ suspicious keywords',
          'Fraudsters use this language to scare, lure or create urgency',
          'Real government agencies and banks never communicate this way',
        ],
        whatToDo: isHindi ? [
          'Koi bhi link pe click mat karo',
          'Kisi ko bhi OTP, password ya personal details mat do',
          '1930 pe call karke cybercrime report karo',
          'Message delete kar do ya screenshot lekar police ko do',
        ] : [
          'Do not click any link in this message',
          'Never share OTP, password or personal details',
          'Report to cybercrime helpline: 1930',
          'Delete the message or screenshot it and report to police',
        ],
        trendNote: isHindi ? 'Ye pattern common Indian fraud hai' : 'This is a common Indian fraud pattern',
        language: language,
        disclaimer: isHindi ? 'SafeSignal ek AI assistant hai. Zaruri maamlon mein 1930 pe call karein.' : 'SafeSignal is an AI assistant. For urgent matters, call 1930.',
        inputText: text,
        checkedAt: DateTime.now(),
      );
    }
    if (scamScore == 1 && safeScore == 0) return VerdictModel.mockCaution();
    if (safeScore >= 1 || isOtp) return VerdictModel.mockSafe();
    if (lower.contains('http') || lower.contains('www.')) return VerdictModel.mockCaution();
    
    // Normal conversation fallback
    return VerdictModel(
      checkId: 'local_${DateTime.now().millisecondsSinceEpoch}',
      verdict: 'INFO',
      confidence: 1.0,
      scamType: 'none',
      escalated: false,
      why: isHindi ? ['Main SafeSignal AI hoon. Aap koi suspicious message ya link paste karke check karwa sakte hain.'] : ['I am SafeSignal AI. You can paste a suspicious message or link for analysis.'],
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

    return VerdictModel.mockSafe();
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
