import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Existing journey tests enter a synthetic named auditor before scoring.
Future<void> registerTestAuditor(WidgetTester tester) async {
  await tester.pumpAndSettle();
  if (find.byKey(const ValueKey('audit-team-entry-form')).evaluate().isEmpty) {
    return;
  }
  await tester.enterText(
      find.byKey(const ValueKey('audit-team-name')), 'Sample Auditor');
  await tester.enterText(
      find.byKey(const ValueKey('audit-team-job')), 'Clinical auditor');
  final save = find.byKey(const ValueKey('audit-team-save'));
  await tester.ensureVisible(save);
  await tester.pumpAndSettle();
  await tester.tap(save);
  await tester.pumpAndSettle();
}
