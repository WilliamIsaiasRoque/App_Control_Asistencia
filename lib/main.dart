import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/auth/remember_session_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_PE');

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
