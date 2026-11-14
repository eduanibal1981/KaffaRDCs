import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/offline/local_store.dart';
import '../../data/models/primitives.dart';
import '../../data/repositories/assessment_session_repository.dart';

/// The client identity and attempted payload survive route changes and restart.
/// Once creation has been attempted its payload stays pinned until acknowledged.
class CampaignBuilderController {
  CampaignBuilderController(this.store, this.repository);
  final LocalStore store;
  final AssessmentSessionRepository Function() repository;
  Future<void> _write = Future.value();
  Future<Map<String, dynamic>> restore() async {
    await _write.catchError((Object _, StackTrace __) {});
    return await store.readCache<Map<String, dynamic>>('campaign.builder') ??
        {'client_id': const Uuid().v4()};
  }

  Future<void> persist(Map<String, dynamic> values) {
    final copy = Map<String, dynamic>.of(values);
    return _write = _write
        .catchError((Object _, StackTrace __) {})
        .then((_) => store.putCache('campaign.builder', copy));
  }

  Future<String> save(Map<String, dynamic> draft,
      {required bool publish}) async {
    await _write;
    final pinned = Map<String, dynamic>.from(draft['attempt'] as Map? ?? draft);
    final stored = {...draft, 'attempt': pinned};
    await persist(stored);
    final id = await repository().create(
        clientId: pinned['client_id'],
        templateId: pinned['template_id'],
        titleEn: pinned['title_en'],
        titleAr: pinned['title_ar'],
        cycle: pinned['cycle'],
        frequency: PeriodFrequency.tryParse(pinned['frequency']),
        start: DateTime.parse(pinned['start']),
        end: DateTime.parse(pinned['end']),
        dueAt:
            pinned['due_at'] == null ? null : DateTime.parse(pinned['due_at']));
    await persist({...stored, 'saved_id': id});
    if (publish) await repository().publish(id);
    await persist({'client_id': const Uuid().v4()});
    return id;
  }
}

final campaignBuilderProvider = Provider((ref) => CampaignBuilderController(
    ref.watch(localStoreProvider),
    () => ref.read(assessmentSessionRepositoryProvider)));
