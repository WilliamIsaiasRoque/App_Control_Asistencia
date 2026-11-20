import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'features/auth/data/auth_repository.dart';
import 'features/auth/domain/user_profile.dart';
import 'features/auth/presentation/login_screen.dart';
import 'theme/app_theme.dart';

class ControlAsistenciaApp extends StatelessWidget {
  const ControlAsistenciaApp({required this.supabaseConfigured, super.key});

  final bool supabaseConfigured;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Control de Asistencia DK Partners',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: supabaseConfigured ? const _AuthGate() : const _SetupScreen(),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  late final AuthRepository _auth = AuthRepository(Supabase.instance.client);
  StreamSubscription<AuthState>? _subscription;
  Session? _session;
  Future<UserProfile>? _profileFuture;
  String? _profileFutureUserId;
  bool _sessionReady = false;

  @override
  void initState() {
    super.initState();
    _session = Supabase.instance.client.auth.currentSession;
    _loadProfileForCurrentSession();
    _subscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      state,
    ) {
      if (!mounted) return;
      setState(() {
        _session = state.session;
        _profileFutureUserId = null;
        _profileFuture = null;
        _sessionReady = true;
        _loadProfileForCurrentSession();
      });
    });
  }

  void _loadProfileForCurrentSession() {
    final userId = _session?.user.id;
    if (userId == null) {
      _profileFutureUserId = null;
      _profileFuture = null;
      return;
    }
    if (_profileFutureUserId != userId || _profileFuture == null) {
      _profileFutureUserId = userId;
      _profileFuture = _auth.loadProfile(userId);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_sessionReady && _session == null) {
      return const _LoadingScreen(label: 'Conectando con tu cuenta…');
    }
    final session = _session;
    if (session == null) return const LoginScreen();

    final profileFuture = _profileFuture;
    if (profileFuture == null) {
      return const _LoadingScreen(label: 'Cargando tu perfil…');
    }
    return FutureBuilder<UserProfile>(
      key: ValueKey(session.user.id),
      future: profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _LoadingScreen(label: 'Cargando tu perfil…');
        }
        if (snapshot.hasError) {
          return _MessageScreen(
            title: 'No pudimos cargar tu perfil',
            message: 'Contacta al administrador y vuelve a intentarlo.',
            actionLabel: 'Cerrar sesión',
            onAction: _auth.signOut,
          );
        }
        final profile = snapshot.data!;
        if (!profile.isActive) {
          return _MessageScreen(
            title: 'Cuenta desactivada',
            message: 'Contacta al administrador de DK Partners.',
            actionLabel: 'Cerrar sesión',
            onAction: _auth.signOut,
          );
        }
        return _SignedInScreen(profile: profile, onSignOut: _auth.signOut);
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(label),
        ],
      ),
    ),
  );
}

class _SetupScreen extends StatelessWidget {
  const _SetupScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Text(
            'Falta la configuración local de Supabase. Ejecuta la app con '
            '--dart-define-from-file=supabase.local.json.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
  );
}

class _SignedInScreen extends StatelessWidget {
  const _SignedInScreen({required this.profile, required this.onSignOut});

  final UserProfile profile;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('DK PARTNERS'),
      actions: [
        IconButton(
          tooltip: 'Cerrar sesión',
          onPressed: onSignOut,
          icon: const Icon(Icons.logout),
        ),
      ],
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  size: 52,
                  color: AppColors.navy,
                ),
                const SizedBox(height: 20),
                Text(
                  'Bienvenido, ${profile.fullName}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  profile.role == 'admin' ? 'Administrador' : 'Trabajador',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 28),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Text(
                      'Tu cuenta está conectada. El siguiente paso será '
                      'mostrar aquí tu espacio de trabajo.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.ink),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _MessageScreen extends StatelessWidget {
  const _MessageScreen({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String message;
  final String actionLabel;
  final Future<void> Function() onAction;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shield_outlined, size: 48, color: AppColors.navy),
            const SizedBox(height: 20),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 22),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    ),
  );
}
