import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/notifications/push_device_service.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/domain/user_profile.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/attendance/presentation/personal_workspace_screen.dart';
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
  late final PushDeviceService _pushDevices = PushDeviceService(
    Supabase.instance.client,
  );
  String? _pushRegistrationStartedFor;
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
        if (_session?.user.id != state.session?.user.id) {
          _pushRegistrationStartedFor = null;
        }
        _session = state.session;
        _profileFutureUserId = null;
        _profileFuture = null;
        _sessionReady = true;
        _loadProfileForCurrentSession();
      });
    });
  }

  Future<void> _signOut() async {
    try {
      await _pushDevices.unregisterCurrentDevice();
    } catch (error) {
      debugPrint(
        'FCM: no se pudo desactivar el dispositivo al cerrar sesión: $error',
      );
    }
    await _auth.signOut();
  }

  void _schedulePushRegistration(String userId) {
    if (_pushRegistrationStartedFor == userId) return;
    _pushRegistrationStartedFor = userId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _session?.user.id != userId) return;
      unawaited(
        _pushDevices.registerForUser(userId).catchError((Object error) {
          debugPrint('FCM: no se pudo registrar el dispositivo: $error');
        }),
      );
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
            onAction: _signOut,
          );
        }
        final profile = snapshot.data!;
        if (!profile.isActive) {
          return _MessageScreen(
            title: 'Cuenta desactivada',
            message: 'Contacta al administrador de DK Partners.',
            actionLabel: 'Cerrar sesión',
            onAction: _signOut,
          );
        }
        _schedulePushRegistration(session.user.id);
        return PersonalWorkspaceScreen(profile: profile, onSignOut: _signOut);
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
