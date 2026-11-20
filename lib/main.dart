import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/auth/remember_session_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  final supabaseConfigured =
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

  if (supabaseConfigured) {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabasePublishableKey,
      authOptions: FlutterAuthClientOptions(
        localStorage: RememberSessionStorage(
          storageKey:
              'sb-${Uri.parse(supabaseUrl).host.split('.').first}-auth-token',
        ),
      ),
    );
  }

  runApp(ControlAsistenciaApp(supabaseConfigured: supabaseConfigured));
}
