import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PushDeviceService {
  PushDeviceService(this._client);

  final SupabaseClient _client;
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  StreamSubscription<String>? _tokenRefreshSubscription;
  String? _activeUserId;
  String? _registeredUserId;
  String? _registrationUserId;
  Future<void>? _registrationFuture;

  bool get _isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> registerForUser(String userId) async {
    if (!_isSupportedPlatform || _registeredUserId == userId) return;
    if (_registrationUserId == userId && _registrationFuture != null) {
      return _registrationFuture!;
    }

    final task = _registerForUser(userId);
    _registrationUserId = userId;
    _registrationFuture = task;
    try {
      await task;
    } finally {
      if (_registrationUserId == userId) {
        _registrationUserId = null;
        _registrationFuture = null;
      }
    }
  }

  Future<void> _registerForUser(String userId) async {
    if (_client.auth.currentUser?.id != userId) return;
    await _tokenRefreshSubscription?.cancel();
    _activeUserId = userId;

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    final permissionGranted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
    if (!permissionGranted) {
      _activeUserId = null;
      return;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final apnsToken = await _messaging.getAPNSToken();
      if (apnsToken == null) {
        debugPrint('FCM: falta configurar APNs para registrar este iPhone.');
        _activeUserId = null;
        return;
      }
    }

    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) {
      _activeUserId = null;
      return;
    }

    await _saveToken(userId, token);
    _registeredUserId = userId;
    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen(
      (newToken) {
        if (_activeUserId != userId ||
            _client.auth.currentUser?.id != userId ||
            newToken.isEmpty) {
          return;
        }
        unawaited(
          _saveToken(userId, newToken).catchError((Object error) {
            debugPrint(
              'FCM: no se pudo actualizar el token del dispositivo: $error',
            );
          }),
        );
      },
      onError: (Object error) {
        debugPrint('FCM: error escuchando cambios del token: $error');
      },
    );
  }

  Future<void> _saveToken(String userId, String token) async {
    if (_client.auth.currentUser?.id != userId) return;
    final platform = defaultTargetPlatform == TargetPlatform.iOS
        ? 'ios'
        : 'android';
    await _client.rpc(
      'register_push_device',
      params: {
        'p_fcm_token': token,
        'p_platform': platform,
        'p_device_label': null,
      },
    );
  }

  Future<void> unregisterCurrentDevice() async {
    final userId = _client.auth.currentUser?.id;
    try {
      if (_isSupportedPlatform && userId != null) {
        final token = await _messaging.getToken();
        if (token != null && token.isNotEmpty) {
          await _client.rpc(
            'unregister_push_device',
            params: {'p_fcm_token': token},
          );
        }
      }
    } finally {
      await _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription = null;
      _activeUserId = null;
      _registeredUserId = null;
      _registrationUserId = null;
      _registrationFuture = null;
    }
  }
}
