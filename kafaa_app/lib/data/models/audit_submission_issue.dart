class AuditSubmissionIssue {
  AuditSubmissionIssue(this.raw);
  final Map<String, dynamic> raw;
  String get code => raw['code'];
  String? get criterionId => raw['criterion_id'];
  String? get criterionCode => raw['criterion_code'];
}

class AuditPreflight {
  AuditPreflight(this.raw);
  final Map<String, dynamic> raw;
  int get revision => (raw['row_version'] as num).toInt();
  String? get leadUserId => raw['lead_user_id'];
  List<AuditSubmissionIssue> get issues => (raw['issues'] as List)
      .map((r) => AuditSubmissionIssue(Map<String, dynamic>.from(r)))
      .toList();
}
