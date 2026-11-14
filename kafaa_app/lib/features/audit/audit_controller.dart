import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/assessment.dart';
import 'scoring/assessment_score_calculator.dart';
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

  AssessmentScoreCalculator get calculation =>
      AssessmentScoreCalculator(blueprint, responses);
  Iterable<AssessmentCriterion> get scorable => calculation.scorable;
  int get totalItems => calculation.totalItems;
  int get answeredItems => calculation.answeredItems;
  double get progress => calculation.progress;
  double get points => calculation.points;
  double get maxPoints => calculation.maxPoints;
  double get percent => calculation.percent;
  GradingBand? get band => calculation.band;
  List<AssessmentCriterion> get unscored => calculation.unscored;
  List<AssessmentCriterion> get missingEvidence => calculation.missingEvidence;
  int countAtLevel(ScoreLevel level) => calculation.countAtLevel(level);
  int sectionAnswered(String id) => calculation.sectionAnswered(id);
  double sectionPercent(String id) => calculation.sectionPercent(id);

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
      final summary = await _audits.summary(auditId);
      if (summary == null) {
        throw StateError('Assessment not found');
      }
      final blueprint = await _ref
          .read(assessmentRepositoryProvider)
          .loadBlueprint(summary.templateId);
      final responses = await _audits.responses(auditId);
      if (!mounted) return;
      state = AsyncValue.data(AuditRunnerState(
        blueprint: blueprint,
        summary: summary,
        responses: responses,
      ));
    } catch (error, stack) {
      if (mounted) state = AsyncValue.error(error, stack);
    }
  }

  AuditRunnerState? get _current => mounted ? state.valueOrNull : null;

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
      final persisted = await _audits.pendingResponse(auditId, criterionId);
      final current = _current;
      if (persisted != null && current != null) {
        _apply(
            criterionId,
            (current.responses[criterionId] ?? response)
                .copyWith(id: persisted.id, rowVersion: persisted.rowVersion),
            saving: false);
      }
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
        if (registeredPatients != null)
          'registered_patients': registeredPatients,
        if (dialysisBeds != null) 'dialysis_beds': dialysisBeds,
      });

  /// Pushes every queued edit, then flips the status. Flushing first
  /// means the reviewer never sees a half-saved audit.
  Future<void> submit() async {
    if (_current?.savingCriterionIds.isNotEmpty ?? false) {
      throw StateError(
          'Assessment changes are still being saved. Please retry.');
    }
    final repository = _audits;
    await repository.flushNow(auditId: auditId);
    if (!mounted) return;
    throw StateError('KAFAA_SIGNOFF_REQUIRED_CLIENT_UPDATE');
  }
}

final auditRunnerProvider = StateNotifierProvider.family<AuditRunnerController,
    AsyncValue<AuditRunnerState>, String>(
  (ref, auditId) => AuditRunnerController(ref, auditId),
);
