import 'dart:convert';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../role_simulation.dart';

/// Every identifier and proof byte is generated locally. Source catalogue IDs
/// are display context only and never enter the simulated data model.
class TesterFixtures {
  TesterFixtures(this.simulation) {
    final names = [
      simulation.center ?? sampleCenters.first,
      sampleCenters.last
    ];
    tables['centers'] = [
      for (var i = 0; i < 2; i++)
        {
          'id': simulation.centerIds[i],
          'code': 'SAMPLE-${i + 1}',
          'name_en': names[i].nameEn,
          'name_ar': names[i].nameAr,
          'is_active': true,
          'registered_patients': 20 + i * 10,
          'dialysis_beds': 6,
        }
    ];
    tables['assessment_templates'] = [
      {
        'id': templateId,
        'code': 'SAMPLE',
        'version': 1,
        'structure_version': 100,
        'name_en': 'Sample audit structure v 1.00',
        'name_ar': 'هيكل التدقيق التجريبي ١٫٠٠',
        'status': 'active',
        'is_default': true,
        'review_period_months': 6,
        'default_frequency': 'semiannual',
        'created_at': seedTime.toIso8601String(),
      }
    ];
    tables['assessment_domains'] = [
      {
        'id': domainId,
        'template_id': templateId,
        'code': 'SAMPLE',
        'name_en': 'Sample quality area',
        'name_ar': 'مجال الجودة التجريبي',
        'weight': 1,
        'sort_order': 1,
        'is_active': true,
      }
    ];
    tables['assessment_sections'] = [
      {
        'id': sectionId,
        'template_id': templateId,
        'domain_id': domainId,
        'code': 'S1',
        'name_en': 'Sample review',
        'name_ar': 'مراجعة تجريبية',
        'weight': 1,
        'sort_order': 1,
        'is_active': true,
      }
    ];
    final en = [
      'Review of a sample policy',
      'Review of a sample team record',
      'Sample equipment check',
      'Sample improvement record'
    ];
    final ar = [
      'مراجعة سياسة تجريبية',
      'مراجعة سجل فريق تجريبي',
      'فحص معدات تجريبي',
      'سجل تحسين تجريبي'
    ];
    tables['assessment_criteria'] = [
      for (var i = 0; i < 4; i++)
        {
          'id': criterionIds[i],
          'template_id': templateId,
          'section_id': sectionId,
          'code': 'S${i + 1}',
          'text_en': en[i],
          'text_ar': ar[i],
          'max_points': 3,
          'weight': 1,
          'evidence_required': false,
          'evidence_methods': ['document_review'],
          'sampling_required': false,
          'allows_not_applicable': false,
          'excluded_from_total': false,
          'sort_order': i,
          'is_active': true,
        }
    ];
    tables['v_criterion_scale'] = [
      for (final criterion in criterionIds)
        for (var i = 0; i < 3; i++)
          {
            'id': const Uuid().v4(),
            'criterion_id': criterion,
            'template_id': templateId,
            'level': ['met', 'partially_met', 'not_met'][i],
            'label_en': ['Met', 'Partially Met', 'Not Met'][i],
            'label_ar': ['مستوفى', 'مستوفى جزئياً', 'غير مستوفى'][i],
            'points': 3 - i,
            'triggers_ncr': i > 0,
            'sort_order': i,
          }
    ];
    tables['grading_bands'] = [];
    tables['assessment_sessions'] = [
      {
        'id': sessionId,
        'template_id': templateId,
        'title_en': 'Sample shared campaign',
        'title_ar': 'حملة مشتركة تجريبية',
        'template_name_en': tables['assessment_templates']!.first['name_en'],
        'template_name_ar': tables['assessment_templates']!.first['name_ar'],
        'cycle_label': '${seedTime.year} SAMPLE',
        'period_frequency': 'semiannual',
        'period_key': '${seedTime.year}-H2',
        'period_start': '${seedTime.year}-07-01',
        'period_end': '${seedTime.year}-12-31',
        'status': 'open',
        'published_at': seedTime.toIso8601String(),
      }
    ];
    for (final name in [
      'audits',
      'audit_responses',
      'audit_evidence',
      'audit_samples',
      'ncrs',
      'ncr_updates',
      'ncr_evidence',
      'staff_members',
      'staff_competencies',
      'emergency_drills',
      'center_badges',
      'badges',
      'notifications',
      'terminology_map',
      'audit_team_members',
      'audit_evidence_reviews',
      'tester_self_responses',
      'tester_messages',
      'audit_discussions',
      'audit_messages',
      'center_self_audits',
      'center_self_responses',
      'center_self_evidence',
      'tester_self_submissions'
    ]) {
      tables[name] = [];
    }
  }
  RoleSimulation simulation;
  bool seeded = false;
  bool offline = false;
  final localChanges = <String, Map<String, dynamic>>{};
  final localFailures = <String, int>{};
  final seedTime = DateTime.now().toUtc();
  final templateId = const Uuid().v4();
  final domainId = const Uuid().v4();
  final sectionId = const Uuid().v4();
  final sessionId = const Uuid().v4();
  final criterionIds = List.generate(4, (_) => const Uuid().v4());
  final Map<String, List<Map<String, dynamic>>> tables = {};
  final evidence = <String, Uint8List>{};
  Map<String, dynamic> get manifest => {
        'scenario_id': simulation.scenarioId,
        'schema_version': 1,
        'workspace_id': simulation.workspaceId,
        'center_ids': simulation.centerIds,
        'campaign_ids': [sessionId],
        'template_id': templateId,
        'seed_time': seedTime.toIso8601String(),
      };
  Uint8List sampleProof({bool arabic = false}) =>
      Uint8List.fromList(utf8.encode(arabic
          ? 'نموذج — وضع الاختبار\nدليل اصطناعي للمراجعة فقط.'
          : 'Sample — testing mode\nSynthetic proof for sample review.'));
}
