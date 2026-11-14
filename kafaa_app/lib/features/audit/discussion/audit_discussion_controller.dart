import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/offline/sync_service.dart';
import '../../../data/models/audit_discussion.dart';
import '../../../data/repositories/audit_discussion_repository.dart';

final auditDiscussionProvider =
    FutureProvider.autoDispose.family<AuditConversation, String>((ref, id) {
  final timer =
      Timer.periodic(const Duration(seconds: 30), (_) => ref.invalidateSelf());
  ref.onDispose(timer.cancel);
  ref.listen(syncServiceProvider, (old, next) {
    if (old?.pending != next.pending) ref.invalidateSelf();
  });
  return ref.watch(auditDiscussionRepositoryProvider).load(id);
});
final auditMessagesProvider = auditDiscussionProvider;
