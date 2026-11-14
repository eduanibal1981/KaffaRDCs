import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../../data/models/primitives.dart';
import 'fixtures.dart';
import 'workspace_lease.dart';

/// In-process implementation of the repositories' REST/RPC contract. The
/// transport has no socket client. Unknown endpoints and out-of-scope IDs fail
/// closed, including calls made directly through the scoped Supabase client.
class FakeRepositories extends http.BaseClient {
  FakeRepositories(this.fixtures, this.lease, {String? actor}) {
    actorId = actor ?? actorId;
    if (fixtures.seeded) return;
    fixtures.seeded = true;
    for (final center in fixtures.simulation.centerIds) {
      if (fixtures.simulation.scenarioId == 'campaign' &&
          center == fixtures.simulation.centerIds.first) {
        continue;
      }
      final audit = _join(fixtures.sessionId, center);
      for (final criterion in fixtures.criterionIds) {
        final option = _table('v_criterion_scale')
            .firstWhere((o) => o['criterion_id'] == criterion);
        _saveResponse({
          'audit_id': audit,
          'criterion_id': criterion,
          'scale_option_id': option['id']
        });
      }
      _table('audit_team_members').add({
        'id': const Uuid().v4(),
        'audit_id': audit,
        'user_id': actorId,
        'member_name': 'Sample Reviewer',
        'actual_job_title': 'Quality specialist',
        'team_role': 'lead',
        'row_version': 1,
        'full_name': 'Sample Reviewer / مراجع تجريبي',
        'actual_job': 'Sample Nurse / ممرض تجريبي',
        'responsibility': 'Sample lead / قائد تجريبي'
      });
      final selfResponses = [
        for (final criterion in fixtures.criterionIds)
          {
            'audit_id': audit,
            'criterion_id': criterion,
            'scale_option_id': _table('v_criterion_scale')
                .firstWhere((o) => o['criterion_id'] == criterion)['id'],
          }
      ];
      _table('tester_self_responses').addAll(selfResponses);
      final baseline = {
        'audit_id': audit,
        'responses': jsonDecode(jsonEncode(selfResponses))
      };
      _table('tester_self_submissions').add(baseline);
      _audit(audit)['tester_self_baseline'] = jsonDecode(jsonEncode(baseline));
      final proofId = const Uuid().v4();
      fixtures.evidence[proofId] = fixtures.sampleProof();
      _table('audit_evidence').add({
        'id': proofId,
        'audit_id': audit,
        'center_id': center,
        'storage_bucket': 'sample',
        'storage_path': proofId,
        'file_name': 'SAMPLE-testing-mode.txt',
        'mime_type': 'text/plain',
        'size_bytes': fixtures.evidence[proofId]!.length,
        'uploaded_at': fixtures.seedTime.toIso8601String()
      });
      _table('tester_messages').add({
        'id': const Uuid().v4(),
        'audit_id': audit,
        'body': 'Sample review message / رسالة مراجعة تجريبية'
      });
      _audit(audit)['status'] =
          fixtures.simulation.scenarioId == 'review' ? 'submitted' : 'approved';
    }
  }
  final TesterFixtures fixtures;
  final WorkspaceLease lease;
  bool get offline => fixtures.offline;
  set offline(bool value) => fixtures.offline = value;
  Map<String, Map<String, dynamic>> get localChanges => fixtures.localChanges;
  bool get _directorate => fixtures.simulation.permissions.isDirectorate;
  List<Map<String, dynamic>> _table(String name) =>
      fixtures.tables[name] ?? (throw StateError('Unavailable sample data'));
  bool _canRead(String center) =>
      fixtures.simulation.permissions.canReadCenter(center);
  bool _canAudit(String center) =>
      fixtures.simulation.permissions.canAuditCenter(center);
  void _require(bool allowed) {
    if (!allowed) throw const _Denied();
  }

  Map<String, dynamic> _audit(String id) => _table('audits')
      .firstWhere((a) => a['id'] == id, orElse: () => throw const _Denied());
  bool _editable(Map<String, dynamic> audit) =>
      ['draft', 'rejected'].contains(audit['status']) &&
      _table('assessment_sessions')
              .firstWhere((s) => s['id'] == audit['session_id'])['status'] ==
          'open';

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lease.check();
    if (request.url.host != 'preview.kafaa.invalid') throw const _Denied();
    if (offline) throw http.ClientException('Simulated offline', request.url);
    final bytes = await request.finalize().toBytes();
    lease.check();
    try {
      final path = request.url.pathSegments;
      if (path.length >= 4 &&
          path[0] == 'storage' &&
          path[1] == 'v1' &&
          path[2] == 'object') {
        final start = path[3] == 'authenticated' ? 5 : 4;
        final bucket = path[3] == 'authenticated' ? path[4] : path[3];
        final name = path.skip(start).join('/');
        final e = _table(bucket == 'audit-evidence'
                ? 'audit_evidence'
                : 'center_self_evidence')
            .where((e) => e['storage_path'] == name)
            .firstOrNull;
        _require(['self-audit-evidence', 'audit-evidence'].contains(bucket) &&
            e != null &&
            _readable(
                bucket == 'audit-evidence'
                    ? 'audit_evidence'
                    : 'center_self_evidence',
                e));
        if (request.method == 'GET') {
          final proof = fixtures.evidence[name];
          _require(proof != null);
          return http.StreamedResponse(Stream.value(proof!), 200,
              headers: {'content-type': e!['mime_type']});
        }
        _require((request.method == 'POST' || request.method == 'PUT') &&
            _selfWritable(e!['self_audit_id']) &&
            e['upload_state'] == 'pending');
        var fileBytes = bytes;
        final contentType = request.headers['content-type'] ?? '';
        final boundary =
            RegExp(r'boundary="?([^";]+)').firstMatch(contentType)?.group(1);
        if (boundary != null) {
          final parts = latin1.decode(bytes).split('--$boundary');
          final filePart =
              parts.where((p) => p.contains('filename=')).firstOrNull;
          if (filePart != null) {
            final start = filePart.indexOf('\r\n\r\n') + 4;
            fileBytes =
                latin1.encode(filePart.substring(start, filePart.length - 2));
          }
        }
        fixtures.evidence[name] = fileBytes;
        return _response({'Key': '$bucket/$name'}, request);
      }
      if (path.length < 3 || path[0] != 'rest' || path[1] != 'v1') {
        throw const _Denied();
      }
      final body = bytes.isEmpty ? null : jsonDecode(utf8.decode(bytes));
      if (path[2] == 'rpc') {
        return _response(
            await _rpc(path[3], (body as Map? ?? {}).cast<String, dynamic>()),
            request);
      }
      final table = path[2];
      if (request.method == 'GET' || request.method == 'HEAD') {
        final rows = _filter(
            _rows(table).where((row) => _readable(table, row)).toList(),
            request.url);
        final offset =
            int.tryParse(request.url.queryParameters['offset'] ?? '') ?? 0;
        final limit =
            int.tryParse(request.url.queryParameters['limit'] ?? '') ??
                rows.length;
        final page = rows.skip(offset).take(limit).toList();
        if (request.headers['accept']?.contains('vnd.pgrst.object') ?? false) {
          if (page.length != 1) {
            return _response({
              'code': 'PGRST116',
              'message': 'Sample item unavailable',
              'details': 'The result contains ${page.length} rows'
            }, request, status: 406);
          }
          return _response(page.single, request);
        }
        return _response(page, request, headers: {
          'content-range': '$offset-${offset + page.length - 1}/${rows.length}'
        });
      }
      return _response(
          _write(table, request.method, body, request.url), request);
    } on _Denied {
      return _response({
        'code': '42501',
        'message': 'Access denied in this sample role'
      }, request, status: 403);
    } on StateError catch (error) {
      return _response(
          {'code': '23514', 'message': 'Sample: ${error.message}'}, request,
          status: 409);
    }
  }

  http.StreamedResponse _response(Object? body, http.BaseRequest request,
          {int status = 200, Map<String, String> headers = const {}}) =>
      http.StreamedResponse(Stream.value(utf8.encode(jsonEncode(body))), status,
          headers: {'content-type': 'application/json', ...headers},
          request: request);

  bool _readable(String table, Map<String, dynamic> row) {
    if (table.startsWith('center_self_')) {
      final h = table == 'center_self_audits'
          ? row
          : _table('center_self_audits')
              .where((h) => h['id'] == row['self_audit_id'])
              .firstOrNull;
      final a = h == null
          ? null
          : _table('audits')
              .where((a) => a['participation_id'] == h['participation_id'])
              .firstOrNull;
      return a != null &&
          fixtures.simulation.permissions.canReadSelfAudit(a['center_id']);
    }
    if (table == 'audit_discussions') {
      final a = _table('audits')
          .where((a) => a['participation_id'] == row['participation_id'])
          .firstOrNull;
      return a != null &&
          fixtures.simulation.permissions
              .canDiscussAudit(a['center_id'] as String);
    }
    if (table == 'audit_messages') {
      final d = _table('audit_discussions')
          .where((d) => d['id'] == row['discussion_id'])
          .firstOrNull;
      return d != null && _readable('audit_discussions', d);
    }
    final center = row['center_id'] ?? (table == 'centers' ? row['id'] : null);
    if (center is String) return _canRead(center);
    if (row['ncr_id'] is String) {
      final ncr =
          _table('ncrs').where((n) => n['id'] == row['ncr_id']).firstOrNull;
      return ncr != null && _canRead(ncr['center_id'] as String);
    }
    if (row['audit_id'] is String) {
      return _canRead(_audit(row['audit_id'])['center_id'] as String);
    }
    return true;
  }

  List<Map<String, dynamic>> _rows(String table) {
    switch (table) {
      case 'v_audit_reviewed_proof':
        final latest = <String, Map<String, dynamic>>{};
        for (final r in _table('audit_evidence_reviews')) {
          latest['${r['response_id']}:${r['self_evidence_id']}:${r['audit_evidence_id']}'] =
              r;
        }
        return [
          for (final r in latest.values)
            {
              ...r,
              'criterion_id': _table('audit_responses').firstWhere(
                  (a) => a['id'] == r['response_id'])['criterion_id'],
              'source_id': r['self_evidence_id'] ?? r['audit_evidence_id'],
              'source_type':
                  r['self_evidence_id'] == null ? 'official' : 'self',
              'finalized': true
            }
        ];
      case 'v_audit_summary':
        return _table('audits').map(_summary).toList();
      case 'v_assessment_progress':
        return [
          for (final session in _table('assessment_sessions'))
            {
              ...session,
              'eligible_count':
                  fixtures.simulation.centerIds.where(_canRead).length,
              'joined_count': _table('audits')
                  .where((a) =>
                      a['session_id'] == session['id'] &&
                      _canRead(a['center_id']))
                  .length,
              'submitted_count': _table('audits')
                  .where((a) =>
                      a['session_id'] == session['id'] &&
                      a['status'] == 'submitted' &&
                      _canRead(a['center_id']))
                  .length,
              'approved_count': _table('audits')
                  .where((a) =>
                      a['session_id'] == session['id'] &&
                      a['status'] == 'approved' &&
                      _canRead(a['center_id']))
                  .length,
            }
        ];
      case 'v_assessment_center_status':
        return [
          for (final session in _table('assessment_sessions'))
            for (final center in _table('centers'))
              _participation(session, center)
        ];
      case 'v_center_ranking':
        return [
          for (final audit in _table('audits'))
            if (audit['status'] == 'approved')
              {..._summary(audit), 'rank_overall': 1}
        ];
      case 'v_audit_domain_scores':
      case 'v_audit_section_scores':
        return [
          for (final audit in _table('audits'))
            {
              ..._summary(audit),
              'domain_id': fixtures.domainId,
              'section_id': fixtures.sectionId,
              'domain_name_en': 'Sample quality area',
              'domain_name_ar': 'مجال الجودة التجريبي',
              'section_name_en': 'Sample review',
              'section_name_ar': 'مراجعة تجريبية',
              'domain_code': 'SAMPLE',
              'section_code': 'S1',
              'sort_order': 1,
            }
        ];
      case 'v_audit_criterion_detail':
        return [
          for (final audit in _table('audits'))
            for (final criterion in _table('assessment_criteria'))
              {
                ...criterion,
                ...?_table('audit_responses')
                    .where((r) =>
                        r['audit_id'] == audit['id'] &&
                        r['criterion_id'] == criterion['id'])
                    .firstOrNull,
                'audit_id': audit['id'],
                'center_id': audit['center_id'],
                'criterion_id': criterion['id'],
                'criterion_code': criterion['code'],
                'criterion_en': criterion['text_en'],
                'criterion_ar': criterion['text_ar'],
                'domain_code': 'SAMPLE',
                'evidence_count': 0,
              }
        ];
      case 'audit_responses':
        return [
          for (final row in _table(table))
            {
              ...row,
              'audit_evidence': [
                {
                  'count': _table('audit_evidence')
                      .where((e) => e['response_id'] == row['id'])
                      .length
                }
              ]
            }
        ];
      case 'v_ncr_dashboard':
      case 'v_recurring_findings':
      case 'v_staff_competency_status':
      case 'v_center_competency_readiness':
      case 'v_center_satisfaction_current':
      case 'v_center_satisfaction_monthly':
      case 'v_center_score_trend':
      case 'v_center_strengths_weaknesses':
      case 'v_survey_question_breakdown':
      case 'competency_types':
        return [];
      default:
        return _table(table);
    }
  }

  Map<String, dynamic> _participation(
      Map<String, dynamic> session, Map<String, dynamic> center) {
    final audit = _table('audits')
        .where((a) =>
            a['session_id'] == session['id'] && a['center_id'] == center['id'])
        .firstOrNull;
    return {
      'session_id': session['id'],
      'center_id': center['id'],
      'center_name_en': center['name_en'],
      'center_name_ar': center['name_ar'],
      'center_active': true,
      if (audit != null) ...{
        ..._summary(audit),
        'participation_id': audit['participation_id'],
        'joined_at': fixtures.seedTime.toIso8601String(),
        if (audit['status'] == 'approved') 'official_audit_id': audit['id'],
        if (audit['status'] == 'approved')
          'official_percent': _summary(audit)['percent'],
      }
    };
  }

  Map<String, dynamic> _summary(Map<String, dynamic> audit) {
    final center =
        _table('centers').firstWhere((c) => c['id'] == audit['center_id']);
    final session = _table('assessment_sessions')
        .firstWhere((s) => s['id'] == audit['session_id']);
    final responses = _table('audit_responses')
        .where((r) => r['audit_id'] == audit['id'])
        .toList();
    final total =
        responses.fold<num>(0, (sum, r) => sum + (r['points'] as num? ?? 0));
    return {
      ...audit,
      'audit_id': audit['id'],
      'center_code': center['code'],
      'center_name_en': center['name_en'],
      'center_name_ar': center['name_ar'],
      'session_title_en': session['title_en'],
      'session_title_ar': session['title_ar'],
      'session_status': session['status'],
      'session_due_at': session['due_at'],
      'total_points': total,
      'max_points': 12,
      'percent': total / 12 * 100,
      'answered_count': responses.length,
      'scorable_count': 4,
      'completion_percent': responses.length / 4 * 100,
      'template_name_en': _table('assessment_templates').first['name_en'],
      'template_name_ar': _table('assessment_templates').first['name_ar'],
      'evaluation_date': fixtures.seedTime.toIso8601String(),
      'version': audit['version'] ?? 1,
      'row_version': audit['row_version'] ?? 1,
    };
  }

  List<Map<String, dynamic>> _filter(List<Map<String, dynamic>> rows, Uri uri) {
    for (final entry in uri.queryParameters.entries) {
      if (['select', 'order', 'offset', 'limit', 'on_conflict']
          .contains(entry.key)) {
        continue;
      }
      final expression = entry.value;
      rows = rows.where((row) {
        final value = row[entry.key];
        if (expression.startsWith('eq.')) {
          return '$value' == expression.substring(3);
        }
        if (expression == 'is.null') return value == null;
        if (expression == 'not.is.null') return value != null;
        if (expression.startsWith('in.(')) {
          return expression
              .substring(4, expression.length - 1)
              .split(',')
              .map((s) => s.replaceAll('"', ''))
              .contains('$value');
        }
        if (expression.startsWith('gte.')) {
          return '$value'.compareTo(expression.substring(4)) >= 0;
        }
        if (expression.startsWith('lte.')) {
          return '$value'.compareTo(expression.substring(4)) <= 0;
        }
        throw StateError('Unsupported sample query');
      }).toList();
    }
    final order = uri.queryParameters['order'];
    if (order != null) {
      rows.sort((a, b) {
        for (final field in order.split(',')) {
          final parts = field.split('.');
          final av = a[parts.first];
          final bv = b[parts.first];
          final comparison = av is num && bv is num
              ? av.compareTo(bv)
              : '$av'.compareTo('$bv');
          if (comparison != 0) {
            return parts.contains('desc') ? -comparison : comparison;
          }
        }
        return 0;
      });
    }
    return rows;
  }

  List<Map<String, dynamic>> _write(
      String table, String method, Object? body, Uri uri) {
    final allowed = [
      'centers',
      'audit_responses',
      'audits',
      'audit_samples',
      'audit_evidence',
      'ncrs',
      'ncr_updates',
      'ncr_evidence',
      'staff_members',
      'staff_competencies',
      'emergency_drills',
      'center_badges',
      'notifications',
      'audit_team_members'
    ];
    _require(allowed.contains(table));
    final rows = _table(table);
    final targets = method == 'POST'
        ? (body is List
            ? body.cast<Map<String, dynamic>>()
            : [(body as Map? ?? {}).cast<String, dynamic>()])
        : _filter(rows.toList(), uri);
    final result = <Map<String, dynamic>>[];
    for (final target in targets) {
      final values = method == 'POST'
          ? Map<String, dynamic>.of(target)
          : {...target, ...?(body as Map?)?.cast<String, dynamic>()};
      final auditId =
          values['audit_id'] ?? (table == 'audits' ? values['id'] : null);
      final audit = auditId is String ? _audit(auditId) : null;
      final center = values['center_id'] ??
          audit?['center_id'] ??
          (table == 'centers' ? values['id'] : null);
      if (center is String) {
        _require(_table('centers').any((c) => c['id'] == center));
      }
      if (table == 'audits' && body is Map) {
        _require(!body.keys.any((key) => [
              'center_id',
              'session_id',
              'participation_id',
              'template_id'
            ].contains(key)));
      }
      if (table == 'centers') {
        _require(_directorate);
      } else if (table == 'notifications') {
        _require(method == 'PATCH');
      } else if (['staff_members', 'staff_competencies', 'emergency_drills']
          .contains(table)) {
        _require(center is String &&
            fixtures.simulation.permissions.managesCenter(center));
      } else if (table == 'center_badges') {
        _require(_directorate && center is String && _canRead(center));
      } else if (table.startsWith('ncr')) {
        final parent = table == 'ncrs'
            ? values
            : _table('ncrs').firstWhere((n) => n['id'] == values['ncr_id']);
        _require(_canRead(parent['center_id'] as String));
        if (values['status'] == 'closed') {
          _require(fixtures.simulation.permissions.canCloseNcr);
        }
      } else {
        _require(audit != null &&
            center is String &&
            _canAudit(center) &&
            _editable(audit));
      }
      if (table == 'audits') {
        _require(!values.containsKey('status') ||
            values['status'] == target['status']);
      }
      if (method == 'DELETE') {
        rows.remove(target);
        continue;
      }
      if (table == 'audit_responses') {
        result.add(_saveResponse(values));
        continue;
      }
      values['id'] ??= const Uuid().v4();
      final existing = rows.where((r) => r['id'] == values['id']).firstOrNull;
      if (existing == null) {
        rows.add(values);
        result.add(values);
      } else {
        existing.addAll(values);
        result.add(existing);
      }
    }
    return result;
  }

  Map<String, dynamic> _saveResponse(Map<String, dynamic> values) {
    final option = _table('v_criterion_scale').firstWhere((o) =>
        o['id'] == values['scale_option_id'] &&
        o['criterion_id'] == values['criterion_id']);
    final rows = _table('audit_responses');
    final existing = rows
        .where((r) =>
            r['audit_id'] == values['audit_id'] &&
            r['criterion_id'] == values['criterion_id'])
        .firstOrNull;
    final response = {
      ...values,
      'id': existing?['id'] ?? values['id'] ?? const Uuid().v4(),
      'row_version': existing?['row_version'] ?? 1,
      'points': option['points'],
      'level': option['level'],
      'assessed_at': fixtures.seedTime.toIso8601String()
    };
    if (existing == null) {
      rows.add(response);
      return response;
    }
    existing.addAll(response);
    return existing;
  }

  String _join(String sessionId, String center) {
    _require(fixtures.simulation.centerIds.contains(center));
    final session =
        _table('assessment_sessions').firstWhere((s) => s['id'] == sessionId);
    if (session['status'] != 'open') throw StateError('Campaign closed');
    final existing = _table('audits')
        .where((a) => a['session_id'] == sessionId && a['center_id'] == center)
        .firstOrNull;
    if (existing != null) return existing['id'] as String;
    final id = const Uuid().v4();
    _table('audits').add({
      'id': id,
      'session_id': sessionId,
      'center_id': center,
      'participation_id': const Uuid().v4(),
      'template_id': session['template_id'],
      'period_start': session['period_start'],
      'period_end': session['period_end'],
      'period_key': session['period_key'],
      'period_frequency': session['period_frequency'],
      'cycle_label': session['cycle_label'],
      'status': 'draft',
      'evaluation_date': fixtures.seedTime.toIso8601String(),
      'content_version': 1,
      'row_version': 1
    });
    return id;
  }

  Map<String, dynamic> _selfHeader(String id) => _table('center_self_audits')
      .firstWhere((h) => h['id'] == id, orElse: () => throw const _Denied());
  bool _selfWritable(String id) {
    final h = _selfHeader(id);
    final a = _table('audits')
        .firstWhere((a) => a['participation_id'] == h['participation_id']);
    return h['status'] == 'draft' &&
        fixtures.simulation.permissions.canPrepareSelfAudit(a['center_id']) &&
        _editable(a) &&
        a['submitted_at'] == null &&
        a['parent_audit_id'] == null;
  }

  String actorId = 'f8000000-0000-4000-8000-000000000001';
  bool formalSubmitting = false;
  void bumpOfficial(Map<String, dynamic> a) {
    a['row_version'] = (a['row_version'] as int? ?? 1) + 1;
    a['content_version'] = (a['content_version'] as int? ?? 1) + 1;
    a['signed_content_version'] = null;
    a['signoff_version'] = null;
    a['signed_off_at'] = null;
  }

  Future<Object?> _rpc(String name, Map<String, dynamic> params) async {
    switch (name) {
      case 'post_ncr_note':
        final n =
            _table('ncrs').firstWhere((n) => n['id'] == params['p_ncr_id']);
        _require(
            fixtures.simulation.permissions.canDiscussAudit(n['center_id']));
        final old = _table('ncr_updates')
            .where((m) => m['id'] == params['p_id'])
            .firstOrNull;
        if (old != null) {
          _require(old['note'] == params['p_body']);
          return old['id'];
        }
        _table('ncr_updates').add({
          'id': params['p_id'],
          'ncr_id': params['p_ncr_id'],
          'note': params['p_body'],
          'created_at': DateTime.now().toIso8601String()
        });
        return params['p_id'];
      case 'start_center_self_audit':
        final part = params['p_participation_id'];
        final a = _table('audits').firstWhere(
            (a) => a['participation_id'] == part,
            orElse: () => throw const _Denied());
        _require(fixtures.simulation.permissions
                .canPrepareSelfAudit(a['center_id']) &&
            _editable(a) &&
            a['submitted_at'] == null);
        final existing = _table('center_self_audits')
            .where((h) =>
                h['id'] == params['p_id'] ||
                h['participation_id'] == part && h['status'] == 'draft')
            .firstOrNull;
        if (existing != null) return existing['id'];
        final versions = _table('center_self_audits')
            .where((h) => h['participation_id'] == part)
            .toList();
        final h = {
          'id': params['p_id'],
          'participation_id': part,
          'template_id': a['template_id'],
          'version': versions.length + 1,
          'parent_self_audit_id': params['p_parent_id'],
          'status': 'draft',
          'row_version': 1
        };
        _table('center_self_audits').add(h);
        if (params['p_parent_id'] != null) {
          for (final r in _table('center_self_responses')
              .where((r) => r['self_audit_id'] == params['p_parent_id'])
              .toList()) {
            _table('center_self_responses').add({
              ...r,
              'id': const Uuid().v4(),
              'self_audit_id': h['id'],
              'row_version': 1
            });
          }
        }
        return h['id'];
      case 'upsert_center_self_response':
        final h = _selfHeader(params['p_self_audit_id']);
        _require(_selfWritable(h['id']));
        final old = _table('center_self_responses')
            .where((r) =>
                r['self_audit_id'] == h['id'] &&
                r['criterion_id'] == params['p_criterion_id'])
            .firstOrNull;
        final data = Map<String, dynamic>.from(params['p_payload']);
        if (old?['last_mutation_id'] == params['p_mutation_id']) return old;
        if ((old?['row_version'] ?? 0) != params['p_expected_version']) {
          throw StateError('KAFAA_CONFLICT');
        }
        final c = _table('assessment_criteria')
            .firstWhere((c) => c['id'] == params['p_criterion_id']);
        _require(c['template_id'] == h['template_id']);
        final na = data['is_not_applicable'] == true;
        _require(!na || c['allows_not_applicable'] == true);
        final option = _table('v_criterion_scale')
            .where((o) =>
                o['criterion_id'] == c['id'] &&
                o['id'] == data['scale_option_id'])
            .firstOrNull;
        _require(na || data['scale_option_id'] == null || option != null);
        final row = {
          ...data,
          'id': old?['id'] ?? params['p_id'],
          'self_audit_id': h['id'],
          'criterion_id': c['id'],
          'level': na ? null : option?['level'],
          'points': na ? 0 : option?['points'] ?? 0,
          'row_version': (old?['row_version'] as int? ?? 0) + 1,
          'last_mutation_id': params['p_mutation_id']
        };
        if (old != null) _table('center_self_responses').remove(old);
        _table('center_self_responses').add(row);
        h['row_version'] = (h['row_version'] as int) + 1;
        return row;
      case 'reserve_center_self_evidence':
        final r = _table('center_self_responses')
            .firstWhere((r) => r['id'] == params['p_self_response_id']);
        final h = _selfHeader(r['self_audit_id']);
        final old = _table('center_self_evidence')
            .where((e) => e['id'] == params['p_id'])
            .firstOrNull;
        if (old != null) {
          _require(_readable('center_self_evidence', old));
          return old;
        }
        _require(_selfWritable(h['id']));
        final a = _table('audits')
            .firstWhere((a) => a['participation_id'] == h['participation_id']);
        final data = Map<String, dynamic>.from(params['p_metadata']);
        final row = {
          ...data,
          'id': params['p_id'],
          'self_audit_id': h['id'],
          'self_response_id': r['id'],
          'storage_bucket': 'self-audit-evidence',
          'storage_path':
              "${a['center_id']}/${h['participation_id']}/${h['id']}/${params['p_id']}/${data['file_name']}",
          'upload_state': 'pending'
        };
        _table('center_self_evidence').add(row);
        return row;
      case 'finalize_center_self_evidence':
        final e = _table('center_self_evidence')
            .firstWhere((e) => e['id'] == params['p_id']);
        _require(_readable('center_self_evidence', e));
        if (e['upload_state'] == 'finalized') return e;
        _require(_selfWritable(e['self_audit_id']) &&
            fixtures.evidence[e['storage_path']]?.length == e['size_bytes']);
        e['upload_state'] = 'finalized';
        return e;
      case 'remove_draft_self_evidence':
        final e = _table('center_self_evidence')
            .firstWhere((e) => e['id'] == params['p_id']);
        _require(_selfWritable(e['self_audit_id']));
        e['removed_at'] = DateTime.now().toIso8601String();
        return null;
      case 'submit_center_self_audit':
        final h = _selfHeader(params['p_id']);
        _require(_selfWritable(h['id']));
        if (h['row_version'] != params['p_expected_version']) {
          throw StateError('KAFAA_CONFLICT');
        }
        final rs = _table('center_self_responses')
            .where((r) => r['self_audit_id'] == h['id']);
        _require(_table('assessment_criteria')
            .where((c) =>
                c['is_active'] != false && c['excluded_from_total'] != true)
            .every((c) => rs.any((r) =>
                r['criterion_id'] == c['id'] &&
                (r['level'] != null || r['is_not_applicable'] == true))));
        h['status'] = 'submitted';
        h['submitted_at'] = DateTime.now().toIso8601String();
        return h;
      case 'audit_team_accounts':
        final a = _audit(params['p_audit_id']);
        _require(_canAudit(a['center_id']));
        return [
          {
            'id': actorId,
            'full_name': 'Sample reviewer',
            'job_title': 'Quality specialist'
          }
        ];
      case 'upsert_audit_team_member':
        final a = _audit(params['p_audit_id']);
        _require(_canAudit(a['center_id']) && _editable(a));
        final rows = _table('audit_team_members');
        final existing =
            rows.where((r) => r['id'] == params['p_id']).firstOrNull;
        final p = Map<String, dynamic>.from(params['p_payload']);
        if (existing != null &&
            jsonEncode(existing['last_payload']) == jsonEncode(p) &&
            existing['row_version'] ==
                (params['p_expected_version'] as num) + 1) {
          return existing;
        }
        if ((existing?['row_version'] ?? 0) != params['p_expected_version']) {
          throw StateError('KAFAA_CONFLICT');
        }
        if ((p['member_name'] ?? '').trim().isEmpty ||
            (p['actual_job_title'] ?? '').trim().isEmpty) {
          throw StateError('KAFAA_TEAM_NAME_JOB_REQUIRED');
        }
        if (p['team_role'] == 'lead' && p['user_id'] == null) {
          throw StateError('KAFAA_LEAD_ACCOUNT_REQUIRED');
        }
        if (p['user_id'] != null &&
            rows.any((r) =>
                r['audit_id'] == a['id'] &&
                r['user_id'] == p['user_id'] &&
                r['id'] != params['p_id'])) {
          throw StateError('KAFAA_TEAM_DUPLICATE_USER');
        }
        if (p['team_role'] == 'lead') {
          for (final m in rows.where((r) =>
              r['audit_id'] == a['id'] &&
              r['team_role'] == 'lead' &&
              r['id'] != params['p_id'])) {
            m['team_role'] = 'member';
            m['row_version'] = (m['row_version'] as int? ?? 1) + 1;
          }
        }
        final row = {
          'id': params['p_id'],
          'audit_id': a['id'],
          ...p,
          'row_version': (params['p_expected_version'] as num) + 1,
          'last_payload': p
        };
        if (existing == null) {
          rows.add(row);
        } else {
          existing.addAll(row);
        }
        if (p['team_role'] == 'lead') {
          a['lead_auditor_id'] = p['user_id'];
          a['evaluator_name'] = p['member_name'];
        }
        bumpOfficial(a);
        return existing ?? row;
      case 'remove_audit_team_member':
        final m = _table('audit_team_members')
            .firstWhere((r) => r['id'] == params['p_id']);
        final a = _audit(m['audit_id']);
        _require(_canAudit(a['center_id']) && _editable(a));
        if (m['removed_at'] != null) return null;
        if (m['row_version'] != params['p_expected_version']) {
          throw StateError('KAFAA_CONFLICT');
        }
        m['removed_at'] = DateTime.now().toIso8601String();
        m['row_version'] = (m['row_version'] as int) + 1;
        bumpOfficial(a);
        return null;
      case 'upsert_assessment_response':
        final a = _audit(params['p_audit_id']);
        _require(_canAudit(a['center_id']) && _editable(a));
        final existing = _table('audit_responses')
            .where((r) =>
                r['audit_id'] == a['id'] &&
                r['criterion_id'] == params['p_criterion_id'])
            .firstOrNull;
        final p = Map<String, dynamic>.from(params['p_payload']);
        if (existing?['last_mutation_id'] == params['p_mutation_id']) {
          if (jsonEncode(existing?['last_payload']) != jsonEncode(p)) {
            throw StateError('KAFAA_RETRY_MISMATCH');
          }
          return existing;
        }
        if ((existing?['row_version'] ?? (existing == null ? 0 : 1)) !=
            params['p_expected_version']) {
          throw StateError('KAFAA_CONFLICT');
        }
        final r = _saveResponse({
          ...p,
          'audit_id': a['id'],
          'criterion_id': params['p_criterion_id']
        });
        r['id'] = params['p_id'];
        r['row_version'] = (params['p_expected_version'] as num) + 1;
        r['last_mutation_id'] = params['p_mutation_id'];
        r['last_payload'] = p;
        bumpOfficial(a);
        return r;
      case 'remove_unreviewed_audit_evidence':
        final a = _audit(params['p_audit_id']);
        _require(_canAudit(a['center_id']) && _editable(a));
        if (_table('audit_evidence_reviews')
            .any((r) => r['audit_evidence_id'] == params['p_id'])) {
          throw StateError('KAFAA_REVIEWED_PROOF_IMMUTABLE');
        }
        _table('audit_evidence').removeWhere(
            (r) => r['id'] == params['p_id'] && r['audit_id'] == a['id']);
        bumpOfficial(a);
        return null;
      case 'reserve_audit_evidence':
        final a = _audit(params['p_audit_id']);
        _require(_canAudit(a['center_id']) && _editable(a));
        final rows = _table('audit_evidence');
        final old = rows.where((r) => r['id'] == params['p_id']).firstOrNull;
        if (old != null) return old;
        final r = {
          'id': params['p_id'],
          'audit_id': a['id'],
          'center_id': a['center_id'],
          'storage_bucket': 'audit-evidence',
          ...Map<String, dynamic>.from(params['p_metadata']),
          'upload_status': 'pending'
        };
        rows.add(r);
        bumpOfficial(a);
        return r;
      case 'finalize_audit_evidence':
        final r = _table('audit_evidence')
            .firstWhere((r) => r['id'] == params['p_id']);
        final a = _audit(r['audit_id']);
        _require(_canAudit(a['center_id']) && _editable(a));
        _require(fixtures.evidence.containsKey(r['storage_path']));
        r['upload_status'] = 'finalized';
        bumpOfficial(a);
        return r;
      case 'load_criterion_proof':
        final a = _audit(params['p_audit_id']);
        _require(
            fixtures.simulation.permissions.canDiscussAudit(a['center_id']));
        final response = _table('audit_responses')
            .where((r) =>
                r['audit_id'] == a['id'] &&
                r['criterion_id'] == params['p_criterion_id'])
            .firstOrNull;
        final selfIds = _table('center_self_audits')
            .where((h) => h['participation_id'] == a['participation_id'])
            .map((h) => h['id'])
            .toSet();
        final selfResponses = _table('center_self_responses')
            .where((r) =>
                selfIds.contains(r['self_audit_id']) &&
                r['criterion_id'] == params['p_criterion_id'])
            .map((r) => r['id'])
            .toSet();
        return {
          'response_id': response?['id'],
          'self': _table('center_self_evidence')
              .where((e) =>
                  selfResponses.contains(e['self_response_id']) &&
                  e['removed_at'] == null)
              .toList(),
          'official': _table('audit_evidence')
              .where((e) =>
                  e['audit_id'] == a['id'] &&
                  (e['response_id'] == null ||
                      e['response_id'] == response?['id']))
              .toList(),
          'reviews': _table('audit_evidence_reviews')
              .where((r) => r['response_id'] == response?['id'])
              .toList()
        };
      case 'record_audit_evidence_review':
        final response = _table('audit_responses')
            .firstWhere((r) => r['id'] == params['p_response_id']);
        final a = _audit(response['audit_id']);
        _require(_canAudit(a['center_id']) && _editable(a));
        if (params['p_outcome'] != 'accepted' &&
            (params['p_note'] ?? '').trim().isEmpty) {
          throw StateError('KAFAA_PROOF_NOTE_REQUIRED');
        }
        final sources = Map<String, dynamic>.from(await _rpc(
            'load_criterion_proof', {
          'p_audit_id': a['id'],
          'p_criterion_id': response['criterion_id']
        }) as Map);
        final self = params['p_self_evidence_id'] != null;
        if (self == (params['p_audit_evidence_id'] != null) ||
            !(sources[self ? 'self' : 'official'] as List).any((e) =>
                e['id'] ==
                params[self ? 'p_self_evidence_id' : 'p_audit_evidence_id'])) {
          throw StateError('KAFAA_PROOF_SOURCE_MISMATCH');
        }
        final rows = _table('audit_evidence_reviews');
        final old = rows.where((r) => r['id'] == params['p_id']).firstOrNull;
        if (old != null) return old['id'];
        rows.add({
          'id': params['p_id'],
          'audit_id': a['id'],
          'response_id': response['id'],
          'self_evidence_id': params['p_self_evidence_id'],
          'audit_evidence_id': params['p_audit_evidence_id'],
          'outcome': params['p_outcome'],
          'note': params['p_note'],
          'reviewer_id': actorId,
          'reviewer_name': 'Sample reviewer',
          'reviewed_at': DateTime.now().toUtc().toIso8601String()
        });
        bumpOfficial(a);
        return params['p_id'];
      case 'validate_assessment_submission':
        final a = _audit(params['p_audit_id']);
        _require(_canAudit(a['center_id']));
        final team = _table('audit_team_members')
            .where((m) => m['audit_id'] == a['id'] && m['removed_at'] == null);
        final lead = team.where((m) => m['team_role'] == 'lead').firstOrNull;
        return {
          'audit_id': a['id'],
          'row_version': a['row_version'] ?? 1,
          'content_version': a['content_version'] ?? 1,
          'lead_user_id': lead?['user_id'],
          'issues': [
            if (!_editable(a)) {'code': 'locked'},
            if (a['evaluation_date'] == null) {'code': 'date'},
            if (team.isEmpty ||
                team.any((m) => (m['actual_job_title'] ?? '').trim().isEmpty))
              {'code': 'team'},
            if (lead?['user_id'] == null) {'code': 'lead'},
            for (final c in _table('assessment_criteria').where((c) =>
                c['template_id'] == a['template_id'] &&
                c['is_active'] != false &&
                c['excluded_from_total'] != true))
              if (!_table('audit_responses').any((r) =>
                  r['audit_id'] == a['id'] &&
                  r['criterion_id'] == c['id'] &&
                  (r['level'] != null || r['is_not_applicable'] == true)))
                {
                  'code': 'score',
                  'criterion_id': c['id'],
                  'criterion_code': c['code']
                }
          ]
        };
      case 'submit_assessment_evaluation':
        final a = _audit(params['p_audit_id']);
        _require(_canAudit(a['center_id']));
        if (a['status'] == 'submitted' &&
            a['signed_content_version'] == a['content_version']) {
          return a;
        }
        if ((a['row_version'] ?? 1) != params['p_expected_version']) {
          throw StateError('KAFAA_CONFLICT');
        }
        final pre = Map<String, dynamic>.from(
            await _rpc('validate_assessment_submission', params) as Map);
        if ((pre['issues'] as List).isNotEmpty) {
          throw StateError('KAFAA_SUBMISSION_INCOMPLETE');
        }
        if (params['p_signoff_version'] != 'kafaa-evaluation-v1') {
          throw StateError('KAFAA_SIGNOFF_REQUIRED');
        }
        if (pre['lead_user_id'] != actorId &&
            (!_directorate || (params['p_note'] ?? '').trim().isEmpty)) {
          throw StateError('KAFAA_LEAD_SIGNOFF_REQUIRED');
        }
        a['signed_off_by'] = actorId;
        a['signed_off_name'] = 'Sample reviewer';
        a['signed_off_at'] = DateTime.now().toIso8601String();
        a['signed_content_version'] = a['content_version'] ?? 1;
        a['signoff_version'] = params['p_signoff_version'];
        a['signoff_note'] = params['p_note'];
        formalSubmitting = true;
        try {
          await _rpc('set_assessment_audit_status',
              {'p_audit_id': a['id'], 'p_status': 'submitted'});
        } finally {
          formalSubmitting = false;
        }
        a['row_version'] = (a['row_version'] as int? ?? 1) + 1;
        return a;
      case 'load_audit_attribution':
        final a = _audit(params['p_audit_id']);
        _require(
            fixtures.simulation.permissions.canDiscussAudit(a['center_id']));
        return {
          'audit': a,
          'team': _table('audit_team_members')
              .where((m) => m['audit_id'] == a['id'] && m['removed_at'] == null)
              .toList()
        };
      case 'directorate_capabilities':
        return {
          'registry': _directorate,
          'review': _directorate,
          'discussion': true,
          'workflow_counts': true,
          'self_audit': true,
          'formal_signoff': true
        };
      case 'save_center':
        _require(_directorate);
        final id = params['p_id'] as String;
        final payload = Map<String, dynamic>.from(params['p_payload']);
        final c = _table('centers').where((c) => c['id'] == id).firstOrNull;
        if (c != null && payload.entries.every((e) => c[e.key] == e.value)) {
          return c;
        }
        if (c != null &&
            (c['row_version'] ?? 1) != params['p_expected_version']) {
          throw StateError('KAFAA_CONFLICT');
        }
        final row = {
          ...?c,
          ...payload,
          'id': id,
          'row_version': (c?['row_version'] as int? ?? 0) + 1,
          'is_active': c?['is_active'] ?? true
        };
        row['code'] = (row['code'] as String).trim().toUpperCase();
        if (_table('centers').any(
            (other) => other['id'] != id && other['code'] == row['code'])) {
          throw StateError('duplicate');
        }
        if (c == null) {
          _table('centers').add(row);
        } else {
          c.addAll(row);
        }
        return row;
      case 'set_center_active':
        _require(_directorate);
        final c =
            _table('centers').firstWhere((c) => c['id'] == params['p_id']);
        if ((c['row_version'] ?? 1) != params['p_expected_version']) {
          throw StateError('KAFAA_CONFLICT');
        }
        c['is_active'] = params['p_active'];
        c['row_version'] = (c['row_version'] as int? ?? 1) + 1;
        return c;
      case 'ensure_audit_discussion':
        final a = _table('audits').firstWhere(
            (a) => a['participation_id'] == params['p_participation_id']);
        _require(
            fixtures.simulation.permissions.canDiscussAudit(a['center_id']));
        final d = _table('audit_discussions')
            .where((d) => d['participation_id'] == a['participation_id'])
            .firstOrNull;
        if (d != null) return d['id'];
        final id = const Uuid().v4();
        _table('audit_discussions')
            .add({'id': id, 'participation_id': a['participation_id']});
        return id;
      case 'page_audit_messages':
        final d = _table('audit_discussions')
            .firstWhere((d) => d['id'] == params['p_discussion_id']);
        _require(_readable('audit_discussions', d));
        return _table('audit_messages')
            .where((m) =>
                m['discussion_id'] == d['id'] &&
                (params['p_before_at'] == null ||
                    (m['created_at'] as String)
                            .compareTo(params['p_before_at']) <
                        0))
            .toList()
            .reversed
            .take(50)
            .toList();
      case 'post_audit_message':
        final d = _table('audit_discussions')
            .firstWhere((d) => d['id'] == params['p_discussion_id']);
        _require(_readable('audit_discussions', d));
        final old = _table('audit_messages')
            .where((m) => m['id'] == params['p_id'])
            .firstOrNull;
        if (old != null) {
          if (old['body'] != params['p_body']) {
            throw StateError('KAFAA_RETRY_MISMATCH');
          }
          return old['id'];
        }
        _require(d['closed_at'] == null &&
            (params['p_directive'] != true || _directorate));
        _table('audit_messages').add({
          'id': params['p_id'],
          'discussion_id': d['id'],
          'audit_id': params['p_audit_id'],
          'criterion_id': params['p_criterion_id'],
          'reply_to_id': params['p_reply_to_id'],
          'body': params['p_body'],
          'author_name': 'Sample reviewer / مراجع تجريبي',
          'author_role': _directorate ? 'directorate' : 'auditor',
          'kind': params['p_directive'] == true ? 'directive' : 'comment',
          'created_at': DateTime.now().toUtc().toIso8601String()
        });
        return params['p_id'];
      case 'set_audit_discussion_closed':
        _require(_directorate);
        final d = _table('audit_discussions')
            .firstWhere((d) => d['id'] == params['p_id']);
        d['closed_at'] = params['p_closed'] == true
            ? DateTime.now().toUtc().toIso8601String()
            : null;
        return null;
      case 'load_audit_review':
        final a = _audit(params['p_audit_id']);
        _require(
            fixtures.simulation.permissions.canDiscussAudit(a['center_id']));
        return {
          'audit': {...a, 'row_version': a['row_version'] ?? 1},
          'summary': _summary(a),
          'responses': _table('audit_responses')
              .where((r) => r['audit_id'] == a['id'])
              .toList(),
          'evidence': _table('audit_evidence')
              .where((r) => r['audit_id'] == a['id'])
              .toList(),
          'team': _table('audit_team_members')
              .where((r) => r['audit_id'] == a['id'])
              .toList(),
          'ncrs':
              _table('ncrs').where((r) => r['audit_id'] == a['id']).toList(),
          'loaded_at': DateTime.now().toUtc().toIso8601String()
        };
      case 'review_assessment_audit':
        _require(_directorate);
        final a = _audit(params['p_audit_id']);
        final decision = params['p_decision'];
        final kind = switch (decision) {
          'approve' => 'approval_notice',
          'request_revisions' => 'revision_request',
          _ => 'review_started'
        };
        final prior = _table('audit_messages')
            .where((m) => m['decision_request_id'] == params['p_request_id'])
            .firstOrNull;
        if (prior != null) {
          if (prior['audit_id'] != a['id'] ||
              prior['kind'] != kind ||
              prior['body'] != params['p_note']) {
            throw StateError('KAFAA_RETRY_MISMATCH');
          }
          return a;
        }
        if ((a['row_version'] ?? 1) != params['p_expected_version']) {
          throw StateError('KAFAA_CONFLICT');
        }
        _require(['submitted', 'under_review'].contains(a['status']));
        if (decision == 'request_revisions' &&
            (params['p_note'] as String).trim().isEmpty) {
          throw StateError('Reason required');
        }
        a['status'] = switch (decision) {
          'approve' => 'approved',
          'request_revisions' => 'rejected',
          _ => 'under_review'
        };
        a['row_version'] = (a['row_version'] as int? ?? 1) + 1;
        final d = await _rpc('ensure_audit_discussion',
            {'p_participation_id': a['participation_id']});
        _table('audit_messages').add({
          'id': const Uuid().v4(),
          'discussion_id': d,
          'audit_id': a['id'],
          'decision_request_id': params['p_request_id'],
          'kind': kind,
          'body': params['p_note'],
          'author_name': 'Sample Directorate / المديرية التجريبية',
          'author_role': 'directorate',
          'created_at': DateTime.now().toUtc().toIso8601String()
        });
        return a;
      case 'join_assessment':
        _require(fixtures.simulation.permissions
            .canJoinCenter(params['p_center_id'] as String));
        return _join(
            params['p_session_id'] as String, params['p_center_id'] as String);
      case 'create_assessment_session':
        _require(
            _directorate && params['p_template_id'] == fixtures.templateId);
        final id = params['p_client_id'] as String;
        if (_table('assessment_sessions').any((s) => s['id'] == id)) return id;
        _table('assessment_sessions').add({
          'id': id,
          'template_id': fixtures.templateId,
          'title_en': params['p_title_en'],
          'title_ar': params['p_title_ar'],
          'cycle_label': params['p_cycle'],
          'period_frequency': params['p_frequency'],
          'period_start': params['p_start'],
          'period_end': params['p_end'],
          'period_key': '${fixtures.seedTime.year}-H2',
          'status': 'draft'
        });
        return id;
      case 'publish_assessment':
      case 'set_assessment_state':
        _require(_directorate);
        final session = _table('assessment_sessions')
            .firstWhere((s) => s['id'] == params['p_id']);
        session['status'] =
            name == 'publish_assessment' ? 'open' : params['p_status'];
        session['published_at'] ??= fixtures.seedTime.toIso8601String();
        session['due_at'] = params['p_due_at'];
        return null;
      case 'set_assessment_audit_status':
        final audit = _audit(params['p_audit_id'] as String);
        final next = AuditStatus.tryParse(params['p_status'] as String);
        if (next == AuditStatus.submitted && !formalSubmitting) {
          throw StateError('KAFAA_SIGNOFF_REQUIRED');
        }
        if (next == AuditStatus.approved || next == AuditStatus.rejected) {
          _require(_directorate && audit['status'] == 'submitted');
          if (next == AuditStatus.rejected &&
              (params['p_review_notes'] as String? ?? '').trim().isEmpty) {
            throw StateError('Review reason required');
          }
        } else {
          _require(next == AuditStatus.submitted &&
              _canAudit(audit['center_id'] as String) &&
              _editable(audit));
          if (_summary(audit)['answered_count'] != 4) {
            throw StateError('Complete sample scores');
          }
        }
        audit['status'] = next.wire;
        audit['review_notes'] = params['p_review_notes'];
        if (next == AuditStatus.submitted) {
          final self = _table('tester_self_submissions')
              .where((s) => s['audit_id'] == audit['id'])
              .firstOrNull;
          final headers = _table('center_self_audits')
              .where((h) =>
                  h['participation_id'] == audit['participation_id'] &&
                  h['status'] == 'submitted')
              .toList()
            ..sort(
                (a, b) => (b['version'] as int).compareTo(a['version'] as int));
          audit['self_audit_baseline_id'] ??= headers.firstOrNull?['id'];
          audit['submitted_at'] ??= DateTime.now().toIso8601String();
          audit['tester_self_baseline'] ??=
              self == null ? null : jsonDecode(jsonEncode(self));
          _createFindings(audit);
        }
        return null;
      default:
        throw const _Denied();
    }
  }

  void _createFindings(Map<String, dynamic> audit) {
    for (final response in _table('audit_responses')
        .where((r) => r['audit_id'] == audit['id'] && r['level'] != 'met')) {
      if (_table('ncrs').any((n) => n['response_id'] == response['id'])) {
        continue;
      }
      _table('ncrs').add({
        'id': const Uuid().v4(),
        'audit_id': audit['id'],
        'center_id': audit['center_id'],
        'response_id': response['id'],
        'criterion_id': response['criterion_id'],
        'title_en': 'Sample finding',
        'title_ar': 'ملاحظة تجريبية',
        'status': 'open',
        'severity': 'minor',
        'created_at': fixtures.seedTime.toIso8601String()
      });
    }
  }

  /// Draft self work and dialogue use a second, ephemeral preview queue.
  /// Lifecycle actions continue through RPC and require an online ACK.
  void saveLocal(String kind, String auditId, Map<String, dynamic> values) {
    lease.check();
    final audit = _audit(auditId);
    final center = audit['center_id'] as String;
    _require(_canRead(center));
    if (kind == 'self') {
      _require(fixtures.simulation.permissions.canPrepareSelfAudit(center) &&
          _editable(audit));
      _require(!fixtures.tables['tester_self_submissions']!
          .any((s) => s['audit_id'] == auditId));
      _require(_table('v_criterion_scale').any((o) =>
          o['id'] == values['scale_option_id'] &&
          o['criterion_id'] == values['criterion_id']));
    }
    if (kind == 'evidence') _require(_canAudit(center) && _editable(audit));
    if (kind == 'ncrEvidence') {
      _require(_table('ncrs')
          .any((n) => n['id'] == values['ncr_id'] && n['audit_id'] == auditId));
    }
    if (kind == 'team') {
      _require(_canAudit(center) && _editable(audit));
      if (['full_name', 'actual_job', 'responsibility']
          .any((key) => (values[key] as String? ?? '').trim().isEmpty)) {
        throw StateError('Required sample team fields');
      }
    }
    if (kind == 'message' && (values['body'] as String? ?? '').trim().isEmpty) {
      throw StateError('Required sample message');
    }
    if (!['self', 'team', 'message', 'evidence', 'ncrEvidence']
        .contains(kind)) {
      throw const _Denied();
    }
    final key = ['message', 'evidence', 'ncrEvidence'].contains(kind)
        ? const Uuid().v4()
        : '$kind:$auditId:${values['criterion_id'] ?? ''}';
    final change = {
      ...values,
      'kind': kind,
      'audit_id': auditId,
      'center_id': center
    };
    if (offline) {
      localChanges[key] = change;
    } else {
      _applyLocal(change);
      localChanges.remove(key);
      fixtures.localFailures.remove(key);
    }
  }

  void _applyLocal(Map<String, dynamic> change) {
    if (change['kind'] == 'evidence' || change['kind'] == 'ncrEvidence') {
      final id = const Uuid().v4();
      fixtures.evidence[id] = fixtures.sampleProof();
      final table =
          change['kind'] == 'evidence' ? 'audit_evidence' : 'ncr_evidence';
      _table(table).add({
        ...change,
        'id': id,
        'storage_bucket': 'sample',
        'storage_path': id,
        'file_name': 'SAMPLE-testing-mode.txt',
        'mime_type': 'text/plain',
        'size_bytes': fixtures.evidence[id]!.length,
        'uploaded_at': fixtures.seedTime.toIso8601String()
      });
      return;
    }
    final table = switch (change['kind']) {
      'self' => 'tester_self_responses',
      'team' => 'audit_team_members',
      _ => 'tester_messages'
    };
    final values = {...change, 'id': const Uuid().v4()};
    final rows = _table(table);
    if (change['kind'] != 'message') {
      rows.removeWhere((r) =>
          r['audit_id'] == change['audit_id'] &&
          r['criterion_id'] == change['criterion_id']);
    }
    rows.add(values);
  }

  void submitSelf(String auditId) {
    lease.check();
    if (offline) throw StateError('Reconnect to confirm');
    final audit = _audit(auditId);
    _require(fixtures.simulation.permissions
            .canPrepareSelfAudit(audit['center_id'] as String) &&
        _editable(audit));
    final rows = _table('tester_self_responses')
        .where((r) => r['audit_id'] == auditId)
        .toList();
    if (rows.length != 4 ||
        localChanges.values.any((c) => c['audit_id'] == auditId)) {
      throw StateError('Complete sample self-audit');
    }
    final submissions = _table('tester_self_submissions');
    if (!submissions.any((s) => s['audit_id'] == auditId)) {
      submissions.add(
          {'audit_id': auditId, 'responses': jsonDecode(jsonEncode(rows))});
    }
  }

  void reconnect() {
    lease.check();
    offline = false;
    for (final key in localChanges.keys.toList()) {
      final change = localChanges[key]!;
      // Repeat authorization after the simulated network comes back.
      try {
        saveLocal(
            change['kind'] as String, change['audit_id'] as String, change);
        localChanges.remove(key);
        fixtures.localFailures.remove(key);
      } on Object {
        fixtures.localFailures.update(key, (n) => n + 1, ifAbsent: () => 1);
      }
    }
  }

  @override
  void close() {
    lease.closed = true;
  }
}

class _Denied implements Exception {
  const _Denied();
}
