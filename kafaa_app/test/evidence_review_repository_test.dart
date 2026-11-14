import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafaa_app/core/offline/local_store.dart';
import 'package:kafaa_app/data/repositories/evidence_review_repository.dart';
import 'package:kafaa_app/data/repositories/self_evidence_repository.dart';
import 'package:kafaa_app/data/models/evidence_review.dart';
import 'helpers/repository_harness.dart';

void main() {
  test(
      'known downloaded proof can queue a review offline; a pending rejection supersedes accepted display',
      () async {
    var offline = false;
    final h = RepositoryHarness((r) async {
      if (offline) throw const SocketException('offline');
      return jsonResponse({
        'response_id': 'r',
        'self': [],
        'official': [
          {
            'id': 'e',
            'audit_id': 'a',
            'file_name': 'x.pdf',
            'upload_status': 'finalized',
            'mime_type': 'application/pdf'
          }
        ],
        'reviews': [
          {
            'id': 'old',
            'audit_evidence_id': 'e',
            'outcome': 'accepted',
            'reviewed_at': '2026-01-01',
            'reviewer_name': 'Previous reviewer'
          }
        ]
      });
    });
    addTearDown(h.dispose);
    await h.ready();
    final repo = EvidenceReviewRepository(h.client, h.store, h.sync, h.audits,
        SelfEvidenceRepository(h.client, h.store, h.sync));
    const key = CriterionProofKey('a', 'c');
    final source = (await repo.load(key)).single;
    await expectLater(
        repo.record(key, source, responseId: 'r', outcome: 'accepted'),
        throwsStateError);
    await h.store.putCache('official.proof.download.e', {
      'file_bytes': base64Encode([1, 2, 3])
    });
    offline = true;
    await expectLater(
        repo.record(key, source,
            responseId: 'r', outcome: 'needs_clarification', note: ' '),
        throwsStateError);
    await repo.record(key, source,
        responseId: 'r', outcome: 'not_accepted', note: 'Please clarify');
    final reopened = (await repo.load(key)).single;
    expect(reopened.accepted, isFalse);
    expect(reopened.latest!.pending, isTrue);
    expect(reopened.latest!.note, 'Please clarify');
    expect(reopened.history, hasLength(2));
    expect(
        (await h.store.pending()).single.kind, OutboxKind.evidenceReviewAppend);
  });
  test(
      'finalized official upload retry does not touch bytes or replace Storage objects',
      () async {
    final requests = <String>[];
    final h = RepositoryHarness((r) async {
      requests.add(r.url.path);
      return jsonResponse({
        'id': 'e',
        'audit_id': 'a',
        'upload_status': 'finalized',
        'storage_bucket': 'audit-evidence',
        'storage_path': 'c/a/r/e.pdf',
        'file_name': 'e.pdf'
      });
    });
    addTearDown(h.dispose);
    await h.ready();
    await h.store.enqueue(OutboxKind.evidenceUpload, {
      'id': 'e',
      'audit_id': 'a',
      'storage_path': 'c/a/r/e.pdf',
      'file_name': 'e.pdf',
      'local_path': 'picker-file-no-longer-exists',
      'entity_key': 'proof:e'
    });
    await h.sync.sync();
    expect(await h.store.pending(), isEmpty);
    expect(requests.any((p) => p.contains('/storage/')), isFalse);
    expect(await h.store.readCache<Object>('official.evidence.accepted.a'),
        isNotNull);
  });
  test('denied authoritative access never falls back to a cached private proof',
      () async {
    final h = RepositoryHarness((_) async =>
        jsonResponse({'code': '42501', 'message': 'denied'}, status: 403));
    addTearDown(h.dispose);
    await h.store.putCache(
        'official.proof.a.c', {'self': [], 'official': [], 'reviews': []});
    final repo = EvidenceReviewRepository(h.client, h.store, h.sync, h.audits,
        SelfEvidenceRepository(h.client, h.store, h.sync));
    await expectLater(
        repo.load(const CriterionProofKey('a', 'c')), throwsA(anything));
  });
  test(
      'accepted-count cache never revives an older acceptance after a server rejection',
      () async {
    var offline = false;
    final h = RepositoryHarness((r) async {
      if (offline) throw const SocketException('offline');
      return jsonResponse([
        {
          'criterion_id': 'c',
          'source_id': 'e',
          'outcome': 'not_accepted',
          'finalized': true,
          'reviewed_at': '2026-11-14T12:00:00Z'
        }
      ]);
    });
    addTearDown(h.dispose);
    await h.store.putCache('official.reviews.accepted.a', {
      'old': {
        'id': 'old',
        'criterion_id': 'c',
        'audit_evidence_id': 'e',
        'outcome': 'accepted',
        'reviewed_at': '2026-11-14T11:00:00Z'
      }
    });
    final repo = EvidenceReviewRepository(h.client, h.store, h.sync, h.audits,
        SelfEvidenceRepository(h.client, h.store, h.sync));
    expect(await repo.acceptedCounts('a'), isEmpty);
    offline = true;
    expect(await repo.acceptedCounts('a'), isEmpty);
  });
}
