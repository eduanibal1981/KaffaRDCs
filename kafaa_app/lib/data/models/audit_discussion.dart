import 'primitives.dart';

class AuditDiscussion {
  AuditDiscussion.fromMap(Map<String, dynamic> m)
      : id = asString(m['id']),
        participationId = asString(m['participation_id']),
        closedAt = asDate(m['closed_at']);
  final String id, participationId;
  final DateTime? closedAt;
}

class AuditMessage {
  AuditMessage.fromMap(Map<String, dynamic> m)
      : id = asString(m['id']),
        discussionId = asString(m['discussion_id']),
        auditId = asStringOrNull(m['audit_id']),
        criterionId = asStringOrNull(m['criterion_id']),
        replyToId = asStringOrNull(m['reply_to_id']),
        authorName = asString(m['author_name']),
        authorRole = asString(m['author_role']),
        kind = asString(m['kind']),
        body = asStringOrNull(m['body']),
        createdAt = asDate(m['created_at']);
  final String id, discussionId, authorName, authorRole, kind;
  final String? auditId, criterionId, replyToId, body;
  final DateTime? createdAt;
}

class AuditConversation {
  AuditConversation(this.discussion, this.messages, this.loadedAt,
      {this.cached = false, this.pending = const []});
  final AuditDiscussion discussion;
  final List<AuditMessage> messages;
  final DateTime loadedAt;
  final bool cached;
  final List<Map<String, dynamic>> pending;
}
