import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/llm_orchestrator.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

enum _QrState { scanning, analyzing, result, error }

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );
  
  _QrState _state = _QrState.scanning;
  String _scannedData = '';
  String _analysisResult = '';
  int _riskScore = 0; // 0-100
  String _grade = 'A';
  bool _isTorchOn = false;

  // Structured Dissected Details
  String _dataType = 'Unknown';
  Map<String, String> _dissectedFields = {};
  List<String> _threatAlerts = [];
  bool _isUpiCollectScam = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleScan(BarcodeCapture capture) async {
    if (_state != _QrState.scanning) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
      final code = barcodes.first.rawValue!;
      HapticFeedback.mediumImpact();
      setState(() {
        _scannedData = code;
        _state = _QrState.analyzing;
      });
      _controller.stop();
      await _analyzeData(code);
    }
  }

  Future<void> _pickAndScanGalleryImage() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      setState(() {
        _state = _QrState.analyzing;
      });
      _controller.stop();

      final BarcodeCapture? capture = await _controller.analyzeImage(image.path);
      if (capture != null && capture.barcodes.isNotEmpty && capture.barcodes.first.rawValue != null) {
        final code = capture.barcodes.first.rawValue!;
        HapticFeedback.mediumImpact();
        setState(() {
          _scannedData = code;
        });
        await _analyzeData(code);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('No clear QR code or Barcode found in selected image.'),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
          _resetScanner();
        }
      }
    } catch (e) {
      debugPrint('Gallery scan error: $e');
      if (mounted) {
        _resetScanner();
      }
    }
  }

  Future<void> _analyzeData(String data) async {
    _threatAlerts = [];
    _dissectedFields = {};
    _isUpiCollectScam = false;

    final lower = data.toLowerCase().trim();

    // 1. Offline Deep Dissection: UPI Payment Intent
    if (lower.startsWith('upi://pay')) {
      _dataType = 'UPI Payment Intent';
      final uri = Uri.tryParse(data);
      if (uri != null) {
        final pa = uri.queryParameters['pa'] ?? 'Not specified';
        final pn = uri.queryParameters['pn'] ?? 'Unknown Payee';
        final am = uri.queryParameters['am'];
        final cu = uri.queryParameters['cu'] ?? 'INR';
        final tn = uri.queryParameters['tn'] ?? '';
        final mc = uri.queryParameters['mc'] ?? '';

        _dissectedFields['Payee VPA'] = pa;
        _dissectedFields['Payee Name'] = pn;
        if (am != null && am.isNotEmpty) {
          _dissectedFields['Pre-filled Amount'] = '₹$am $cu';
        }
        if (tn.isNotEmpty) _dissectedFields['Note'] = tn;
        if (mc.isNotEmpty) _dissectedFields['Merchant Code'] = mc;

        if (am != null && double.tryParse(am) != null && double.parse(am) > 0) {
          _isUpiCollectScam = true;
          _riskScore = 85;
          _grade = 'E';
          _threatAlerts.add(
            '🚨 REVERSE PAYMENT FRAUD WARNING: This QR code executes a DEBIT of ₹$am from your account! '
            'Scammers on OLX, WhatsApp, and Facebook send this pretending to "send" money. '
            'In UPI, you NEVER need to scan a QR or enter your PIN to receive funds!',
          );
        } else {
          _riskScore = 20;
          _grade = 'A';
          _threatAlerts.add(
            'ℹ️ Standard UPI QR: Will initiate a payment to $pn ($pa). Confirm payee identity before approving in your bank app.',
          );
        }
      }
    } 
    // 2. Offline Deep Dissection: Web URL
    else if (lower.startsWith('http://') || lower.startsWith('https://')) {
      _dataType = 'Web URL / Link';
      final uri = Uri.tryParse(data);
      if (uri != null) {
        final host = uri.host;
        _dissectedFields['Domain'] = host;
        _dissectedFields['Protocol'] = uri.scheme.toUpperCase();

        if (uri.scheme == 'http') {
          _riskScore += 40;
          _threatAlerts.add('⚠️ INSECURE HTTP: Traffic is unencrypted. Susceptible to interception.');
        }

        if (lower.endsWith('.apk') || lower.contains('.apk?') || lower.contains('/download')) {
          _riskScore = 95;
          _grade = 'E';
          _threatAlerts.add('🚨 MALICIOUS APK DROPPER: Direct Android application package download link. High risk of spyware or banking trojan.');
        }

        final scamTlds = ['.xyz', '.top', '.click', '.tk', '.ml', '.ga', '.cf', '.work', '.rest', '.buzz'];
        if (scamTlds.any((tld) => host.endsWith(tld))) {
          _riskScore += 35;
          _threatAlerts.add('⚠️ SUSPICIOUS TLD: Hosted on cheap, disposable top-level domain frequently utilized in phishing syndicates.');
        }

        final bankKeywords = ['sbi', 'yono', 'hdfc', 'icici', 'pnb', 'paytm', 'kyc', 'pan', 'electricity', 'bill'];
        if (bankKeywords.any((kw) => host.contains(kw)) && !host.endsWith('.com') && !host.endsWith('.co.in') && !host.endsWith('.in')) {
          _riskScore += 45;
          _threatAlerts.add('🚨 BANK TYPOSQUATTING: Impersonates financial or utility services on an unverified domain.');
        }
      }
    }
    // 3. Wi-Fi QR Code
    else if (lower.startsWith('wifi:')) {
      _dataType = 'Wi-Fi Network Configuration';
      _riskScore = 15;
      _grade = 'A';
      _dissectedFields['Type'] = 'Wi-Fi Auto-Connect';
    } 
    // 4. Plain Text
    else {
      _dataType = 'Plain Text / Data';
      _riskScore = 5;
      _grade = 'A';
    }

    _riskScore = _riskScore.clamp(0, 100);
    if (_riskScore >= 70) {
      _grade = 'E';
    } else if (_riskScore >= 35) {
      _grade = 'C';
    } else {
      _grade = 'A';
    }

    // Call LLM for enriched context if network is available
    try {
      final prompt = '''
Analyze this raw data scanned from a QR code: "$data".
Data Type: $_dataType
Give a concise 2-sentence risk summary for an Indian user. Mention specific dangers like UPI collect fraud, fake OLX buyer scams, or phishing if applicable.
''';
      final response = await LlmOrchestrator().analyze(text: prompt, type: 'chat');
      _analysisResult = response.summary.replaceAll(RegExp(r'SCORE:\s*\d+'), '').replaceAll(RegExp(r'GRADE:\s*[ACE]'), '').replaceAll('ANALYSIS:', '').trim();
    } catch (_) {
      _analysisResult = _threatAlerts.isNotEmpty ? _threatAlerts.first : 'Verified QR code structure. Review parsed parameters below.';
    }

    if (mounted) {
      setState(() {
        _state = _QrState.result;
      });
    }
  }

  void _resetScanner() {
    setState(() {
      _state = _QrState.scanning;
      _scannedData = '';
      _analysisResult = '';
      _riskScore = 0;
      _dissectedFields = {};
      _threatAlerts = [];
      _isUpiCollectScam = false;
    });
    _controller.start();
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard!'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF06090F) : const Color(0xFFF1F5F9);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Deep QR & UPI Inspector',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            color: textColor,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_state == _QrState.scanning) ...[
            IconButton(
              icon: Icon(_isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded, color: textColor),
              onPressed: () async {
                await _controller.toggleTorch();
                setState(() => _isTorchOn = !_isTorchOn);
              },
            ),
            IconButton(
              icon: Icon(Icons.flip_camera_android_rounded, color: textColor),
              onPressed: () => _controller.switchCamera(),
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_state == _QrState.scanning)
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    MobileScanner(
                      controller: _controller,
                      onDetect: _handleScan,
                    ),
                    // Reticle
                    Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF2563EB), width: 2.5),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      bottom: 40,
                      left: 20,
                      right: 20,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.center_focus_strong_rounded, color: Colors.white, size: 16),
                                SizedBox(width: 8),
                                Text(
                                  'Align QR inside viewfinder',
                                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          // Gallery Pick Button
                          ElevatedButton.icon(
                            onPressed: _pickAndScanGalleryImage,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF0F172A),
                              elevation: 4,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            ),
                            icon: const Icon(Icons.photo_library_rounded, size: 18, color: Color(0xFF2563EB)),
                            label: const Text(
                              'Scan from Gallery / Screenshot',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            if (_state == _QrState.analyzing)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(color: Color(0xFF2563EB)),
                      const SizedBox(height: 24),
                      Text(
                        'Deconstructing QR payload & UPI intent...',
                        style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w700),
                      ).animate().fade().scale(),
                    ],
                  ),
                ),
              ),

            if (_state == _QrState.error)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 60),
                      const SizedBox(height: 16),
                      Text('Analysis failed.', style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _resetScanner,
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                ),
              ),

            if (_state == _QrState.result)
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Risk Gauge Header Card
                      _buildResultHeaderCard(),
                      const SizedBox(height: 16),

                      // High-Risk UPI Collect Fraud Banner
                      if (_isUpiCollectScam) ...[
                        _buildUpiScamWarningBanner(),
                        const SizedBox(height: 16),
                      ],

                      // Threat Alerts
                      if (_threatAlerts.isNotEmpty && !_isUpiCollectScam) ...[
                        ..._threatAlerts.map((alert) => Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFFCA5A5)),
                              ),
                              child: Text(
                                alert,
                                style: const TextStyle(fontSize: 12.5, color: Color(0xFF991B1B), height: 1.4, fontWeight: FontWeight.w600),
                              ),
                            )),
                        const SizedBox(height: 4),
                      ],

                      // Dissected Parameters Card
                      if (_dissectedFields.isNotEmpty) ...[
                        _buildParametersCard(),
                        const SizedBox(height: 16),
                      ],

                      // Raw Payload
                      _buildRawDataCard(textColor),
                      const SizedBox(height: 20),

                      // Action Buttons
                      _buildActionButtons(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultHeaderCard() {
    final isDanger = _grade == 'E';
    final isWarning = _grade == 'C';
    final themeColor = isDanger ? const Color(0xFFEF4444) : (isWarning ? const Color(0xFFF59E0B) : const Color(0xFF10B981));
    final statusText = isDanger ? 'HIGH THREAT DETECTED' : (isWarning ? 'SUSPICIOUS CAUTION' : 'SAFE STRUCTURE');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: themeColor.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: themeColor.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: themeColor,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '$_riskScore / 100',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: themeColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _dataType,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _analysisResult,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              height: 1.45,
            ),
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildUpiScamWarningBanner() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEF4444), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.dangerous_rounded, color: Color(0xFFDC2626), size: 26),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'DO NOT SCAN OR PAY!',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF991B1B)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            '⚠️ REVERSE PAYMENT FRAUD DETECTED: A scammer is attempting to DEBIT money from your bank account! '
            'Commonly used in OLX sales, Army Officer scams, and fake lottery rewards. '
            'Remember: IN UPI, YOU NEVER ENTER YOUR PIN TO RECEIVE MONEY.',
            style: TextStyle(fontSize: 13, color: Color(0xFF7F1D1D), height: 1.45, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ).animate().shake();
  }

  Widget _buildParametersCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tune_rounded, color: Color(0xFF2563EB), size: 18),
              SizedBox(width: 8),
              Text(
                'DISSECTED INTENT PARAMETERS',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 1.0),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ..._dissectedFields.entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(
                        entry.key,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        entry.value,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildRawDataCard(Color textColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'RAW PAYLOAD',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 1.0),
              ),
              const Spacer(),
              InkWell(
                onTap: () => _copyToClipboard(_scannedData, 'Payload'),
                child: const Row(
                  children: [
                    Icon(Icons.copy_rounded, size: 14, color: Color(0xFF2563EB)),
                    SizedBox(width: 4),
                    Text('Copy', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF2563EB))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _scannedData,
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Color(0xFF334155)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final isUrl = _scannedData.startsWith('http://') || _scannedData.startsWith('https://');

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _resetScanner,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                label: const Text('Scan Another QR', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              ),
            ),
            if (isUrl) ...[
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    context.push('/url-scanner');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.security_rounded, size: 18),
                  label: const Text('Analyze URL', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
