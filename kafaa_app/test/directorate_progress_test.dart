import 'package:flutter_test/flutter_test.dart';
import 'package:kafaa_app/data/models/assessment_session.dart';
import 'package:kafaa_app/features/directorate/directorate_dashboard_controller.dart';
import 'package:kafaa_app/core/routing/app_router.dart';
import 'package:kafaa_app/features/auth/session.dart';
import 'package:kafaa_app/data/models/center.dart';
import 'package:kafaa_app/data/models/primitives.dart';

void main() {
  test(
      'workflow buckets partition retained membership; official correction result stays separate',
      () {
    final rows = <Map<String, dynamic>>[
      {'joined_at': null},
      {'joined_at': '2026-11-01', 'status': 'draft', 'answered_count': 0},
      {
        'joined_at': '2026-11-01',
        'status': 'draft',
        'answered_count': 2,
        'official_audit_id': 'old-approved',
        'center_active': false
      },
      for (final s in [
        'rejected',
        'submitted',
        'under_review',
        'approved',
        'archived'
      ])
        {'joined_at': '2026-11-01', 'status': s},
    ];
    final data = DirectorateCampaign(
        AssessmentSession.fromMap({'id': 'campaign'}),
        rows.map(AssessmentParticipation.fromMap).toList(),
        DateTime.now());
    expect(data.buckets.values.every((n) => n == 1), true);
    expect(data.buckets.values.reduce((a, b) => a + b), rows.length);
    expect(data.approvedResults, 1);
  });
  for (final role in [AppRole.viewer, AppRole.centerManager, AppRole.auditor]) {
    test('${role.wire} cannot enter directorate or review URLs', () {
      final p = Permissions([RoleGrant(role: role, centerId: 'one')]);
      for (final path in [
        '/directorate',
        '/directorate/centers',
        '/assessments/campaign/progress',
        '/audits/audit/review'
      ]) {
        expect(
            roleRouteRedirect(path, p, actual: p, preview: false), Routes.home);
      }
    });
  }
}
