import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/offline/local_store.dart';
import '../models/assessment.dart';
import '../models/operations.dart';
import '../supabase/supabase_providers.dart';

/// Loads the active checklist and keeps a copy on the device so an
/// auditor can start work in a basement with no signal.
class AssessmentRepository {
  AssessmentRepository(this._client, this._store);

  final SupabaseClient _client;
  final LocalStore _store;

  static const _cacheKey = 'blueprint.active';

  Future<AssessmentBlueprint> loadActiveBlueprint({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _readCached();
      if (cached != null) {
        // Refresh in the background so the next open is current.
        unawaitedRefresh();
        return cached;
      }
    }
    return _fetchAndCache();
  }

  void unawaitedRefresh() {
    _fetchAndCache().ignore();
  }

  Future<AssessmentBlueprint?> _readCached() async {
    final raw = await _store.readCache<Map<String, dynamic>>(_cacheKey);
    if (raw == null) return null;
    try {
      return _decode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<AssessmentBlueprint> _fetchAndCache() async {
    final templateRow = await _client
        .from('assessment_templates')
        .select()
        .eq('status', 'active')
        .eq('is_default', true)
        .maybeSingle();

    if (templateRow == null) {
      throw StateError('No active assessment template has been published.');
    }

    final templateId = templateRow['id'] as String;

    final results = await Future.wait([
      _client
          .from('assessment_domains')
          .select()
          .eq('template_id', templateId)
          .order('sort_order'),
      _client
          .from('assessment_sections')
          .select()
          .eq('template_id', templateId)
          .order('sort_order'),
      _client
          .from('assessment_criteria')
          .select()
          .eq('template_id', templateId)
          .order('sort_order'),
      _client
          .from('v_criterion_scale')
          .select()
          .eq('template_id', templateId)
          .order('sort_order'),
      _client
          .from('grading_bands')
          .select()
          .eq('template_id', templateId)
          .order('sort_order'),
    ]);

    final raw = <String, dynamic>{
      'template': templateRow,
      'domains': results[0],
      'sections': results[1],
      'criteria': results[2],
      'scale': results[3],
      'bands': results[4],
    };

    await _store.putCache(_cacheKey, raw);
    return _decode(raw);
  }

  AssessmentBlueprint _decode(Map<String, dynamic> raw) {
    final scaleRows = (raw['scale'] as List).cast<Map<String, dynamic>>();
    final byCriterion = <String, List<ScaleOption>>{};
    for (final row in scaleRows) {
      final criterionId = row['criterion_id'] as String;
      byCriterion.putIfAbsent(criterionId, () => []).add(ScaleOption.fromMap(row));
    }
    for (final list in byCriterion.values) {
      list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }

    final criteria = (raw['criteria'] as List)
        .cast<Map<String, dynamic>>()
        .map(AssessmentCriterion.fromMap)
        .map((c) => c.withOptions(byCriterion[c.id] ?? const []))
        .toList();

    return AssessmentBlueprint(
      template:
          AssessmentTemplate.fromMap(raw['template'] as Map<String, dynamic>),
      domains: (raw['domains'] as List)
          .cast<Map<String, dynamic>>()
          .map(AssessmentDomain.fromMap)
          .toList(),
      sections: (raw['sections'] as List)
          .cast<Map<String, dynamic>>()
          .map(AssessmentSection.fromMap)
          .toList(),
      criteria: criteria,
      bands: (raw['bands'] as List)
          .cast<Map<String, dynamic>>()
          .map(GradingBand.fromMap)
          .toList(),
    );
  }

  // -------------------------------------------------------------------
  // Terminology dictionary
  // -------------------------------------------------------------------

  Future<List<TerminologyEntry>> loadTerminology() async {
    final rows = await _client
        .from('terminology_map')
        .select()
        .eq('is_active', true)
        .order('clinical_term_en');
    return rows.map(TerminologyEntry.fromMap).toList();
  }

  Future<void> upsertTerminology(Map<String, dynamic> values) =>
      _client.from('terminology_map').upsert(values);

  Future<void> deleteTerminology(String id) =>
      _client.from('terminology_map').delete().eq('id', id);

  // -------------------------------------------------------------------
  // Template configuration (super admin)
  // -------------------------------------------------------------------

  Future<void> upsertCriterion(Map<String, dynamic> values) async {
    await _client.from('assessment_criteria').upsert(values);
    await _fetchAndCache();
  }

  Future<void> archiveCriterion(String id) async {
    await _client
        .from('assessment_criteria')
        .update({'is_active': false}).eq('id', id);
    await _fetchAndCache();
  }

  Future<void> setCriterionActive(String id, bool active) async {
    await _client
        .from('assessment_criteria')
        .update({'is_active': active}).eq('id', id);
    await _fetchAndCache();
  }

  // -------------------------------------------------------------------
  // Structure: main areas (domains) and sections
  // -------------------------------------------------------------------

  Future<void> upsertDomain(Map<String, dynamic> values) async {
    await _client.from('assessment_domains').upsert(values);
    await _fetchAndCache();
  }

  Future<void> setDomainActive(String id, bool active) async {
    await _client
        .from('assessment_domains')
        .update({'is_active': active}).eq('id', id);
    await _fetchAndCache();
  }

  Future<void> upsertSection(Map<String, dynamic> values) async {
    await _client.from('assessment_sections').upsert(values);
    await _fetchAndCache();
  }

  Future<void> setSectionActive(String id, bool active) async {
    await _client
        .from('assessment_sections')
        .update({'is_active': active}).eq('id', id);
    await _fetchAndCache();
  }

  /// Moves a section to a different main area. Criteria come with it, so
  /// the totals and charts regroup on the next refresh.
  Future<void> moveSectionToDomain(String sectionId, String? domainId) async {
    await _client
        .from('assessment_sections')
        .update({'domain_id': domainId}).eq('id', sectionId);
    await _fetchAndCache();
  }

  // -------------------------------------------------------------------
  // Reordering
  // -------------------------------------------------------------------

  Future<void> _reorder(
    _StructureLevel level,
    List<({String id, int sortOrder})> order,
  ) async {
    for (final item in order) {
      await _client
          .from(level.table)
          .update({'sort_order': item.sortOrder}).eq('id', item.id);
    }
    await _fetchAndCache();
  }

  Future<void> reorderDomains(List<({String id, int sortOrder})> order) =>
      _reorder(_StructureLevel.domain, order);

  Future<void> reorderSections(List<({String id, int sortOrder})> order) =>
      _reorder(_StructureLevel.section, order);

  Future<void> reorderCriteria(List<({String id, int sortOrder})> order) =>
      _reorder(_StructureLevel.criterion, order);

  // -------------------------------------------------------------------
  // Scoring scale
  // -------------------------------------------------------------------

  /// Writes a criterion's own Met / Partially Met / Not Met choices,
  /// replacing whatever was there. Once a criterion has its own options
  /// it stops inheriting the template default, so this is also what
  /// "customise thresholds" does for a newly added point.
  ///
  /// `max_points` is kept in step with the highest choice, because that is
  /// what the totals and the percentage denominator are built from.
  Future<void> saveCriterionScale({
    required String criterionId,
    required String templateId,
    required List<Map<String, dynamic>> options,
  }) async {
    await _client
        .from('assessment_scale_options')
        .delete()
        .eq('criterion_id', criterionId);

    if (options.isNotEmpty) {
      await _client.from('assessment_scale_options').insert([
        for (final o in options)
          {...o, 'criterion_id': criterionId, 'template_id': templateId},
      ]);

      final highest = options
          .map((o) => (o['points'] as num?)?.toInt() ?? 0)
          .fold<int>(0, (a, b) => a > b ? a : b);
      if (highest > 0) {
        await _client
            .from('assessment_criteria')
            .update({'max_points': highest}).eq('id', criterionId);
      }
    }

    await _fetchAndCache();
  }

  /// Drops a criterion's own options so it falls back to the template
  /// default scale.
  Future<void> resetCriterionScale(String criterionId) async {
    await _client
        .from('assessment_scale_options')
        .delete()
        .eq('criterion_id', criterionId);
    await _fetchAndCache();
  }

  Future<void> upsertGradingBand(Map<String, dynamic> values) async {
    await _client.from('grading_bands').upsert(values);
    await _fetchAndCache();
  }
}

enum _StructureLevel {
  domain('assessment_domains'),
  section('assessment_sections'),
  criterion('assessment_criteria');

  const _StructureLevel(this.table);
  final String table;
}

extension _IgnoreFuture<T> on Future<T> {
  /// Fire-and-forget: a failed background refresh must never surface as
  /// an unhandled error, because the cached copy is still serving.
  void ignore() {
    then<void>((_) {}, onError: (Object _, StackTrace __) {});
  }
}

final assessmentRepositoryProvider = Provider<AssessmentRepository>(
  (ref) => AssessmentRepository(
    ref.watch(supabaseProvider),
    ref.watch(localStoreProvider),
  ),
);

/// The active checklist, resolved once per app session.
final blueprintProvider = FutureProvider<AssessmentBlueprint>(
  (ref) => ref.watch(assessmentRepositoryProvider).loadActiveBlueprint(),
);

final terminologyProvider = FutureProvider<List<TerminologyEntry>>(
  (ref) => ref.watch(assessmentRepositoryProvider).loadTerminology(),
);
