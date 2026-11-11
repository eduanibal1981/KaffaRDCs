/// Shared parsing helpers and the enums that mirror the database types.
library;

double? asDouble(Object? v) => switch (v) {
      null => null,
      num n => n.toDouble(),
      String s => double.tryParse(s),
      _ => null,
    };

double asDoubleOr(Object? v, double fallback) => asDouble(v) ?? fallback;

int? asInt(Object? v) => switch (v) {
      null => null,
      int n => n,
      num n => n.round(),
      String s => int.tryParse(s) ?? double.tryParse(s)?.round(),
      _ => null,
    };

int asIntOr(Object? v, int fallback) => asInt(v) ?? fallback;

bool asBool(Object? v, {bool fallback = false}) => switch (v) {
      null => fallback,
      bool b => b,
      String s => s == 'true' || s == 't' || s == '1',
      num n => n != 0,
      _ => fallback,
    };

DateTime? asDate(Object? v) => switch (v) {
      null => null,
      DateTime d => d,
      String s => DateTime.tryParse(s),
      _ => null,
    };

String asString(Object? v, {String fallback = ''}) =>
    v == null ? fallback : v.toString();

String? asStringOrNull(Object? v) {
  if (v == null) return null;
  final s = v.toString();
  return s.isEmpty ? null : s;
}

List<String> asStringList(Object? v) => switch (v) {
      null => const [],
      List l => l.map((e) => e.toString()).toList(),
      String s when s.startsWith('{') && s.endsWith('}') =>
        s.substring(1, s.length - 1).split(',').where((e) => e.isNotEmpty).toList(),
      _ => const [],
    };

// ---------------------------------------------------------------------------

enum AppRole {
  superAdmin('super_admin'),
  directorate('directorate'),
  auditor('auditor'),
  centerManager('center_manager'),
  viewer('viewer');

  const AppRole(this.wire);
  final String wire;

  static AppRole? tryParse(String? value) {
    for (final r in AppRole.values) {
      if (r.wire == value) return r;
    }
    return null;
  }
}

enum ScoreLevel {
  met('met'),
  partiallyMet('partially_met'),
  notMet('not_met'),
  notApplicable('not_applicable');

  const ScoreLevel(this.wire);
  final String wire;

  static ScoreLevel? tryParse(String? value) {
    for (final l in ScoreLevel.values) {
      if (l.wire == value) return l;
    }
    return null;
  }

  bool get raisesFinding =>
      this == ScoreLevel.partiallyMet || this == ScoreLevel.notMet;
}

enum EvidenceMethod {
  observation('observation'),
  interview('interview'),
  documentReview('document_review'),
  other('other');

  const EvidenceMethod(this.wire);
  final String wire;

  static EvidenceMethod? tryParse(String? value) {
    for (final m in EvidenceMethod.values) {
      if (m.wire == value) return m;
    }
    return null;
  }
}

enum AuditStatus {
  draft('draft'),
  submitted('submitted'),
  underReview('under_review'),
  approved('approved'),
  rejected('rejected'),
  archived('archived');

  const AuditStatus(this.wire);
  final String wire;

  static AuditStatus tryParse(String? value) {
    for (final s in AuditStatus.values) {
      if (s.wire == value) return s;
    }
    return AuditStatus.draft;
  }

  bool get isEditable => this == AuditStatus.draft || this == AuditStatus.rejected;
  bool get isLocked => this == AuditStatus.approved || this == AuditStatus.archived;
}

/// How often an assessment recurs. The period, not the evaluation date, is
/// what results are grouped and filtered by.
enum PeriodFrequency {
  monthly('monthly', 1),
  quarterly('quarterly', 3),
  semiannual('semiannual', 6),
  annual('annual', 12),
  custom('custom', 0);

  const PeriodFrequency(this.wire, this.months);
  final String wire;
  final int months;

  static PeriodFrequency tryParse(String? value) {
    for (final f in PeriodFrequency.values) {
      if (f.wire == value) return f;
    }
    return PeriodFrequency.semiannual;
  }

  /// The period containing [anchor], snapped to this frequency's boundaries.
  /// Mirrors app.set_audit_period() in SQL.
  ({DateTime start, DateTime end}) periodFor(DateTime anchor) {
    final start = switch (this) {
      PeriodFrequency.monthly => DateTime(anchor.year, anchor.month, 1),
      PeriodFrequency.quarterly =>
        DateTime(anchor.year, ((anchor.month - 1) ~/ 3) * 3 + 1, 1),
      PeriodFrequency.semiannual =>
        DateTime(anchor.year, anchor.month <= 6 ? 1 : 7, 1),
      PeriodFrequency.annual => DateTime(anchor.year, 1, 1),
      PeriodFrequency.custom => anchor,
    };
    if (this == PeriodFrequency.custom) {
      return (start: anchor, end: anchor);
    }
    // Day zero of the following month is the last day of this one.
    final end = DateTime(start.year, start.month + months, 0);
    return (start: start, end: end);
  }

  /// The grouping key the database stores: 2026-03, 2026-Q1, 2026-H1, 2026.
  String keyFor(DateTime anchor) {
    final p = periodFor(anchor);
    final year = p.start.year;
    return switch (this) {
      PeriodFrequency.monthly =>
        '$year-${p.start.month.toString().padLeft(2, '0')}',
      PeriodFrequency.quarterly => '$year-Q${((p.start.month - 1) ~/ 3) + 1}',
      PeriodFrequency.semiannual => '$year-H${p.start.month <= 6 ? 1 : 2}',
      PeriodFrequency.annual => '$year',
      PeriodFrequency.custom =>
        '$year-${p.start.month.toString().padLeft(2, '0')}-'
            '${p.start.day.toString().padLeft(2, '0')}',
    };
  }
}

enum NcrStatus {
  open('open'),
  inProgress('in_progress'),
  submittedForReview('submitted_for_review'),
  resolved('resolved'),
  closed('closed'),
  overdue('overdue');

  const NcrStatus(this.wire);
  final String wire;

  static NcrStatus tryParse(String? value) {
    for (final s in NcrStatus.values) {
      if (s.wire == value) return s;
    }
    return NcrStatus.open;
  }

  bool get isOpen =>
      this == NcrStatus.open ||
      this == NcrStatus.inProgress ||
      this == NcrStatus.submittedForReview ||
      this == NcrStatus.overdue;
}

enum RiskLevel {
  low('low'),
  medium('medium'),
  high('high'),
  critical('critical');

  const RiskLevel(this.wire);
  final String wire;

  static RiskLevel tryParse(String? value) {
    for (final r in RiskLevel.values) {
      if (r.wire == value) return r;
    }
    return RiskLevel.medium;
  }
}

enum StaffCategory {
  nurse('nurse'),
  physician('physician'),
  pharmacist('pharmacist'),
  technician('technician'),
  dietitian('dietitian'),
  administrative('administrative'),
  other('other');

  const StaffCategory(this.wire);
  final String wire;

  static StaffCategory tryParse(String? value) {
    for (final c in StaffCategory.values) {
      if (c.wire == value) return c;
    }
    return StaffCategory.other;
  }
}

enum CompetencyState {
  valid('valid'),
  expiringSoon('expiring_soon'),
  expired('expired'),
  missing('missing');

  const CompetencyState(this.wire);
  final String wire;

  static CompetencyState tryParse(String? value) {
    for (final s in CompetencyState.values) {
      if (s.wire == value) return s;
    }
    return CompetencyState.missing;
  }
}

enum SurveyInputType {
  emoji5('emoji_5'),
  stars5('stars_5'),
  slider10('slider_10'),
  yesNo('yes_no'),
  nps10('nps_10'),
  singleChoice('single_choice'),
  freeText('free_text');

  const SurveyInputType(this.wire);
  final String wire;

  static SurveyInputType tryParse(String? value) {
    for (final t in SurveyInputType.values) {
      if (t.wire == value) return t;
    }
    return SurveyInputType.emoji5;
  }
}
