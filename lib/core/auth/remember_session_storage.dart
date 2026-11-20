import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Uses Supabase's normal local session storage only when the user chose
/// "Mantener sesión iniciada" on the login screen.
class RememberSessionStorage extends LocalStorage {
  RememberSessionStorage({required this.storageKey});

  final String storageKey;
  final Future<SharedPreferences> _preferences =
      SharedPreferences.getInstance();
  late final SharedPreferencesLocalStorage _delegate =
      SharedPreferencesLocalStorage(persistSessionKey: storageKey);

  bool get _rememberSession =>
      (_cachedPreferences?.getBool('dk_remember_session')) ?? true;

  SharedPreferences? _cachedPreferences;

  @override
  Future<void> initialize() async {
    await _delegate.initialize();
    _cachedPreferences = await _preferences;
    if (!_rememberSession) await _delegate.removePersistedSession();
  }

  @override
  Future<bool> hasAccessToken() async {
    if (!_rememberSession) return false;
    return _delegate.hasAccessToken();
  }

  @override
  Future<String?> accessToken() async {
    if (!_rememberSession) return null;
    return _delegate.accessToken();
  }

  @override
  Future<void> removePersistedSession() => _delegate.removePersistedSession();

  @override
  Future<void> persistSession(String persistSessionString) async {
    if (_rememberSession) {
      await _delegate.persistSession(persistSessionString);
    } else {
      await _delegate.removePersistedSession();
    }
  }

  static Future<void> setRememberSession(bool remember) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('dk_remember_session', remember);
  }
}
