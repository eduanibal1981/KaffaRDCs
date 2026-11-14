import 'audit.dart';
import 'primitives.dart';

/// Separate identity: never pass these IDs to the official response writer.
class SelfAudit {
  SelfAudit(this.row);
  final Map<String, dynamic> row;
  String get id => asString(row['id']);
  String get participationId => asString(row['participation_id']);
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
  const SelfAuditContext(this.sessionId, this.centerId, {this.snapshotId});
  final String sessionId;
  final String centerId;
  final String? snapshotId;
  @override
  bool operator ==(Object other) =>
      other is SelfAuditContext &&
      sessionId == other.sessionId &&
      centerId == other.centerId &&
      snapshotId == other.snapshotId;
  @override
  int get hashCode => Object.hash(sessionId, centerId, snapshotId);
}
