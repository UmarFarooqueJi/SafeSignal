import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/services/llm_orchestrator.dart';
import '../../core/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

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
      setState(() {
        _scannedData = code;
        _state = _QrState.analyzing;
      });
      _controller.stop();
      await _analyzeData(code);
    }
  }

  Future<void> _analyzeData(String data) async {
    final prompt = '''
    Analyze this raw data scanned from a QR code/Barcode: "$data".
    
    Identify what it is (e.g., Website URL, UPI Payment Link, App Download Link, Plain Text, Contact Card).
    What are the potential security risks? Is it safe? 
    Give a concice, authoritative advanced security analysis.
    Assign a security score (0-100, 100 is most dangerous). 
    Start your response exactly like this format:
    SCORE: [number]
    GRADE: [A/C/E] (A=Safe, C=Caution, E=Dangerous)
    ANALYSIS: [your analysis]
    ''';

    try {
      final response = await LlmOrchestrator().analyze(text: prompt, type: 'chat');
      final text = response.summary;
      
      // Parse response
      int score = 0;
      String grade = 'A';
      String analysis = text;

      try {
        final scoreMatch = RegExp(r'SCORE:\s*(\d+)').firstMatch(text);
        if (scoreMatch != null) score = int.parse(scoreMatch.group(1)!);
        
        final gradeMatch = RegExp(r'GRADE:\s*([ACE])').firstMatch(text);
        if (gradeMatch != null) grade = gradeMatch.group(1)!;

        final analysisParts = text.split('ANALYSIS:');
        if (analysisParts.length > 1) {
          analysis = analysisParts[1].trim();
        }
      } catch (_) {}

      setState(() {
        _riskScore = score;
        _grade = grade;
        _analysisResult = analysis;
        _state = _QrState.result;
      });
    } catch (e) {
      setState(() {
        _state = _QrState.error;
      });
    }
  }

  void _resetScanner() {
    setState(() {
      _state = _QrState.scanning;
      _scannedData = '';
      _analysisResult = '';
      _riskScore = 0;
    });
    _controller.start();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF06090F) : const Color(0xFFEBF3FA);
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: isDark ? Colors.white24 : Colors.black12, width: 1.5),
            ),
            child: IconButton(
              icon: Icon(Icons.grid_view_rounded, color: isDark ? Colors.white54 : Colors.black54, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: Text(
          'Advanced AI Scanner',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: textColor,
            fontFamily: 'serif',
          ),
        ),
        centerTitle: true,
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
                    // Scanner Overlay Target
                    Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.primary, width: 2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    Positioned(
                      bottom: 40,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Text('Point camera at QR/Barcode', style: TextStyle(color: Colors.white)),
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
                      const CircularProgressIndicator(color: AppTheme.primary),
                      const SizedBox(height: 24),
                      Text(
                        'AI is analyzing the scanned data...',
                        style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w600),
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
                      const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 60),
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
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    children: [
                      // Status and Gauge
                      _QrSpeedometerGauge(score: _riskScore.toDouble()),
                      const SizedBox(height: 12),
                      Text(
                        _grade == 'E' ? 'Unsafe' : (_grade == 'C' ? 'Suspicious' : 'Safe'),
                        style: TextStyle(
                          color: _grade == 'E' ? const Color(0xFFFF8A65) : (_grade == 'C' ? const Color(0xFFFFB300) : const Color(0xFF4CAF50)),
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'serif',
                        ),
                      ).animate().fadeIn(),
                      
                      const SizedBox(height: 32),
                      
                      // Data Card
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white24, width: 1.5),
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Scanned Raw Data', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            Text(
                              _scannedData,
                              style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),

                      // Risk Analysis Card
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFFF8A65), width: 1.5),
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF5D1D05),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text('AI Analysis', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                            ),
                            const SizedBox(height: 24),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Security Grade', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 15, fontWeight: FontWeight.bold)),
                                  Text(_grade, style: const TextStyle(color: Color(0xFFFF8A65), fontSize: 15, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Divider(color: Colors.white24, height: 1, thickness: 1),
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 2, child: Text('Synopsis', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 15, fontWeight: FontWeight.bold))),
                                Expanded(flex: 3, child: Text(_analysisResult, style: const TextStyle(color: Color(0xFFFF8A65), fontSize: 13, height: 1.4))),
                              ],
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 200.ms),

                      const SizedBox(height: 24),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _resetScanner,
                              icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                              label: const Text('Scan Another', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E293B),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                            ),
                          ),
                          if (_scannedData.startsWith('http://') || _scannedData.startsWith('https://')) ...[
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  final uri = Uri.parse(_scannedData);
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                                  }
                                },
                                icon: const Icon(Icons.language, color: Colors.white),
                                label: const Text('Open Link', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2979FF),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _QrSpeedometerGauge extends StatelessWidget {
  final double score; 
  const _QrSpeedometerGauge({required this.score});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      height: 140,
      child: CustomPaint(
        painter: _QrSpeedometerPainter(score),
      ),
    );
  }
}

class _QrSpeedometerPainter extends CustomPainter {
  final double score;
  _QrSpeedometerPainter(this.score);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 20);
    final radius = size.width / 2;
    
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 40
      ..strokeCap = StrokeCap.butt;
    
    final rect = Rect.fromCircle(center: center, radius: radius - 20);
    
    paint.color = Colors.greenAccent.shade400;
    canvas.drawArc(rect, 3.14159, 3.14159 / 3, false, paint);
    
    paint.color = Colors.orangeAccent.shade400;
    canvas.drawArc(rect, 3.14159 + (3.14159 / 3), 3.14159 / 3, false, paint);
    
    paint.color = Colors.redAccent.shade400;
    canvas.drawArc(rect, 3.14159 + (2 * 3.14159 / 3), 3.14159 / 3, false, paint);
    
    double clampedScore = score.clamp(0.0, 100.0);
    final angle = 3.14159 + (clampedScore / 100) * 3.14159;
    
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    
    final needlePaint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..style = PaintingStyle.fill;
    
    final path = Path();
    path.moveTo(0, -6);
    path.lineTo(radius - 10, 0);
    path.lineTo(0, 6);
    path.close();
    
    canvas.drawShadow(path, Colors.black, 4, true);
    canvas.drawPath(path, needlePaint);
    
    canvas.drawCircle(const Offset(0, 0), 16, needlePaint);
    final innerCirclePaint = Paint()..color = Colors.grey.shade400;
    canvas.drawCircle(const Offset(0, 0), 10, innerCirclePaint);
    
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _QrSpeedometerPainter oldDelegate) {
    return oldDelegate.score != score;
  }
}
