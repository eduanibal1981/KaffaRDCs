import 'package:flutter_test/flutter_test.dart';
import 'package:kafaa_app/data/models/evidence_review.dart';

void main() {
  test(
      'attached proof is distinct from accepted finalized proof and pending rejection wins',
      () {
    final raw = {'id': 'e', 'upload_status': 'finalized'};
    expect(
        CriterionProof(raw: raw, self: false, history: []).accepted, isFalse);
    expect(
        CriterionProof(raw: raw, self: false, history: [
          EvidenceReview({'id': 'r', 'outcome': 'accepted'})
        ]).accepted,
        isTrue);
    expect(
        CriterionProof(raw: raw, self: false, history: [
          EvidenceReview(
              {'id': 'r2', 'outcome': 'not_accepted', 'local_pending': true}),
          EvidenceReview({'id': 'r', 'outcome': 'accepted'})
        ]).accepted,
        isFalse);
    expect(
        CriterionProof(
            raw: {...raw, 'upload_status': 'pending'},
            self: false,
            history: [
              EvidenceReview({'id': 'r', 'outcome': 'accepted'})
            ]).accepted,
        isFalse);
  });
}
