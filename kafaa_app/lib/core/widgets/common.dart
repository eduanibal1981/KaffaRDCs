import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n_extensions.dart';
import '../theme/kafaa_colors.dart';
import '../theme/kafaa_theme.dart';

/// Padded, titled card used across every screen so density stays uniform.
class KafaaCard extends StatelessWidget {
  const KafaaCard({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.accent,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null || leading != null || trailing != null) ...[
            Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 12)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (title != null)
                        Text(title!, style: theme.textTheme.titleMedium),
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            subtitle!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );

    final card = Card(
      shape: accent == null
          ? null
          : RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(KafaaTheme.radius),
              side: BorderSide(
                  color: accent!.withValues(alpha: 0.35), width: 1.5),
            ),
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(KafaaTheme.radius),
              child: content,
            ),
    );

    return card;
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(4, 24, 4, 12),
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          if (action != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ),
    );
  }
}

/// Small coloured pill for statuses, levels and risk ratings.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.dense = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 13 : 15, color: color),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: dense ? 12 : 13,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single headline number with a label — the building block of the
/// overview rows.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.icon,
    this.color,
    this.onTap,
  });

  final String value;
  final String label;
  final IconData? icon;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.primary;

    return Semantics(
      button: onTap != null,
      label: '$label: $value',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KafaaTheme.radius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(KafaaTheme.radius),
            border: Border.all(color: c.withValues(alpha: 0.18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: c, size: 22),
                const SizedBox(height: 10),
              ],
              ExcludeSemantics(
                child: Text(
                  value,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(color: c, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 2),
              ExcludeSemantics(
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loading / empty / error
// ---------------------------------------------------------------------------

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            message ?? context.l10n.loading,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.title,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final IconData icon;
  final String? title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 20),
            Text(
              title ?? context.l10n.emptyTitle,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final message = describeError(context, error);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                size: 44, color: KafaaColors.danger),
            const SizedBox(height: 16),
            Text(l10n.errorTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.actionRetry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Turns a raw exception into something a nurse or manager can act on.
String describeError(BuildContext context, Object error) {
  final l10n = context.l10n;
  final text = error.toString().toLowerCase();

  final auditorErrors = <String, String>{
    'kafaa_team_name_job_required': l10n.auditTeamNameJobRequired,
    'kafaa_team_duplicate_user': l10n.auditTeamDuplicateUser,
    'audit_team_members_audit_id_user_id_key': l10n.auditTeamDuplicateUser,
    'kafaa_lead_account_required': l10n.auditTeamLeadRequired,
    'kafaa_team_account_invalid': l10n.auditTeamLeadRequired,
    'kafaa_proof_note_required': l10n.auditProofNoteRequired,
    'kafaa_proof_source_mismatch': l10n.auditProofSourceMismatch,
    'kafaa_signed_content_conflict': l10n.auditSignedContentConflict,
    'kafaa_signoff_required': l10n.auditSignoffLeadOnly,
    'kafaa_lead_signoff_required': l10n.auditSignoffLeadOnly,
    'kafaa_official_locked': l10n.assessmentClosedReadOnly,
    'kafaa_legacy_response_reconciliation': l10n.auditLegacyQueue,
    'kafaa_submission_incomplete': l10n.auditSubmissionPending,
    'kafaa_submission_pending': l10n.auditSubmissionPending,
    'kafaa_reviewed_proof_immutable': l10n.auditProofImmutable,
    'kafaa_proof_immutable': l10n.auditProofImmutable,
  };
  for (final item in auditorErrors.entries) {
    if (text.contains(item.key)) return item.value;
  }
  if (text.contains('quota') ||
      text.contains('disk is full') ||
      text.contains('sqlite_full')) {
    return l10n.selfAuditStorageFull;
  }
  if (text.contains('joining is pending')) return l10n.syncReconnectToConfirm;
  if (text.contains('kafaa_self_frozen')) return l10n.selfAuditFrozen;
  if (text.contains('kafaa_self_unavailable')) return l10n.selfAuditUnavailable;
  if (text.contains('kafaa_self_unjoined')) return l10n.selfAuditUnjoined;
  if (text.contains('kafaa_self_incomplete')) {
    return l10n.selfAuditIncompleteError;
  }
  if (text.contains('kafaa_self_pending')) return l10n.selfAuditPending;
  if (text.contains('kafaa_proof_format')) return l10n.selfAuditProofFormat;
  if (text.contains('kafaa_proof_pending')) return l10n.selfAuditProofPending;
  if (text.contains('kafaa_proof_local_missing')) {
    return l10n.selfAuditProofMissing;
  }
  if (text.contains('kafaa_proof_not_downloaded')) {
    return l10n.evidenceNotDownloaded;
  }
  if (text.contains('kafaa_gap_no_official')) return l10n.gapNoOfficial;
  if (text.contains('kafaa_structure_mismatch')) {
    return l10n.assessmentStructureMismatch;
  }
  if (text.contains('kafaa_required_proof_missing')) {
    return l10n.reviewRequiredProofMissing;
  }
  if (text.contains('kafaa_review_incomplete')) return l10n.reviewIncomplete;
  if (text.contains('kafaa_conflict') || text.contains('40001')) {
    return l10n.syncConflict;
  }
  if (text.contains('kafaa_access_denied')) return l10n.errorPermission;
  if (text.contains('socketexception') ||
      text.contains('failed host lookup') ||
      text.contains('connection closed')) {
    return l10n.errorNetwork;
  }
  if (text.contains('row-level security') ||
      text.contains('permission denied') ||
      text.contains('42501')) {
    return l10n.errorPermission;
  }
  if (text.contains('not found') || text.contains('pgrst116')) {
    return l10n.errorNotFound;
  }
  return l10n.errorGeneric;
}

/// Consistent async rendering: spinner, friendly error, then content.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.value,
    required this.builder,
    this.onRetry,
    this.loading,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback? onRetry;
  final Widget? loading;

  @override
  Widget build(BuildContext context) => value.when(
        data: builder,
        loading: () => loading ?? const LoadingView(),
        error: (e, _) => ErrorView(error: e, onRetry: onRetry),
      );
}
