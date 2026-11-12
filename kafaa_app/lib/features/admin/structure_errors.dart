import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/l10n/l10n_extensions.dart';
import '../../core/widgets/common.dart';

String describeStructureError(BuildContext context, Object error) {
  if (error is PostgrestException) {
    if (error.code == '23505') return context.l10n.structuresDuplicate;
    if (error.message.contains('Add at least one scored item')) {
      return context.l10n.structuresEmpty;
    }
    if (error.message.contains('Each item needs')) {
      return context.l10n.structuresScaleInvalid;
    }
    if (error.message.contains('locked') ||
        error.message.contains('Only a draft')) {
      return context.l10n.structuresLocked;
    }
  }
  return describeError(context, error);
}
