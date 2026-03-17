import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/daily_diet_log.dart';

class PdfReportService {
  /// Haftalık raporu PDF'e döküp paylaşma arayüzünü açar
  static Future<void> generateAndShareWeeklyReport({
    required String userName,
    required DateTime weekStart,
    required DateTime weekEnd,
    required List<DailyDietLog> dailyLogs,
  }) async {
    final pdf = pw.Document();

    // Google Fonts üzerinden yükle — yerel asset gerekmez
    final fontRegular = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();

    final titleStyle = pw.TextStyle(
      font: fontBold,
      fontSize: 24,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.blue900,
    );

    final normalStyle = pw.TextStyle(
      font: fontRegular,
      fontSize: 12,
      color: PdfColors.black,
    );

    final highlightStyle = pw.TextStyle(
      font: fontBold,
      fontSize: 14,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.green700,
    );

    final dateFormat = DateFormat('dd.MM.yyyy');
    final startStr = dateFormat.format(weekStart);
    final endStr = dateFormat.format(weekEnd);

    double totalCalories = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;
    int loggedDays = 0;

    for (var log in dailyLogs) {
      if (log.totalCalories > 0) loggedDays++;
      totalCalories += log.totalCalories;
      totalProtein += log.totalProtein;
      totalCarbs += log.totalCarbs;
      totalFat += log.totalFat;
    }

    final avgCalories = loggedDays > 0 ? totalCalories / loggedDays : 0.0;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // HEADER
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('FitMentor - Haftalık Rapor', style: titleStyle),
                  pw.Text('$startStr - $endStr', style: normalStyle),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Divider(color: PdfColors.grey400),
              pw.SizedBox(height: 20),

              // USER INFO
              pw.Text(
                'Kullanıcı: $userName',
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),

              // ÖZET KARTLARI
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  border: pw.Border.all(color: PdfColors.blue200),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryStat(fontRegular, fontBold, 'Ort. Kalori', '${avgCalories.toStringAsFixed(0)} kcal', highlightStyle),
                    _buildSummaryStat(fontRegular, fontBold, 'Toplam Protein', '${totalProtein.toStringAsFixed(0)} g', highlightStyle),
                    _buildSummaryStat(fontRegular, fontBold, 'Toplam Karb', '${totalCarbs.toStringAsFixed(0)} g', highlightStyle),
                    _buildSummaryStat(fontRegular, fontBold, 'Toplam Yağ', '${totalFat.toStringAsFixed(0)} g', highlightStyle),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),

              // GÜNLÜK DETAYLAR
              pw.Text(
                'Günlük Detaylar',
                style: pw.TextStyle(font: fontBold, fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),

              _buildLogsTable(fontRegular, fontBold, dailyLogs),

              pw.Spacer(),

              // FOOTER
              pw.Divider(color: PdfColors.grey400),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text(
                  'Bu rapor FitMentor tarafından otomatik oluşturulmuştur.',
                  style: pw.TextStyle(font: fontRegular, fontSize: 10, color: PdfColors.grey600),
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'haftalik_rapor_${weekEnd.millisecondsSinceEpoch}.pdf',
    );
  }

  static pw.Widget _buildSummaryStat(
    pw.Font fontRegular,
    pw.Font fontBold,
    String label,
    String value,
    pw.TextStyle valStyle,
  ) {
    return pw.Column(
      children: [
        pw.Text(label, style: pw.TextStyle(font: fontRegular, fontSize: 10, color: PdfColors.grey700)),
        pw.SizedBox(height: 4),
        pw.Text(value, style: valStyle),
      ],
    );
  }

  static pw.Widget _buildLogsTable(pw.Font fontRegular, pw.Font fontBold, List<DailyDietLog> logs) {
    if (logs.isEmpty) {
      return pw.Text('Bu hafta kayıt bulunmuyor.', style: pw.TextStyle(font: fontRegular, fontSize: 12));
    }

    final dateFormatter = DateFormat('EEE, d MMM', 'tr_TR');

    return pw.TableHelper.fromTextArray(
      headers: ['Tarih', 'Kalori (kcal)', 'Protein (g)', 'Karb (g)', 'Yağ (g)'],
      data: logs.map((log) => [
        dateFormatter.format(log.date),
        log.totalCalories.toStringAsFixed(0),
        log.totalProtein.toStringAsFixed(1),
        log.totalCarbs.toStringAsFixed(1),
        log.totalFat.toStringAsFixed(1),
      ]).toList(),
      headerStyle: pw.TextStyle(font: fontBold, fontWeight: pw.FontWeight.bold, fontSize: 12),
      cellStyle: pw.TextStyle(font: fontRegular, fontSize: 11),
      headerDecoration: pw.BoxDecoration(color: PdfColors.grey200),
      cellPadding: const pw.EdgeInsets.all(6),
      border: pw.TableBorder.all(color: PdfColors.grey300),
    );
  }
}
