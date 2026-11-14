import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/evidence_review.dart';
import '../../../data/repositories/evidence_review_repository.dart';

final auditEvidenceReviewProvider =
    Provider.family<EvidenceReviewRepository, CriterionProofKey>(
        (ref, key) => ref.watch(evidenceReviewRepositoryProvider));
