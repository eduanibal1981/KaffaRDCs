import 'audit.dart';
import 'primitives.dart';

/// Separate identity: never pass these IDs to the official response writer.
class SelfAudit {
  SelfAudit(this.row);
  final Map<String, dynamic> row;
  String get id => asString(row['id']);
  String get participationId => asString(row['participation_id']);
  String get assessmentId =>
      asString(row['assessment_id'] ?? row['participation_id']);
  String? get centerId => asStringOrNull(row['center_id']);
  DateTime? get updatedAt => asDate(row['updated_at'] ?? row['created_at']);
  String get templateId => asString(row['template_id']);
  String? get parentId => asStringOrNull(row['parent_self_audit_id']);
  String get status => asString(row['status']);
  int get version => asIntOr(row['version'], 1);
  int get revision => asIntOr(row['row_version'], 1);
  bool get submitted => status == 'submitted';
  DateTime? get submittedAt => asDate(row['submitted_at']);
}

class SelfResponse {
  SelfResponse(this.row);
  final Map<String, dynamic> row;
  String get id => asString(row['id']);
  String get selfAuditId => asString(row['self_audit_id']);
  String get criterionId => asString(row['criterion_id']);
  int get revision => asIntOr(row['row_version'], 0);
  AuditResponse get score =>
      AuditResponse.fromMap({...row, 'audit_id': selfAuditId});
}

class SelfEvidence {
  SelfEvidence(this.row);
  final Map<String, dynamic> row;
  String get id => asString(row['id']);
  String get selfAuditId => asString(row['self_audit_id']);
  String get responseId => asString(row['self_response_id']);
  String get path => asString(row['storage_path']);
  String get fileName => asString(row['file_name']);
  String get mimeType => asString(row['mime_type']);
  bool get finalized => row['upload_state'] == 'finalized';
  bool get removed => row['removed_at'] != null;
  bool get pending => row['local_pending'] == true || !finalized;
}

class SelfAuditContext {
  const SelfAuditContext(this.sessionId, this.centerId,
      {this.snapshotId, this.assessmentId});
  const SelfAuditContext.independent(this.centerId, this.assessmentId,
      {this.snapshotId})
      : sessionId = '';
  final String sessionId;
  final String centerId;
  final String? snapshotId;
  final String? assessmentId;
  @override
  bool operator ==(Object other) =>
      other is SelfAuditContext &&
      sessionId == other.sessionId &&
      centerId == other.centerId &&
      assessmentId == other.assessmentId &&
      snapshotId == other.snapshotId;
  @override
  int get hashCode =>
      Object.hash(sessionId, centerId, assessmentId, snapshotId);

  String get location => Uri(
        path: assessmentId == null
            ? '/assessments/$sessionId/self-audit'
            : '/self-assessments/view/$assessmentId',
        queryParameters: {
          'centerId': centerId,
          if (snapshotId != null) 'snapshotId': snapshotId!,
        },
      ).toString();
}
