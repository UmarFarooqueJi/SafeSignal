import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/visual_osint_engine.dart';
import '../url_scanner/in_app_browser_screen.dart';

class ImageOsintScreen extends StatefulWidget {
  final String? initialImageUrl;
  const ImageOsintScreen({super.key, this.initialImageUrl});

  @override
  State<ImageOsintScreen> createState() => _ImageOsintScreenState();
}

class _ImageOsintScreenState extends State<ImageOsintScreen> {
  final _picker = ImagePicker();
  final _urlController = TextEditingController();
  final _compareHashController = TextEditingController();

  bool _isAnalyzing = false;
  String _currentStep = '';
  VisualOsintResult? _result;
  String? _selectedImagePath;
  String? _activeImageUrl;
  double? _comparedSimilarity;

  static const _kDarkBg = Color(0xFF06090F);
  static const _kCardBg = Color(0xFF0F172A);
  static const _kCardBorder = Color(0xFF1E293B);
  static const _kCyan = Color(0xFF00E5FF);
  static const _kEmerald = Color(0xFF10B981);
  static const _kRose = Color(0xFFF43F5E);
  static const _kAmber = Color(0xFFF59E0B);
  static const _kPurple = Color(0xFFA855F7);

  @override
  void initState() {
    super.initState();
    if (widget.initialImageUrl != null && widget.initialImageUrl!.isNotEmpty) {
      _urlController.text = widget.initialImageUrl!;
      _analyzeUrl(widget.initialImageUrl!);
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _compareHashController.dispose();
    super.dispose();
  }

  void _setStatus(String step) {
    if (mounted) setState(() => _currentStep = step);
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      HapticFeedback.lightImpact();
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 88,
      );

      if (picked != null) {
        setState(() {
          _selectedImagePath = picked.path;
          _activeImageUrl = null;
          _result = null;
          _comparedSimilarity = null;
        });
        await _analyzeLocalFile(picked.path);
      }
    } catch (e) {
      _showToast('Failed to access camera/gallery: $e');
    }
  }

  Future<void> _analyzeLocalFile(String filePath) async {
    setState(() {
      _isAnalyzing = true;
      _currentStep = 'Computing SHA-256 & 64-bit dHash signatures...';
    });

    try {
      await Future.delayed(const Duration(milliseconds: 150));
      _setStatus('Running on-device OCR & scam entity detection...');
      
      final res = await VisualOsintEngine.analyze(localFilePath: filePath);
      
      if (mounted) {
        setState(() {
          _result = res;
          _isAnalyzing = false;
          _currentStep = '';
        });
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _currentStep = '';
        });
        _showToast('Analysis error: $e');
      }
    }
  }

  Future<void> _analyzeUrl(String url) async {
    final clean = url.trim();
    if (clean.isEmpty || (!clean.startsWith('http://') && !clean.startsWith('https://'))) {
      _showToast('Please enter a valid HTTP/HTTPS image URL');
      return;
    }

    HapticFeedback.lightImpact();
    FocusScope.of(context).unfocus();

    setState(() {
      _isAnalyzing = true;
      _selectedImagePath = null;
      _activeImageUrl = clean;
      _result = null;
      _comparedSimilarity = null;
      _currentStep = 'Fetching remote image bytes securely...';
    });

    try {
      await Future.delayed(const Duration(milliseconds: 200));
      _setStatus('Calculating cryptographic hashes & generating reverse queries...');
      final res = await VisualOsintEngine.analyze(imageUrl: clean);

      if (mounted) {
        setState(() {
          _result = res;
          _isAnalyzing = false;
          _currentStep = '';
        });
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _currentStep = '';
        });
        _showToast('Failed to download & inspect image: $e');
      }
    }
  }

  void _loadSampleScamNotice() {
    const sampleText = '''
CENTRAL BUREAU OF INVESTIGATION (CBI) - CYBER CRIME CELL
NEW DELHI HEADQUARTERS
NOTICE OF DIGITAL ARREST & NON-BAILABLE WARRANT
Case Reference: PMLA/NCB/2026/09428-B
To: Accused Person
You are placed under immediate DIGITAL ARREST under Section 420 IPC and IT Act Section 66D.
Money laundering and illegal narcotics trafficking detected via your Aadhaar linked bank accounts.
Do not disconnect video call verification. Transfer security clearance deposit to verified RBI vault:
Target UPI ID: centralvault.clearance@okhdfcbank
Penalty Amount: ₹98,500
Failure to comply will lead to immediate physical property attachment.
    ''';

    setState(() {
      _selectedImagePath = null;
      _activeImageUrl = null;
      _isAnalyzing = true;
      _currentStep = 'Emulating forensic sample scan...';
    });

    Future.delayed(const Duration(milliseconds: 300), () async {
      final hashes = VisualHashReport(
        sha256: '9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08',
        md5: '5d41402abc4b2a76b9719d911017c592',
        sha1: '2fd4e1c67a2d28fced849ee1bb76e7391b93eb12',
        dHash: 'F8C0E0E0E0C08000',
        fileSizeBytes: 245600,
        width: 1080,
        height: 1920,
        mimeType: 'image/jpeg',
      );

      final ocr = VisualOsintEngine.inspectTextForensics(sampleText);
      final queries = VisualOsintEngine.generateEngineQueries('https://via.placeholder.com/1080x1920.png?text=CBI+Sample');
      final assess = VisualOsintEngine.evaluateThreat(hashes, ocr, 'https://via.placeholder.com/1080x1920.png');

      if (mounted) {
        setState(() {
          _result = VisualOsintResult(
            imageUrl: 'https://via.placeholder.com/1080x1920.png?text=CBI+Sample',
            hashes: hashes,
            ocrEntities: ocr,
            engineQueries: queries,
            assessment: assess,
            inspectedAt: DateTime.now(),
          );
          _isAnalyzing = false;
          _currentStep = '';
        });
      }
    });
  }

  void _openInApp(String url, String title) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InAppBrowserScreen(url: url),
      ),
    );
  }

  Future<void> _openExternal(String url) async {
    HapticFeedback.lightImpact();
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showToast('Could not open URL: $url');
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.selectionClick();
    _showToast('$label copied to clipboard');
  }

  void _exportForensicReport() {
    if (_result == null) return;
    final r = _result!;
    final buffer = StringBuffer();
    buffer.writeln('====================================================');
    buffer.writeln('SAFESIGNAL TITAN VISUAL OSINT & FORENSIC EVIDENCE REPORT');
    buffer.writeln('Generated: ${r.inspectedAt.toIso8601String()}');
    buffer.writeln('====================================================\n');
    buffer.writeln('1. CRYPTOGRAPHIC INTEGRITY');
    buffer.writeln('SHA-256 : ${r.hashes.sha256}');
    buffer.writeln('MD5     : ${r.hashes.md5}');
    buffer.writeln('64-dHash: ${r.hashes.dHash}');
    buffer.writeln('Size    : ${(r.hashes.fileSizeBytes / 1024).toStringAsFixed(1)} KB');
    buffer.writeln('Format  : ${r.hashes.mimeType} (${r.hashes.width ?? "?"}x${r.hashes.height ?? "?"}px)\n');
    buffer.writeln('2. THREAT ASSESSMENT');
    buffer.writeln('Verdict : ${r.assessment.verdictTitle}');
    buffer.writeln('Score   : ${r.assessment.threatScore}/100 (${r.assessment.threatLevel.name.toUpperCase()})');
    buffer.writeln('Category: ${r.assessment.primaryThreatType}\n');
    buffer.writeln('3. DETECTED EXTORTION / FRAUD ENTITIES');
    buffer.writeln('Authorities  : ${r.ocrEntities.detectedInstitutions.join(", ")}');
    buffer.writeln('Scam Triggers: ${r.ocrEntities.detectedScamKeywords.join(", ")}');
    buffer.writeln('Extracted UPI: ${r.ocrEntities.detectedUpiIds.join(", ")}');
    buffer.writeln('Phone Numbers: ${r.ocrEntities.detectedPhoneNumbers.join(", ")}');
    buffer.writeln('Amounts      : ${r.ocrEntities.detectedAmounts.join(", ")}\n');
    buffer.writeln('4. REVERSE ENGINE SOURCES');
    for (final q in r.engineQueries) {
      buffer.writeln('- ${q.engineName}: ${q.queryUrl}');
    }
    buffer.writeln('\n====================================================');
    buffer.writeln('Report this evidence to National Cyber Crime Portal (1930)');

    _copyToClipboard(buffer.toString(), 'Full Forensic Evidence Report');
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 12, color: Colors.white)),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kDarkBg,
      appBar: AppBar(
        backgroundColor: _kDarkBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _kCyan.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.image_search_rounded, color: _kCyan, size: 20),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Visual OSINT Radar',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Reverse Image & Fake ID Recon',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Username OSINT',
            icon: const Icon(Icons.person_search_rounded, color: Colors.white70, size: 22),
            onPressed: () => context.push('/social-osint'),
          ),
          if (_result != null)
            IconButton(
              tooltip: 'Export Evidence',
              icon: const Icon(Icons.share_rounded, color: _kCyan, size: 20),
              onPressed: _exportForensicReport,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSourceSelector(),
            const SizedBox(height: 16),
            if (_isAnalyzing) _buildScanningProgress(),
            if (_result != null && !_isAnalyzing) ...[
              _buildThreatVerdictCard(_result!.assessment),
              const SizedBox(height: 16),
              _buildReverseEnginesCard(_result!),
              const SizedBox(height: 16),
              _buildOcrFindingsCard(_result!.ocrEntities),
              const SizedBox(height: 16),
              _buildHashesCard(_result!.hashes),
              const SizedBox(height: 16),
              _buildHashComparatorCard(_result!.hashes.dHash),
              const SizedBox(height: 32),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSourceSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.camera_enhance_rounded, color: _kCyan, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Ingest Target Image / Screenshot',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              TextButton(
                onPressed: _loadSampleScamNotice,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Try Sample Scam', style: TextStyle(color: _kPurple, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildActionBtn(
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery Photo',
                  color: const Color(0xFF38BDF8),
                  onTap: () => _pickImage(ImageSource.gallery),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildActionBtn(
                  icon: Icons.photo_camera_rounded,
                  label: 'Camera Capture',
                  color: const Color(0xFF34D399),
                  onTap: () => _pickImage(ImageSource.camera),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _urlController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Or paste image URL (https://...)',
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                    filled: true,
                    fillColor: const Color(0xFF06090F),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    prefixIcon: const Icon(Icons.link_rounded, color: Colors.white54, size: 18),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _kCardBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _kCardBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _kCyan),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _analyzeUrl(_urlController.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kCyan,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Inspect', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          ),
          if (_selectedImagePath != null) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  Image.file(
                    File(_selectedImagePath!),
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _selectedImagePath!.split(Platform.pathSeparator).last,
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (_activeImageUrl != null) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  Image.network(
                    _activeImageUrl!,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      height: 100,
                      color: Colors.black26,
                      alignment: Alignment.center,
                      child: const Text('Network image preview unavailable', style: TextStyle(color: Colors.white54, fontSize: 11)),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _activeImageUrl!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanningProgress() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kCyan.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const SizedBox(
            height: 36,
            width: 36,
            child: CircularProgressIndicator(color: _kCyan, strokeWidth: 3),
          ),
          const SizedBox(height: 16),
          const Text(
            'TITAN VISUAL OSINT ENGINE RUNNING',
            style: TextStyle(color: _kCyan, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.8),
          ),
          const SizedBox(height: 6),
          Text(
            _currentStep,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms);
  }

  Widget _buildThreatVerdictCard(VisualThreatAssessment assess) {
    Color badgeColor;
    IconData badgeIcon;
    switch (assess.threatLevel) {
      case VisualThreatLevel.critical:
        badgeColor = _kRose;
        badgeIcon = Icons.dangerous_rounded;
        break;
      case VisualThreatLevel.high:
        badgeColor = _kAmber;
        badgeIcon = Icons.warning_rounded;
        break;
      case VisualThreatLevel.medium:
        badgeColor = const Color(0xFFF97316);
        badgeIcon = Icons.shield_outlined;
        break;
      case VisualThreatLevel.low:
        badgeColor = const Color(0xFF38BDF8);
        badgeIcon = Icons.info_outline_rounded;
        break;
      case VisualThreatLevel.safe:
        badgeColor = _kEmerald;
        badgeIcon = Icons.check_circle_rounded;
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(badgeIcon, color: badgeColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      assess.verdictTitle,
                      style: TextStyle(color: badgeColor, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      assess.primaryThreatType,
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${assess.threatScore}/100',
                  style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 12),
          const Text(
            'FORENSIC FINDINGS',
            style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
          const SizedBox(height: 6),
          ...assess.findings.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: TextStyle(color: badgeColor, fontSize: 14)),
                    Expanded(child: Text(f, style: const TextStyle(color: Colors.white, fontSize: 12))),
                  ],
                ),
              )),
          if (assess.recommendations.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'ACTION DIRECTIVE',
              style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
            const SizedBox(height: 6),
            ...assess.recommendations.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.arrow_right_rounded, color: _kCyan, size: 16),
                      Expanded(child: Text(r, style: const TextStyle(color: Color(0xFFBAE6FD), fontSize: 12))),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildReverseEnginesCard(VisualOsintResult result) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.travel_explore_rounded, color: _kCyan, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Universal Reverse Image Radar',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _kCyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${result.engineQueries.length} ENGINES',
                  style: const TextStyle(color: _kCyan, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Direct queries across global visual search indices to find web appearances, stock photo origin, and social profile matches.',
            style: TextStyle(color: Colors.white54, fontSize: 11),
          ),
          if (result.ephemeralHostedUrl != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF06090F),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _kEmerald.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_clock_rounded, color: _kEmerald, size: 14),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Ephemeral 1-Hour Self-Destruct Relay Active',
                      style: TextStyle(color: _kEmerald, fontSize: 11),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, color: Colors.white70, size: 14),
                    onPressed: () => _copyToClipboard(result.ephemeralHostedUrl!, 'Relay Image URL'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          ...result.engineQueries.map((q) => _buildEngineItem(q)),
        ],
      ),
    );
  }

  Widget _buildEngineItem(ReverseEngineQuery query) {
    Color engineColor;
    IconData engineIcon;
    switch (query.engineKey) {
      case 'google_lens':
        engineColor = const Color(0xFF4285F4);
        engineIcon = Icons.lens_blur_rounded;
        break;
      case 'yandex_images':
        engineColor = const Color(0xFFFF3333);
        engineIcon = Icons.face_retouching_natural_rounded;
        break;
      case 'tineye':
        engineColor = const Color(0xFF00B4D8);
        engineIcon = Icons.history_edu_rounded;
        break;
      case 'bing_visual':
        engineColor = const Color(0xFF008373);
        engineIcon = Icons.window_rounded;
        break;
      case 'baidu_vision':
        engineColor = const Color(0xFF2932E1);
        engineIcon = Icons.public_rounded;
        break;
      default:
        engineColor = _kPurple;
        engineIcon = Icons.image_search_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF06090F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: engineColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(engineIcon, color: engineColor, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          query.engineName,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        if (query.isPrimary) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: engineColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('TOP PICK', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      query.specialization,
                      style: TextStyle(color: engineColor, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            query.description,
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.launch_rounded, size: 13),
                  label: const Text('In-App Browser', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: engineColor,
                    side: BorderSide(color: engineColor.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _openInApp(query.queryUrl, query.engineName),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: _kCardBorder),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _openExternal(query.queryUrl),
                child: const Icon(Icons.open_in_new_rounded, size: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOcrFindingsCard(OcrEntityExtraction ocr) {
    if (ocr.rawText.trim().isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.text_snippet_rounded, color: _kAmber, size: 18),
              const SizedBox(width: 8),
              const Text(
                'On-Device Document Forensics (OCR)',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (ocr.detectedInstitutions.isNotEmpty) ...[
            const Text('DETECTED INSTITUTIONS / LAW ENFORCEMENT', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: ocr.detectedInstitutions.map((inst) => _buildChip(inst, _kRose)).toList(),
            ),
            const SizedBox(height: 10),
          ],
          if (ocr.detectedScamKeywords.isNotEmpty) ...[
            const Text('SCAM / EXTORTION TRIGGERS', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: ocr.detectedScamKeywords.map((kw) => _buildChip(kw, _kAmber)).toList(),
            ),
            const SizedBox(height: 10),
          ],
          if (ocr.detectedUpiIds.isNotEmpty) ...[
            const Text('EXTRACTED PAYMENT HANDLES (UPI)', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: ocr.detectedUpiIds.map((upi) => _buildChip(upi, _kCyan, onCopy: () => _copyToClipboard(upi, 'UPI ID'))).toList(),
            ),
            const SizedBox(height: 10),
          ],
          if (ocr.detectedPhoneNumbers.isNotEmpty) ...[
            const Text('SUSPECT PHONE NUMBERS', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: ocr.detectedPhoneNumbers.map((p) => _buildChip(p, _kEmerald, onCopy: () => _copyToClipboard(p, 'Phone Number'))).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChip(String label, Color color, {VoidCallback? onCopy}) {
    return InkWell(
      onTap: onCopy,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
            if (onCopy != null) ...[
              const SizedBox(width: 4),
              Icon(Icons.copy_rounded, size: 11, color: color),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHashesCard(VisualHashReport hashes) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.fingerprint_rounded, color: _kPurple, size: 18),
              SizedBox(width: 8),
              Text(
                'Cryptographic & Perceptual Signatures',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildHashRow('SHA-256', hashes.sha256),
          _buildHashRow('MD5', hashes.md5),
          _buildHashRow('64-bit dHash', hashes.dHash),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                'Size: ${(hashes.fileSizeBytes / 1024).toStringAsFixed(1)} KB',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
              const SizedBox(width: 16),
              Text(
                'Resolution: ${hashes.width ?? "?"} x ${hashes.height ?? "?"}',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHashRow(String title, String hash) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 85,
            child: Text(title, style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: Text(
              hash,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _kCyan, fontSize: 11, fontFamily: 'monospace'),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 14, color: Colors.white54),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => _copyToClipboard(hash, title),
          ),
        ],
      ),
    );
  }

  Widget _buildHashComparatorCard(String currentDHash) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.compare_rounded, color: _kEmerald, size: 18),
              SizedBox(width: 8),
              Text(
                'Visual Clone & Impersonation Tester',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Paste any reference 64-bit dHash to calculate perceptual Hamming Distance and determine if two images are visual duplicates.',
            style: TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _compareHashController,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    hintText: 'Enter 16-hex dHash (e.g. F8C0E0E0E0C08000)',
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 11),
                    filled: true,
                    fillColor: const Color(0xFF06090F),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kCardBorder)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kCardBorder)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  final target = _compareHashController.text.trim();
                  if (target.isNotEmpty) {
                    setState(() {
                      _comparedSimilarity = VisualOsintEngine.calculateVisualSimilarity(currentDHash, target);
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kEmerald,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Compare', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          if (_comparedSimilarity != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _comparedSimilarity! >= 80 ? _kRose.withValues(alpha: 0.15) : _kEmerald.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _comparedSimilarity! >= 80 ? Icons.copy_rounded : Icons.check_circle_rounded,
                    color: _comparedSimilarity! >= 80 ? _kRose : _kEmerald,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Visual Similarity: ${_comparedSimilarity!.toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: _comparedSimilarity! >= 80 ? _kRose : _kEmerald,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _comparedSimilarity! >= 80 ? 'CLONE DETECTED' : 'DIFFERENT IMAGE',
                    style: TextStyle(
                      color: _comparedSimilarity! >= 80 ? _kRose : _kEmerald,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
