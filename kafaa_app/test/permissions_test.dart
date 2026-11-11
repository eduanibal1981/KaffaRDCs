import 'package:flutter_test/flutter_test.dart';
import 'package:kafaa_app/data/models/center.dart';
import 'package:kafaa_app/data/models/primitives.dart';
import 'package:kafaa_app/features/auth/session.dart';

/// The database enforces authorisation independently through RLS; these
/// tests cover the client-side mirror that decides what the interface
/// offers, so the two cannot drift apart unnoticed.
void main() {
  const centreA = 'centre-a';
  const centreB = 'centre-b';

  Permissions perms(List<RoleGrant> grants) => Permissions(grants);

  group('Super admin', () {
    final admin = perms([const RoleGrant(role: AppRole.superAdmin)]);

    test('has full configuration authority', () {
      expect(admin.isSuperAdmin, isTrue);
      expect(admin.isDirectorate, isTrue);
      expect(admin.canConfigureTemplate, isTrue);
      expect(admin.canManageUsers, isTrue);
      expect(admin.canManageStaff, isTrue);
    });

    test('can read and audit every centre', () {
      expect(admin.canReadCenter(centreA), isTrue);
      expect(admin.canReadCenter(centreB), isTrue);
      expect(admin.canAuditCenter(centreA), isTrue);
      expect(admin.canApproveAudits, isTrue);
    });
  });

  group('Directorate', () {
    final directorate = perms([const RoleGrant(role: AppRole.directorate)]);

    test('sees everything and approves, but does not configure', () {
      expect(directorate.isDirectorate, isTrue);
      expect(directorate.canApproveAudits, isTrue);
      expect(directorate.canCompareAllCentres, isTrue);
      expect(directorate.canReadCenter(centreB), isTrue);
      expect(directorate.canConfigureTemplate, isFalse);
      expect(directorate.canManageUsers, isFalse);
    });

    test('has no single home centre, so it opens on the comparison', () {
      expect(directorate.homeCenterId, isNull);
    });
  });

  group('Auditor', () {
    final roaming = perms([const RoleGrant(role: AppRole.auditor)]);
    final scoped =
        perms([const RoleGrant(role: AppRole.auditor, centerId: centreA)]);

    test('a roaming auditor may audit any centre', () {
      expect(roaming.canAuditCenter(centreA), isTrue);
      expect(roaming.canAuditCenter(centreB), isTrue);
      expect(roaming.canRunAudits, isTrue);
    });

    test('a scoped auditor is confined to their centre', () {
      expect(scoped.canAuditCenter(centreA), isTrue);
      expect(scoped.canAuditCenter(centreB), isFalse);
      expect(scoped.canReadCenter(centreB), isFalse);
      expect(scoped.homeCenterId, centreA);
    });

    test('cannot approve their own work or change the checklist', () {
      expect(roaming.canApproveAudits, isFalse);
      expect(roaming.canConfigureTemplate, isFalse);
      expect(roaming.canManageStaff, isFalse);
    });

    test('may close a corrective action', () {
      expect(roaming.canCloseNcr, isTrue);
    });
  });

  group('Centre manager', () {
    final manager = perms(
        [const RoleGrant(role: AppRole.centerManager, centerId: centreA)]);

    test('is confined to their own centre', () {
      expect(manager.managesCenter(centreA), isTrue);
      expect(manager.managesCenter(centreB), isFalse);
      expect(manager.canReadCenter(centreA), isTrue);
      expect(manager.canReadCenter(centreB), isFalse);
      expect(manager.homeCenterId, centreA);
    });

    test('may manage staff and respond to findings', () {
      expect(manager.canManageStaff, isTrue);
      expect(manager.canRespondToNcr, isTrue);
      expect(manager.canExportReports, isTrue);
    });

    test('cannot audit, approve, close findings or compare all centres', () {
      expect(manager.canRunAudits, isFalse);
      expect(manager.canApproveAudits, isFalse);
      expect(manager.canCloseNcr, isFalse);
      expect(manager.canCompareAllCentres, isFalse);
      expect(manager.canConfigureTemplate, isFalse);
    });
  });

  group('No role', () {
    const none = Permissions.empty;

    test('an account without a grant can do nothing', () {
      expect(none.hasAnyRole, isFalse);
      expect(none.canReadCenter(centreA), isFalse);
      expect(none.canRunAudits, isFalse);
      expect(none.canRespondToNcr, isFalse);
      expect(none.canExportReports, isFalse);
      expect(none.primaryRole, isNull);
    });
  });

  group('Combined grants', () {
    final both = perms([
      const RoleGrant(role: AppRole.centerManager, centerId: centreA),
      const RoleGrant(role: AppRole.auditor, centerId: centreB),
    ]);

    test('each grant applies only to its own centre', () {
      expect(both.managesCenter(centreA), isTrue);
      expect(both.managesCenter(centreB), isFalse);
      expect(both.canAuditCenter(centreB), isTrue);
      expect(both.canAuditCenter(centreA), isFalse);
    });

    test('the strongest role is reported as primary', () {
      expect(both.primaryRole, AppRole.auditor);
    });

    test('the managed centre wins as the default home', () {
      // Managing a centre is a stronger claim on "your centre" than
      // auditing one, so the manager's centre is where the app opens.
      expect(both.homeCenterId, centreA);
    });

    test('managing two centres leaves no default, so it opens on the list', () {
      final twoCentres = perms([
        const RoleGrant(role: AppRole.centerManager, centerId: centreA),
        const RoleGrant(role: AppRole.centerManager, centerId: centreB),
      ]);
      expect(twoCentres.homeCenterId, isNull);
    });

    test('a roaming auditor has no home centre', () {
      expect(perms([const RoleGrant(role: AppRole.auditor)]).homeCenterId,
          isNull);
    });
  });
}
