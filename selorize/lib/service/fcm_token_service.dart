import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../repository/auth_repository.dart';

class FcmTokenService {
  static const String _userIdKey = 'logged_in_user_id';
  static const String _tokenKey = 'latest_fcm_token';
  static final AuthRepository _repo = AuthRepository();
  static StreamSubscription<String>? _tokenRefreshSubscription;

  static Future<void> initialize() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null && token.isNotEmpty) {
      debugPrint('============= FCM TOKEN =============');
      debugPrint(token);
      await _saveAndSyncToken(token);
    }

    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh
        .listen((token) async {
          debugPrint('============= FCM TOKEN REFRESHED =============');
          debugPrint(token);
          await _saveAndSyncToken(token);
        });
  }

  static Future<void> syncLatestToken(String userId) async {
    if (userId.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    var token = await FirebaseMessaging.instance.getToken() ?? '';
    token = token.isNotEmpty ? token : prefs.getString(_tokenKey) ?? '';
    if (token.isEmpty) return;

    await prefs.setString(_tokenKey, token);
    await _syncToken(userId: userId, token: token);
  }

  static Future<void> _saveAndSyncToken(String token) async {
    if (token.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);

    final userId = prefs.getString(_userIdKey) ?? '';
    if (userId.isEmpty) return;

    await _syncToken(userId: userId, token: token);
  }

  static Future<void> _syncToken({
    required String userId,
    required String token,
  }) async {
    try {
      await _repo.updateFcmToken(id: userId, fcmToken: token);
      debugPrint('FCM token synced for userId=$userId');
    } catch (e) {
      debugPrint('FCM token sync error: $e');
    }
  }
}
