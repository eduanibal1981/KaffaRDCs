import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The single Supabase client. Everything that touches the network goes
/// through a repository that reads this provider, which keeps the swap to
/// another backend a matter of reimplementing the repositories.
final supabaseProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

final authStateChangesProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(supabaseProvider).auth.onAuthStateChange,
);

final currentUserProvider = Provider<User?>((ref) {
  // Re-read on every auth event so dependents rebuild on sign-in/out.
  ref.watch(authStateChangesProvider);
  return ref.watch(supabaseProvider).auth.currentUser;
});

/// Recreate repositories at account boundaries so their dependent providers
/// cannot retain the previous user's results on a shared device.
SupabaseClient watchSessionClient(Ref ref) {
  ref.watch(currentUserProvider.select((user) => user?.id));
  return ref.watch(supabaseProvider);
}
