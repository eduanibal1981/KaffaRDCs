import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase/supabase_providers.dart';
import '../../core/offline/local_store.dart';
import '../../core/offline/network_error.dart';

final directorateCapabilitiesProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  try {
    final caps = Map<String, dynamic>.from(
        await watchSessionClient(ref).rpc('directorate_capabilities'));
    await ref
        .read(localStoreProvider)
        .putCache('directorate.capabilities', caps);
    return caps;
  } on PostgrestException catch (e) {
    if (e.code == 'PGRST202' || e.code == '42883') return {};
    rethrow;
  } catch (e) {
    if (!isNetworkError(e)) rethrow;
    final caps = await ref
        .read(localStoreProvider)
        .readCache<Map<String, dynamic>>('directorate.capabilities');
    if (caps == null) rethrow;
    return caps;
  }
});
