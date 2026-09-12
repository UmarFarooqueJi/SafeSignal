import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfReportService {
  static Future<void> generateAndShareReport({
    required Map<String, dynamic> scamData,
    required String originalMessage,
  }) async {
    final pdf = pw.Document();

    final logoData = await rootBundle.load('assets/images/logo.png');
    final logoImage = pw.MemoryImage(logoData.buffer.asUint8List());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Image(logoImage, width: 50, height: 50),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('SafeSignal Cyber Forensic Report',
                        style: pw.TextStyle(
                            fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.red800)),
                    pw.Text('Generated for Cyber Crime Cell (1930)',
                        style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                    pw.Text('Date: ${DateTime.now().toLocal().toString().split('.')[0]}',
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500)),
                  ],
                )
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.SizedBox(height: 20),

            // Summary Section
            pw.Text('INCIDENT SUMMARY',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildRow('Threat Type:', scamData['scamType']?.toString().toUpperCase() ?? 'UNKNOWN'),
                  _buildRow('Risk Level:', scamData['riskLevel']?.toString() ?? 'HIGH'),
                  _buildRow('AI Confidence:', '${((scamData['confidence'] as double? ?? 0.0) * 100).toStringAsFixed(1)}%'),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Original Message
            pw.Text('ORIGINAL SUSPICIOUS CONTENT',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.red50,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                border: pw.Border.all(color: PdfColors.red200),
              ),
              child: pw.Text(
                originalMessage,
                style: const pw.TextStyle(fontSize: 12, color: PdfColors.black),
              ),
            ),
            pw.SizedBox(height: 20),

            // Evidence / Red Flags
            pw.Text('EVIDENCE & RED FLAGS IDENTIFIED',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            ...List.generate(
              (scamData['why'] as List<dynamic>? ?? []).length,
              (index) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('• ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.red800)),
                    pw.Expanded(
                      child: pw.Text(
                        scamData['why'][index].toString(),
                        style: const pw.TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Divider(),
            
            // Footer
            pw.SizedBox(height: 20),
            pw.Center(
              child: pw.Text(
                'This is an AI-generated preliminary forensic analysis by SafeSignal.\nPlease verify with official authorities.',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
              ),
            ),
          ];
        },
      ),
    );

    // Save and print/share
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'SafeSignal_CyberReport_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  static pw.Widget _buildRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        children: [
          pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
          pw.SizedBox(width: 8),
          pw.Text(value, style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey800)),
        ],
      ),
    );
  }
}
