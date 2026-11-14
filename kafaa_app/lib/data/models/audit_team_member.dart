class AuditTeamMember {
  AuditTeamMember(this.raw);
  final Map<String, dynamic> raw;
  String get id => raw['id'];
  String get auditId => raw['audit_id'];
  String get name => raw['member_name'] ?? '';
  String? get job => raw['actual_job_title'];
  String? get userId => raw['user_id'];
  bool get lead => raw['team_role'] == 'lead';
  int get revision => (raw['row_version'] as num?)?.toInt() ?? 1;
  bool get pending => raw['local_pending'] == true;
}
