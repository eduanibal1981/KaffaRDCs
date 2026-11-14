class CriterionProofKey {
  const CriterionProofKey(this.auditId, this.criterionId);
  final String auditId, criterionId;
  @override
  bool operator ==(Object other) =>
      other is CriterionProofKey &&
      auditId == other.auditId &&
      criterionId == other.criterionId;
  @override
  int get hashCode => Object.hash(auditId, criterionId);
}

class EvidenceReview {
  EvidenceReview(this.raw);
  final Map<String, dynamic> raw;
  String get id => raw['id'];
  String get outcome => raw['outcome'];
  String? get note => raw['note'];
  String get reviewer => raw['reviewer_name'] ?? '';
  bool get pending => raw['local_pending'] == true;
}

class CriterionProof {
  CriterionProof(
      {required this.raw, required this.self, required this.history});
  final Map<String, dynamic> raw;
  final bool self;
  final List<EvidenceReview> history;
  String get id => raw['id'];
  String get fileName => raw['file_name'] ?? '';
  bool get finalized =>
      (raw[self ? 'upload_state' : 'upload_status'] ?? 'finalized') ==
          'finalized' &&
      raw['local_pending'] != true;
  EvidenceReview? get latest => history.isEmpty ? null : history.first;
  bool get accepted =>
      finalized && latest?.outcome == 'accepted' && latest?.pending == false;
}
