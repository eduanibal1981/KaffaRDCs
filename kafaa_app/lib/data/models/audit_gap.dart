import 'audit.dart';
import 'self_audit.dart';
import 'assessment.dart';
import '../../features/audit/scoring/assessment_score_calculator.dart';

class AuditGapRow {
  const AuditGapRow(this.criterion, this.self, this.official,
      {this.proofReviews = const []});
  final List<Map<String, dynamic>> proofReviews;
  final AssessmentCriterion criterion;
  final AuditResponse? self;
  final AuditResponse? official;
  bool get applicabilityDiffers =>
      self?.isAnswered == true &&
      official?.isAnswered == true &&
      self!.isNotApplicable != official!.isNotApplicable;
  double? get delta => self?.isAnswered != true ||
          official?.isAnswered != true ||
          applicabilityDiffers ||
          self!.isNotApplicable
      ? null
      : official!.points - self!.points;
  bool get differs =>
      applicabilityDiffers ||
      self?.isAnswered != true ||
      official?.isAnswered != true ||
      delta != null && delta != 0;
}

class AuditGap {
  const AuditGap(
      {required this.officialId,
      this.officialVersion = 1,
      required this.provisional,
      required this.self,
      required this.blueprint,
      required this.rows,
      required this.officialScores,
      required this.selfScores});
  final String officialId;
  final int officialVersion;
  final bool provisional;
  final SelfAudit? self;
  final AssessmentBlueprint blueprint;
  final List<AuditGapRow> rows;
  final AssessmentScoreCalculator officialScores;
  final AssessmentScoreCalculator selfScores;
}
