import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/user_profile.dart';

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserProfile> loadProfile(String userId) async {
    final response = await _client
        .from('profiles')
        .select('id,full_name,role,is_active')
        .eq('id', userId)
        .maybeSingle();

    if (response == null) {
      throw const AuthException(
        'No se encontró el perfil de esta cuenta. Contacta al administrador.',
      );
    }
    return UserProfile.fromJson(response);
  }

  Future<void> signOut() => _client.auth.signOut();
}
