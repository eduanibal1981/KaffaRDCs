import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/l10n/l10n_extensions.dart';
import '../models/analytics.dart';
import '../models/audit.dart';
import '../models/primitives.dart';
import 'analytics_repository.dart';

/// Branded, bilingual PDF and CSV output.
///
/// Arabic needs a font with Arabic glyphs. The service prefers a bundled
/// Cairo TTF (drop it in assets/fonts/), falls back to fetching the same
/// family once and caching it, and finally falls back to the built-in
/// Helvetica for English-only reports. See docs/SETUP.md.
class ReportService {
  ReportService(this._analytics);

  final AnalyticsRepository _analytics;

  pw.Font? _regular;
  pw.Font? _bold;
  bool _fontsResolved = false;

  static const _brandBlue = PdfColor.fromInt(0xFF0F5E9C);
  static const _teal = PdfColor.fromInt(0xFF0EA5A4);
  static const _grey = PdfColor.fromInt(0xFF64748B);
  static const _lightGrey = PdfColor.fromInt(0xFFF1F5F9);

  Future<void> _ensureFonts() async {
    if (_fontsResolved) return;
    _fontsResolved = true;

    try {
      _regular =
          pw.Font.ttf(await rootBundle.load('assets/fonts/Cairo-Regular.ttf'));
      _bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Cairo-Bold.ttf'));
      return;
    } catch (_) {
      // No bundled font — try the network copy.
    }

    try {
      _regular = await PdfGoogleFonts.cairoRegular();
      _bold = await PdfGoogleFonts.cairoBold();
    } catch (_) {
      // Offline and unbundled: English reports still render correctly.
      _regular = null;
      _bold = null;
    }
  }

  pw.ThemeData _theme() => pw.ThemeData.withFont(
        base: _regular,
        bold: _bold ?? _regular,
      );

  bool get canRenderArabic => _regular != null;

  // -------------------------------------------------------------------
  // Audit report
  // -------------------------------------------------------------------

  Future<File> buildAuditPdf({
    required AuditSummary summary,
    required List<ScoreBreakdown> domains,
    required List<CriterionDetail> criteria,
    required String locale,
    bool includeEvidenceList = true,
  }) async {
    await _ensureFonts();
    final arabic = locale == 'ar' && canRenderArabic;
    final dir = arabic ? pw.TextDirection.rtl : pw.TextDirection.ltr;

    String t(String en, String ar) => arabic ? ar : en;
    final centreName = pickForLocale(
        arabic ? 'ar' : 'en', summary.centerNameEn, summary.centerNameAr);

    final doc = pw.Document(
      title: 'Kafaa ${summary.centerCode} ${summary.cycleLabel ?? ''}',
      author: "Kafa'a Initiative",
    );

    final findings = criteria
        .where((c) =>
            c.level == ScoreLevel.partiallyMet || c.level == ScoreLevel.notMet)
        .toList();

    doc.addPage(
      pw.MultiPage(
        theme: _theme(),
        textDirection: dir,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 36, 32, 40),
        header: (context) => context.pageNumber == 1
            ? pw.SizedBox()
            : pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 12),
                child: pw.Text(
                  '${t("Kafa'a Initiative", 'مبادرة كفاءة')} — $centreName',
                  style: const pw.TextStyle(fontSize: 9, color: _grey),
                ),
              ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(top: 12),
          child: pw.Text(
            '${t("Directorate General of Health Services, Muscat Governorate", "المديرية العامة للخدمات الصحية بمحافظة مسقط")}'
            '   ·   ${context.pageNumber} / ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: _grey),
          ),
        ),
        build: (context) => [
          _pdfHeader(t, centreName, summary),
          pw.SizedBox(height: 18),
          _pdfScoreBlock(t, summary, arabic),
          pw.SizedBox(height: 18),
          pw.Text(t('Scores by main area', 'النتائج حسب المجال الرئيسي'),
              style:
                  pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          _pdfDomainTable(t, domains, arabic),
          pw.SizedBox(height: 18),
          if (findings.isNotEmpty) ...[
            pw.Text(
              t('Findings requiring action (${findings.length})',
                  'الملاحظات التي تتطلب إجراءً (${findings.length})'),
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            _pdfFindingsTable(t, findings, arabic),
            pw.SizedBox(height: 18),
          ],
          pw.Text(t('Full checklist', 'قائمة التقييم الكاملة'),
              style:
                  pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          _pdfCriteriaTable(t, criteria, arabic, includeEvidenceList),
        ],
      ),
    );

    final bytes = await doc.save();
    final dirPath = await getTemporaryDirectory();
    final file = File(p.join(
      dirPath.path,
      'kafaa_${summary.centerCode}_${summary.cycleLabel ?? 'report'}_$locale.pdf',
    ));
    await file.writeAsBytes(bytes);
    return file;
  }

  pw.Widget _pdfHeader(
      String Function(String, String) t, String centreName, AuditSummary s) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: const pw.BoxDecoration(color: _lightGrey),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            t("Kafa'a Initiative", 'مبادرة كفاءة'),
            style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: _brandBlue),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            t('Renal Dialysis Centre Evaluation',
                'تقييم أداء مراكز غسيل الكلى'),
            style: const pw.TextStyle(fontSize: 11, color: _grey),
          ),
          pw.SizedBox(height: 12),
          pw.Text(centreName,
              style:
                  pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Row(children: [
            _kv(t('Cycle', 'الدورة'), s.cycleLabel ?? '—'),
            pw.SizedBox(width: 24),
            _kv(t('Evaluation date', 'تاريخ التقييم'),
                s.evaluationDate?.toIso8601String().split('T').first ?? '—'),
            pw.SizedBox(width: 24),
            _kv(t('Evaluator', 'المُقيِّم'), s.leadAuditorName ?? '—'),
          ]),
        ],
      ),
    );
  }

  pw.Widget _kv(String label, String value) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: _grey)),
          pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
        ],
      );

  pw.Widget _pdfScoreBlock(
      String Function(String, String) t, AuditSummary s, bool arabic) {
    final grade =
        pickForLocale(arabic ? 'ar' : 'en', s.gradeNameEn, s.gradeNameAr);
    return pw.Row(
      children: [
        pw.Expanded(
          child: _scoreBox(
            t('Total score', 'النتيجة الإجمالية'),
            '${s.totalPoints.round()} / ${s.maxPoints.round()}',
            _brandBlue,
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          child: _scoreBox(t('Percentage', 'النسبة المئوية'),
              '${s.percent.toStringAsFixed(1)}%', _teal),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          child: _scoreBox(
              t('Rating', 'التقدير'), grade.isEmpty ? '—' : grade, _brandBlue),
        ),
      ],
    );
  }

  pw.Widget _scoreBox(String label, String value, PdfColor color) =>
      pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: color, width: 1),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label,
                style: const pw.TextStyle(fontSize: 8, color: _grey)),
            pw.SizedBox(height: 4),
            pw.Text(value,
                style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: color)),
          ],
        ),
      );

  pw.Widget _pdfDomainTable(String Function(String, String) t,
      List<ScoreBreakdown> domains, bool arabic) {
    return pw.TableHelper.fromTextArray(
      headers: [
        t('Main area', 'المجال الرئيسي'),
        t('Points', 'النقاط'),
        t('Maximum', 'الحد الأقصى'),
        '%',
      ],
      headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: _lightGrey),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignment:
          arabic ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
      columnWidths: {
        0: const pw.FlexColumnWidth(4),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(1),
        3: const pw.FlexColumnWidth(1),
      },
      data: [
        for (final d in domains)
          [
            pickForLocale(arabic ? 'ar' : 'en', d.nameEn, d.nameAr),
            d.points.round().toString(),
            d.maxPoints.round().toString(),
            d.percent == null ? '—' : '${d.percent!.toStringAsFixed(1)}%',
          ],
      ],
    );
  }

  pw.Widget _pdfFindingsTable(String Function(String, String) t,
      List<CriterionDetail> findings, bool arabic) {
    return pw.TableHelper.fromTextArray(
      headers: [
        t('Ref', 'الرمز'),
        t('Criterion', 'المعيار'),
        t('Result', 'النتيجة'),
        t('Comment', 'التعليق'),
      ],
      headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      headerDecoration:
          const pw.BoxDecoration(color: PdfColor.fromInt(0xFFFDF3E1)),
      cellStyle: const pw.TextStyle(fontSize: 8.5),
      cellAlignment:
          arabic ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
      columnWidths: {
        0: const pw.FlexColumnWidth(1),
        1: const pw.FlexColumnWidth(5),
        2: const pw.FlexColumnWidth(1.6),
        3: const pw.FlexColumnWidth(3.4),
      },
      data: [
        for (final f in findings)
          [
            f.criterionCode,
            pickForLocale(arabic ? 'ar' : 'en', f.textEn, f.textAr),
            _levelLabel(t, f.level),
            f.comment ?? '',
          ],
      ],
    );
  }

  pw.Widget _pdfCriteriaTable(String Function(String, String) t,
      List<CriterionDetail> criteria, bool arabic, bool includeEvidence) {
    final grouped = <String, List<CriterionDetail>>{};
    for (final c in criteria) {
      grouped
          .putIfAbsent(
              pickForLocale(
                  arabic ? 'ar' : 'en', c.sectionNameEn, c.sectionNameAr),
              () => [])
          .add(c);
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final entry in grouped.entries) ...[
          pw.SizedBox(height: 10),
          pw.Text(entry.key,
              style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: _brandBlue)),
          pw.SizedBox(height: 4),
          pw.TableHelper.fromTextArray(
            headers: [
              t('Ref', 'الرمز'),
              t('Criterion', 'المعيار'),
              t('Result', 'النتيجة'),
              t('Points', 'النقاط'),
              if (includeEvidence) t('Evidence', 'الأدلة'),
            ],
            headerStyle:
                pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: _lightGrey),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment:
                arabic ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
            columnWidths: {
              0: const pw.FlexColumnWidth(1),
              1: const pw.FlexColumnWidth(6),
              2: const pw.FlexColumnWidth(1.6),
              3: const pw.FlexColumnWidth(1),
              if (includeEvidence) 4: const pw.FlexColumnWidth(1),
            },
            data: [
              for (final c in entry.value)
                [
                  c.criterionCode,
                  pickForLocale(arabic ? 'ar' : 'en', c.textEn, c.textAr),
                  _levelLabel(t, c.level),
                  '${c.points.round()}/${c.maxPoints}',
                  if (includeEvidence) '${c.evidenceCount}',
                ],
            ],
          ),
        ],
      ],
    );
  }

  String _levelLabel(String Function(String, String) t, ScoreLevel? level) =>
      switch (level) {
        ScoreLevel.met => t('Met', 'مستوفى'),
        ScoreLevel.partiallyMet => t('Partially met', 'مستوفى جزئياً'),
        ScoreLevel.notMet => t('Not met', 'غير مستوفى'),
        ScoreLevel.notApplicable => t('Not applicable', 'لا ينطبق'),
        null => '—',
      };

  // -------------------------------------------------------------------
  // Entry points used by the UI
  // -------------------------------------------------------------------

  Future<void> exportAuditPdf(
    BuildContext context,
    AuditSummary summary, {
    String? localeOverride,
    bool includeEvidenceList = true,
  }) async {
    final locale =
        localeOverride ?? Localizations.localeOf(context).languageCode;

    final domains = await _analytics.domainScores(summary.auditId);
    final criteria = await _analytics.criterionDetail(summary.auditId);

    final file = await buildAuditPdf(
      summary: summary,
      domains: domains,
      criteria: criteria,
      locale: locale,
      includeEvidenceList: includeEvidenceList,
    );

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: "Kafa'a report — ${summary.centerNameEn}",
      ),
    );
  }

  Future<void> exportAuditCsv(
      BuildContext context, AuditSummary summary) async {
    final criteria = await _analytics.criterionDetail(summary.auditId);
    final rows = <List<dynamic>>[
      [
        'centre_code',
        'centre_name_en',
        'centre_name_ar',
        'cycle',
        'evaluation_date',
        'domain',
        'section',
        'criterion_code',
        'criterion_en',
        'criterion_ar',
        'result',
        'points',
        'max_points',
        'evidence_count',
        'comment',
        'ncr_code',
      ],
      for (final c in criteria)
        [
          summary.centerCode,
          summary.centerNameEn,
          summary.centerNameAr,
          summary.cycleLabel ?? '',
          summary.evaluationDate?.toIso8601String().split('T').first ?? '',
          c.domainNameEn,
          c.sectionNameEn,
          c.criterionCode,
          c.textEn,
          c.textAr,
          c.level?.wire ?? '',
          c.points,
          c.maxPoints,
          c.evidenceCount,
          c.comment ?? '',
          c.ncrCode ?? '',
        ],
    ];
    await _shareCsv(rows,
        'kafaa_${summary.centerCode}_${summary.cycleLabel ?? 'audit'}.csv');
  }

  Future<void> exportComparisonCsv(
      BuildContext context, List<CenterRanking> ranking) async {
    final rows = <List<dynamic>>[
      [
        'rank',
        'centre_code',
        'centre_name_en',
        'centre_name_ar',
        'cycle',
        'total_points',
        'max_points',
        'percent',
        'grade',
        'satisfaction_percent',
        'satisfaction_responses',
        'open_actions',
        'overdue_actions',
      ],
      for (final r in ranking)
        [
          r.rankOverall,
          r.summary.centerCode,
          r.summary.centerNameEn,
          r.summary.centerNameAr,
          r.summary.cycleLabel ?? '',
          r.summary.totalPoints,
          r.summary.maxPoints,
          r.summary.percent,
          r.summary.gradeNameEn ?? '',
          r.satisfactionPercent ?? '',
          r.satisfactionResponses,
          r.openNcrCount,
          r.overdueNcrCount,
        ],
    ];
    await _shareCsv(rows, 'kafaa_comparison.csv');
  }

  Future<void> _shareCsv(List<List<dynamic>> rows, String fileName) async {
    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, fileName));
    // The BOM makes Excel open the Arabic columns as UTF-8 rather than
    // as the local code page.
    await file.writeAsString('﻿$csv');
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
  }
}

final reportServiceProvider = Provider<ReportService>(
  (ref) => ReportService(ref.watch(analyticsRepositoryProvider)),
);
