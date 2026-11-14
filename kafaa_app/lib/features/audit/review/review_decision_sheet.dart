import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../../../core/widgets/common.dart';
import '../../../data/repositories/audit_review_repository.dart';
import 'audit_review_controller.dart';

Future<void> showReviewDecision(
        BuildContext context, AuditReviewBundle bundle, String decision) =>
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) =>
            ReviewDecisionSheet(bundle: bundle, decision: decision));

class ReviewDecisionSheet extends ConsumerStatefulWidget {
  const ReviewDecisionSheet(
      {super.key, required this.bundle, required this.decision});
  final AuditReviewBundle bundle;
  final String decision;
  @override
  ConsumerState<ReviewDecisionSheet> createState() =>
      _ReviewDecisionSheetState();
}

class _ReviewDecisionSheetState extends ConsumerState<ReviewDecisionSheet> {
  final _note = TextEditingController();
  bool _busy = false, _conflict = false;
  String? _error;
  late AuditReviewBundle _bundle = widget.bundle;
  String _requestId = const Uuid().v4();
  String? _attemptNote;
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _decide() async {
    final text = _note.text.trim();
    if (widget.decision == 'request_revisions' && text.isEmpty) {
      setState(() => _error = context.l10n.reviewRevisionReason);
      return;
    }
    if (_attemptNote != null && _attemptNote != text) {
      _requestId = const Uuid().v4();
    }
    _attemptNote = text;
    setState(() => _busy = true);
    try {
      await ref
          .read(auditReviewControllerProvider(_bundle.summary.auditId))
          .review(_bundle, widget.decision, text, _requestId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.reviewDecisionConfirmed)));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _conflict = e.toString().contains('KAFAA_CONFLICT');
          _error =
              _conflict ? context.l10n.syncConflict : describeError(context, e);
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final label = switch (widget.decision) {
      'approve' => l.reviewApprove,
      'request_revisions' => l.reviewRequestRevisions,
      _ => l.reviewStart
    };
    return Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(20),
            children: [
              Text(label, style: Theme.of(context).textTheme.titleLarge),
              Text(context.pick(
                  _bundle.summary.centerNameEn, _bundle.summary.centerNameAr)),
              Text(
                  '${l.reviewVersion}: ${_bundle.summary.version} / ${_bundle.rowVersion}'),
              TextField(
                  controller: _note,
                  enabled: !_busy,
                  minLines: 2,
                  maxLines: 6,
                  maxLength: 8000,
                  decoration: InputDecoration(
                      labelText: widget.decision == 'request_revisions'
                          ? l.reviewRevisionReason
                          : l.reviewDecisionNote)),
              if (_error != null) Text(_error!),
              if (_conflict)
                OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            setState(() => _busy = true);
                            try {
                              final latest = await ref.read(
                                  auditReviewBundleProvider(
                                          _bundle.summary.auditId)
                                      .future);
                              if (mounted) {
                                setState(() {
                                  _bundle = latest;
                                  _conflict = false;
                                  _requestId = const Uuid().v4();
                                });
                              }
                            } catch (e) {
                              if (mounted) {
                                setState(
                                    () => _error = describeError(context, e));
                              }
                            } finally {
                              if (mounted) setState(() => _busy = false);
                            }
                          },
                    child: Text(l.actionRefresh)),
              const SizedBox(height: 12),
              FilledButton(
                  onPressed:
                      _busy || _conflict || !_bundle.canDecide ? null : _decide,
                  child: Text(label)),
              TextButton(
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  child: Text(l.actionCancel)),
            ]));
  }
}
