import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../domain/repositories/diary_repository.dart';

class PdfService {
  /// Generates a PDF report for a week of nutritional data and shares/prints it.
  static Future<void> generateAndShareWeeklyReport(
    Map<String, DiaryTotals> weeklyData,
    double dailyTarget,
  ) async {
    final pdf = pw.Document();

    // Custom fonts
    final fontRegular = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();

    final sortedKeys = weeklyData.keys.toList()..sort();
    final values = sortedKeys.map((k) => weeklyData[k]!.totalKcal).toList();
    final totalKcal = values.fold(0.0, (a, b) => a + b);
    final avgKcal = values.isNotEmpty ? totalKcal / values.length : 0.0;
    
    final totalProtein = sortedKeys.fold(0.0, (a, k) => a + weeklyData[k]!.totalProtein);
    final totalCarb = sortedKeys.fold(0.0, (a, k) => a + weeklyData[k]!.totalCarb);
    final totalFat = sortedKeys.fold(0.0, (a, k) => a + weeklyData[k]!.totalFat);
    
    final avgProtein = sortedKeys.isNotEmpty ? totalProtein / sortedKeys.length : 0.0;
    final avgCarb = sortedKeys.isNotEmpty ? totalCarb / sortedKeys.length : 0.0;
    final avgFat = sortedKeys.isNotEmpty ? totalFat / sortedKeys.length : 0.0;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Haftalık Beslenme Özeti',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 24,
                          color: PdfColors.blue900,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        '${sortedKeys.first} ile ${sortedKeys.last} arası',
                        style: pw.TextStyle(
                          font: fontRegular,
                          fontSize: 14,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                  pw.Container(
                    width: 50,
                    height: 50,
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.blue100,
                      shape: pw.BoxShape.circle,
                    ),
                    child: pw.Center(
                      child: pw.Text(
                        'PRO',
                        style: pw.TextStyle(
                          font: fontBold,
                          color: PdfColors.blue900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 30),
              
              // Summary Stats Box
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryItem('Ortalama Kalori', '${avgKcal.round()} kcal', fontRegular, fontBold),
                    _buildSummaryItem('Ortalama Protein', '${avgProtein.round()} g', fontRegular, fontBold),
                    _buildSummaryItem('Ortalama Karb', '${avgCarb.round()} g', fontRegular, fontBold),
                    _buildSummaryItem('Ortalama Yağ', '${avgFat.round()} g', fontRegular, fontBold),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 30),
              
              pw.Text(
                'Günlük Detaylar',
                style: pw.TextStyle(font: fontBold, fontSize: 18),
              ),
              pw.SizedBox(height: 12),
              
              // Table
              pw.TableHelper.fromTextArray(
                context: context,
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                headerStyle: pw.TextStyle(font: fontBold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
                cellStyle: pw.TextStyle(font: fontRegular),
                cellAlignment: pw.Alignment.center,
                headers: ['Tarih', 'Kalori (kcal)', 'Protein (g)', 'Karb (g)', 'Yağ (g)', 'Durum'],
                data: List<List<String>>.generate(
                  sortedKeys.length,
                  (index) {
                    final key = sortedKeys[index];
                    final data = weeklyData[key]!;
                    final isOver = data.totalKcal > dailyTarget;
                    
                    return [
                      key,
                      data.totalKcal.round().toString(),
                      data.totalProtein.round().toString(),
                      data.totalCarb.round().toString(),
                      data.totalFat.round().toString(),
                      isOver ? 'Hedef Aşıldı' : 'Hedefte',
                    ];
                  },
                ),
              ),
              
              pw.Spacer(),
              
              // Footer
              pw.Divider(color: PdfColors.grey400),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'FitMentor Tarafından Oluşturuldu',
                    style: pw.TextStyle(font: fontRegular, fontSize: 10, color: PdfColors.grey600),
                  ),
                  pw.Text(
                    'Tarih: ${DateTime.now().toLocal().toString().split(' ')[0]}',
                    style: pw.TextStyle(font: fontRegular, fontSize: 10, color: PdfColors.grey600),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    // Share / Print the document
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'Haftalik_Beslenme_Ozeti.pdf',
    );
  }

  static pw.Widget _buildSummaryItem(String label, String value, pw.Font fontRegular, pw.Font fontBold) {
    return pw.Column(
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(
            font: fontBold,
            fontSize: 16,
            color: PdfColors.blue800,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          label,
          style: pw.TextStyle(
            font: fontRegular,
            fontSize: 10,
            color: PdfColors.grey700,
          ),
        ),
      ],
    );
  }
}
