import 'package:supabase_flutter/supabase_flutter.dart';

/// Legacy Kafaa deployments store the period dates but do not yet expose the
/// optional frequency/key columns. Preserve the chosen structure, dates and
/// idempotency key when retrying that specific schema mismatch.
Future<List<Map<String, dynamic>>> writeAuditDraft(
  SupabaseClient client,
  Map<String, dynamic> payload, {
  bool replay = false,
}) async {
  Future<List<Map<String, dynamic>>> write(Map<String, dynamic> values) async {
    if (replay) {
      await client
          .from('audits')
          .upsert(values, onConflict: 'client_uuid', ignoreDuplicates: true);
      return [];
    }
    final row =
        await client.from('audits').insert(values).select('id').single();
    return [row];
  }

  try {
    return await write(payload);
  } on PostgrestException catch (error) {
    final missingPeriodColumn =
        (error.code == 'PGRST204' || error.code == '42703') &&
            error.message.contains('audits') &&
            (error.message.contains('period_frequency') ||
                error.message.contains('period_key'));
    if (!missingPeriodColumn) rethrow;
    return write(Map<String, dynamic>.of(payload)
      ..remove('period_frequency')
      ..remove('period_key'));
  }
}
