import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/offline/local_store.dart';
import '../../core/offline/network_error.dart';
import '../models/analytics.dart';
import '../models/audit.dart';
import '../models/operations.dart';
import '../supabase/supabase_providers.dart';

class AnalyticsRepository {
  AnalyticsRepository(this._client, this._store);

  final SupabaseClient _client;
  final LocalStore _store;

  Future<List<CenterRanking>> ranking() async {
    const cacheKey = 'analytics.ranking';
    try {
      final rows =
          await _client.from('v_center_ranking').select().order('rank_overall');
      // The ranking view predates the shared-session columns. Match the
      // selected approved audit by ID so its title and period stay together.
      final summaries = rows.isEmpty
          ? <Map<String, dynamic>>[]
          : await _client.from('v_audit_summary').select().inFilter(
              'audit_id', rows.map((row) => row['audit_id']).toList());
      final byId = {
        for (final summary in summaries) summary['audit_id']: summary
      };
      final results = [
        for (final row in rows)
          if (byId.containsKey(row['audit_id']))
            {...row, ...byId[row['audit_id']]!},
      ];
      await _store.putCache(cacheKey, results);
      return results.map(CenterRanking.fromMap).toList();
    } catch (error) {
      if (!isNetworkError(error)) rethrow;
      final cached = await _store.readCache<List<dynamic>>(cacheKey);
      if (cached == null) rethrow;
      return cached
          .cast<Map<String, dynamic>>()
          .map(CenterRanking.fromMap)
          .toList();
    }
  }

  Future<List<CenterRanking>> rankingForSession(String sessionId) async {
    final key = 'analytics.session-ranking.$sessionId';
    try {
      final participants = await _client
          .from('v_assessment_center_status')
          .select('official_audit_id')
          .eq('session_id', sessionId);
      final ids = participants
          .map((row) => row['official_audit_id'])
          .whereType<String>()
          .toList();
      if (ids.isEmpty) {
        await _store.putCache(key, <Map<String, dynamic>>[]);
        return [];
      }
      final rows = await _client
          .from('v_audit_summary')
          .select()
          .inFilter('audit_id', ids)
          .order('percent', ascending: false)
          .order('center_code');
      final statistics = await Future.wait([
        _client.from('v_center_satisfaction_current').select(),
        _client
            .from('ncrs')
            .select('center_id,status')
            .inFilter('audit_id', ids),
      ]);
      final satisfaction = {
        for (final row in statistics[0]) row['center_id']: row,
      };
      final openCounts = <String, int>{};
      final overdueCounts = <String, int>{};
      for (final finding in statistics[1]) {
        final center = finding['center_id'] as String;
        if (['open', 'in_progress', 'submitted_for_review']
            .contains(finding['status'])) {
          openCounts.update(center, (n) => n + 1, ifAbsent: () => 1);
        }
        if (finding['status'] == 'overdue') {
          overdueCounts.update(center, (n) => n + 1, ifAbsent: () => 1);
        }
      }
      var rank = 0;
      double? previous;
      final output = <Map<String, dynamic>>[];
      for (var index = 0; index < rows.length; index++) {
        final row = rows[index];
        final score = (row['percent'] as num).toDouble();
        if (score != previous) rank = index + 1;
        previous = score;
        final stats = satisfaction[row['center_id']];
        output.add({
          ...row,
          'rank_overall': rank,
          'satisfaction_percent': stats?['satisfaction_percent'],
          'satisfaction_responses': stats?['response_count'],
          'open_ncr_count': openCounts[row['center_id']] ?? 0,
          'overdue_ncr_count': overdueCounts[row['center_id']] ?? 0
        });
      }
      await _store.putCache(key, output);
      return output.map(CenterRanking.fromMap).toList();
    } catch (error) {
      if (!isNetworkError(error)) rethrow;
      final cached = await _store.readCache<List<dynamic>>(key);
      if (cached == null) rethrow;
      return cached
          .cast<Map<String, dynamic>>()
          .map(CenterRanking.fromMap)
          .toList();
    }
  }

  Future<List<ScoreBreakdown>> domainScores(String auditId) async {
    final cacheKey = 'analytics.domains.$auditId';
    try {
      final rows = await _client
          .from('v_audit_domain_scores')
          .select()
          .eq('audit_id', auditId)
          .order('sort_order');
      await _store.putCache(cacheKey, rows);
      return rows.map(ScoreBreakdown.fromDomainMap).toList();
    } catch (error) {
      if (!isNetworkError(error)) rethrow;
      final cached = await _store.readCache<List<dynamic>>(cacheKey);
      if (cached == null) rethrow;
      return cached
          .cast<Map<String, dynamic>>()
          .map(ScoreBreakdown.fromDomainMap)
          .toList();
    }
  }

  Future<List<ScoreBreakdown>> sectionScores(String auditId) async {
    final rows = await _client
        .from('v_audit_section_scores')
        .select()
        .eq('audit_id', auditId)
        .order('sort_order');
    return rows.map(ScoreBreakdown.fromSectionMap).toList();
  }

  /// Domain scores for several audits at once — the radar chart's data.
  Future<Map<String, List<ScoreBreakdown>>> domainScoresForAudits(
    List<String> auditIds,
  ) async {
    if (auditIds.isEmpty) return {};
    final rows = await _client
        .from('v_audit_domain_scores')
        .select()
        .inFilter('audit_id', auditIds)
        .order('sort_order');

    final grouped = <String, List<ScoreBreakdown>>{};
    for (final row in rows) {
      grouped
          .putIfAbsent(row['audit_id'] as String, () => [])
          .add(ScoreBreakdown.fromDomainMap(row));
    }
    return grouped;
  }

  Future<List<ScoreTrendPoint>> trend({List<String>? centerIds}) async {
    var query = _client.from('v_center_score_trend').select();
    if (centerIds != null && centerIds.isNotEmpty) {
      query = query.inFilter('center_id', centerIds);
    }
    final rows = await query.order('evaluation_date');
    return rows.map(ScoreTrendPoint.fromMap).toList();
  }

  Future<List<DomainInsight>> insights(String centerId) async {
    final rows = await _client
        .from('v_center_strengths_weaknesses')
        .select()
        .eq('center_id', centerId);
    return rows.map(DomainInsight.fromMap).toList();
  }

  /// Criterion-level detail behind a chart segment. Filtering by domain
  /// or section turns any bar into a drill-down.
  Future<List<CriterionDetail>> criterionDetail(
    String auditId, {
    String? domainCode,
    String? sectionId,
    bool onlyFindings = false,
  }) async {
    var query = _client
        .from('v_audit_criterion_detail')
        .select()
        .eq('audit_id', auditId);
    if (domainCode != null) query = query.eq('domain_code', domainCode);
    if (sectionId != null) query = query.eq('section_id', sectionId);
    if (onlyFindings) {
      query = query.inFilter('level', ['partially_met', 'not_met']);
    }
    final rows = await query.order('criterion_code');
    return rows.map(CriterionDetail.fromMap).toList();
  }

  Future<Map<String, SatisfactionSummary>> satisfaction() async {
    final rows = await _client.from('v_center_satisfaction_current').select();
    return {
      for (final row in rows)
        row['center_id'] as String: SatisfactionSummary.fromMap(row)
    };
  }

  Future<List<SatisfactionPoint>> satisfactionTrend(
      List<String> centerIds) async {
    var query = _client.from('v_center_satisfaction_monthly').select();
    if (centerIds.isNotEmpty) query = query.inFilter('center_id', centerIds);
    final rows = await query.order('period_month');
    return rows.map(SatisfactionPoint.fromMap).toList();
  }

  Future<List<SurveyQuestionResult>> satisfactionBreakdown(
      String centerId) async {
    final rows = await _client
        .from('v_survey_question_breakdown')
        .select()
        .eq('center_id', centerId);
    return rows.map(SurveyQuestionResult.fromMap).toList();
  }

  /// The centre whose score rose the most between its two most recent
  /// approved cycles.
  Future<ScoreTrendPoint?> mostImproved() async {
    final rows = await _client
        .from('v_center_score_trend')
        .select()
        .not('delta_percent', 'is', null)
        .order('evaluation_date', ascending: false)
        .limit(60);

    ScoreTrendPoint? best;
    final seen = <String>{};
    for (final row in rows) {
      final point = ScoreTrendPoint.fromMap(row);
      if (!seen.add(point.centerId)) continue; // keep only the latest cycle
      if (best == null ||
          (point.deltaPercent ?? 0) > (best.deltaPercent ?? 0)) {
        best = point;
      }
    }
    return (best != null && (best.deltaPercent ?? 0) > 0) ? best : null;
  }

  Future<ScoreTrendPoint?> largestDecline() async {
    final rows = await _client
        .from('v_center_score_trend')
        .select()
        .not('delta_percent', 'is', null)
        .order('evaluation_date', ascending: false)
        .limit(60);

    ScoreTrendPoint? worst;
    final seen = <String>{};
    for (final row in rows) {
      final point = ScoreTrendPoint.fromMap(row);
      if (!seen.add(point.centerId)) continue;
      if (worst == null ||
          (point.deltaPercent ?? 0) < (worst.deltaPercent ?? 0)) {
        worst = point;
      }
    }
    return (worst != null && (worst.deltaPercent ?? 0) < 0) ? worst : null;
  }
}

final analyticsRepositoryProvider = Provider<AnalyticsRepository>(
  (ref) => AnalyticsRepository(
    watchSessionClient(ref),
    ref.watch(localStoreProvider),
  ),
);

final rankingProvider = FutureProvider<List<CenterRanking>>(
  (ref) => ref.watch(analyticsRepositoryProvider).ranking(),
);

final domainScoresProvider =
    FutureProvider.family<List<ScoreBreakdown>, String>(
  (ref, auditId) =>
      ref.watch(analyticsRepositoryProvider).domainScores(auditId),
);

final sectionScoresProvider =
    FutureProvider.family<List<ScoreBreakdown>, String>(
  (ref, auditId) =>
      ref.watch(analyticsRepositoryProvider).sectionScores(auditId),
);

final insightsProvider = FutureProvider.family<List<DomainInsight>, String>(
  (ref, centerId) => ref.watch(analyticsRepositoryProvider).insights(centerId),
);

final satisfactionProvider = FutureProvider<Map<String, SatisfactionSummary>>(
  (ref) => ref.watch(analyticsRepositoryProvider).satisfaction(),
);

final trendProvider = FutureProvider<List<ScoreTrendPoint>>(
  (ref) => ref.watch(analyticsRepositoryProvider).trend(),
);

final sessionRankingProvider =
    FutureProvider.family<List<CenterRanking>, String>((ref, id) =>
        ref.watch(analyticsRepositoryProvider).rankingForSession(id));
