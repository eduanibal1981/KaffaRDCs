import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/assessment.dart';
import '../../data/models/audit.dart';
import '../../data/models/primitives.dart';
import '../../data/repositories/assessment_repository.dart';
import '../../data/repositories/audit_repository.dart';

/// Live scoring for one audit. Points are recomputed locally so the total
/// updates the instant an option is tapped, then the server recomputes
/// authoritatively from the chosen scale option — the client can never
/// award itself points the template does not define.
class AuditRunnerState {
  const AuditRunnerState({
    required this.blueprint,
    required this.summary,
    required this.responses,
    this.savingCriterionIds = const {},
  });

  final AssessmentBlueprint blueprint;
  final AuditSummary summary;
  final Map<String, AuditResponse> responses;
  final Set<String> savingCriterionIds;

  Iterable<AssessmentCriterion> get scorable => blueprint.scorable;

  int get totalItems => scorable.length;

  int get answeredItems => scorable
      .where((c) => responses[c.id]?.isAnswered ?? false)
      .length;

  double get progress => totalItems == 0 ? 0 : answeredItems / totalItems;

  double get points => scorable.fold(
        0.0,
        (sum, c) => sum + (responses[c.id]?.points ?? 0),
      );

  /// Not Applicable removes a criterion from the denominator, matching
  /// recalculate_audit() in SQL.
  double get maxPoints => scorable.fold(
        0.0,
        (sum, c) =>
            sum + ((responses[c.id]?.isNotApplicable ?? false) ? 0 : c.maxPoints),
      );

  double get percent => maxPoints == 0 ? 0 : (points / maxPoints) * 100;

  GradingBand? get band {
    for (final b in blueprint.bands) {
      final byPercent = b.minPercent != null || b.maxPercent != null;
      if (byPercent) {
        if (percent >= (b.minPercent ?? -1e9) &&
            percent <= (b.maxPercent ?? 1e9)) {
          return b;
        }
      } else if (points >= (b.minPoints ?? -1e9) &&
          points <= (b.maxPoints ?? 1e9)) {
        return b;
      }
    }
    return null;
  }

  List<AssessmentCriterion> get unscored => scorable
      .where((c) => !(responses[c.id]?.isAnswered ?? false))
      .toList();

  /// Criteria the template marks as needing evidence that still have none.
  List<AssessmentCriterion> get missingEvidence => scorable
      .where((c) =>
          c.evidenceRequired &&
          (responses[c.id]?.isAnswered ?? false) &&
          !(responses[c.id]?.isNotApplicable ?? false) &&
          (responses[c.id]?.evidenceCount ?? 0) == 0)
      .toList();

  int countAtLevel(ScoreLevel level) => scorable
      .where((c) => responses[c.id]?.level == level)
      .length;

  int sectionAnswered(String sectionId) => blueprint
      .criteriaOfSection(sectionId)
      .where((c) => responses[c.id]?.isAnswered ?? false)
      .length;

  double sectionPercent(String sectionId) {
    final criteria = blueprint.criteriaOfSection(sectionId);
    final max = criteria.fold<double>(
        0,
        (sum, c) =>
            sum + ((responses[c.id]?.isNotApplicable ?? false) ? 0 : c.maxPoints));
    if (max == 0) return 0;
    final got = criteria.fold<double>(
        0, (sum, c) => sum + (responses[c.id]?.points ?? 0));
    return (got / max) * 100;
  }

  AuditRunnerState copyWith({
    AuditSummary? summary,
    Map<String, AuditResponse>? responses,
    Set<String>? savingCriterionIds,
  }) =>
      AuditRunnerState(
        blueprint: blueprint,
        summary: summary ?? this.summary,
        responses: responses ?? this.responses,
        savingCriterionIds: savingCriterionIds ?? this.savingCriterionIds,
      );
}

class AuditRunnerController
    extends StateNotifier<AsyncValue<AuditRunnerState>> {
  AuditRunnerController(this._ref, this.auditId)
      : super(const AsyncValue.loading()) {
    load();
  }

  final Ref _ref;
  final String auditId;

  AuditRepository get _audits => _ref.read(auditRepositoryProvider);

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final blueprint =
          await _ref.read(assessmentRepositoryProvider).loadActiveBlueprint();
      final summary = await _audits.summary(auditId);
      if (summary == null) {
        throw StateError('Assessment not found');
      }
      final responses = await _audits.responses(auditId);
      state = AsyncValue.data(AuditRunnerState(
        blueprint: blueprint,
        summary: summary,
        responses: responses,
      ));
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
    }
  }

  AuditRunnerState? get _current => state.valueOrNull;

  /// Records a score. The UI updates immediately; the write goes through
  /// the outbox so it survives a lost connection.
  Future<void> score(AssessmentCriterion criterion, ScaleOption option) async {
    final current = _current;
    if (current == null) return;

    final existing = current.responses[criterion.id];
    final updated = (existing ??
            AuditResponse(
              auditId: auditId,
              criterionId: criterion.id,
              points: 0,
              isNotApplicable: false,
              requiresFollowUp: false,
              ncrSuppressed: false,
            ))
        .copyWith(
      scaleOptionId: option.id,
      level: option.level,
      points: option.points.toDouble().clamp(0, criterion.maxPoints.toDouble()),
      isNotApplicable: false,
    );

    _apply(criterion.id, updated, saving: true);
    await _persist(criterion.id, updated);
  }

  Future<void> setNotApplicable(
      AssessmentCriterion criterion, bool value) async {
    final current = _current;
    if (current == null || !criterion.allowsNotApplicable) return;

    final existing = current.responses[criterion.id];
    final updated = (existing ??
            AuditResponse(
              auditId: auditId,
              criterionId: criterion.id,
              points: 0,
              isNotApplicable: false,
              requiresFollowUp: false,
              ncrSuppressed: false,
            ))
        .copyWith(
      isNotApplicable: value,
      points: 0,
      clearLevel: value,
    );

    _apply(criterion.id, updated, saving: true);
    await _persist(criterion.id, updated);
  }

  Future<void> updateDetails(
    AssessmentCriterion criterion, {
    String? comment,
    String? recommendation,
    EvidenceMethod? method,
    double? measuredValue,
    bool? requiresFollowUp,
    bool? ncrSuppressed,
    String? ncrSuppressionReason,
  }) async {
    final current = _current;
    if (current == null) return;

    final existing = current.responses[criterion.id] ??
        AuditResponse(
          auditId: auditId,
          criterionId: criterion.id,
          points: 0,
          isNotApplicable: false,
          requiresFollowUp: false,
          ncrSuppressed: false,
        );

    final updated = existing.copyWith(
      comment: comment,
      recommendation: recommendation,
      evidenceMethod: method,
      measuredValue: measuredValue,
      requiresFollowUp: requiresFollowUp,
      ncrSuppressed: ncrSuppressed,
      ncrSuppressionReason: ncrSuppressionReason,
    );

    _apply(criterion.id, updated, saving: true);
    await _persist(criterion.id, updated);
  }

  void noteEvidenceAdded(String criterionId) {
    final current = _current;
    if (current == null) return;
    final existing = current.responses[criterionId];
    if (existing == null) return;
    _apply(
      criterionId,
      existing.copyWith(evidenceCount: existing.evidenceCount + 1),
      saving: false,
    );
  }

  void _apply(String criterionId, AuditResponse response,
      {required bool saving}) {
    final current = _current;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(
      responses: {...current.responses, criterionId: response},
      savingCriterionIds: saving
          ? {...current.savingCriterionIds, criterionId}
          : current.savingCriterionIds,
    ));
  }

  Future<void> _persist(String criterionId, AuditResponse response) async {
    try {
      await _audits.saveResponse(response);
    } finally {
      final current = _current;
      if (current != null) {
        state = AsyncValue.data(current.copyWith(
          savingCriterionIds: {...current.savingCriterionIds}
            ..remove(criterionId),
        ));
      }
    }
  }

  Future<void> saveHeader({
    String? generalRecommendations,
    String? suggestedActionPlan,
    int? registeredPatients,
    int? dialysisBeds,
  }) =>
      _audits.updateAudit(auditId, {
        if (generalRecommendations != null)
          'general_recommendations': generalRecommendations,
        if (suggestedActionPlan != null)
          'suggested_action_plan': suggestedActionPlan,
        if (registeredPatients != null) 'registered_patients': registeredPatients,
        if (dialysisBeds != null) 'dialysis_beds': dialysisBeds,
      });

  /// Pushes every queued edit, then flips the status. Flushing first
  /// means the reviewer never sees a half-saved audit.
  Future<void> submit() async {
    await _audits.flushNow();
    await _audits.setStatus(auditId, AuditStatus.submitted);
    await load();
  }
}

final auditRunnerProvider = StateNotifierProvider.family<AuditRunnerController,
    AsyncValue<AuditRunnerState>, String>(
  (ref, auditId) => AuditRunnerController(ref, auditId),
);
