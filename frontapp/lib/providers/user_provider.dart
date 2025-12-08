import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // import 추가
import 'package:flutter/foundation.dart'; // kDebugMode import 추가

class UserProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  bool _isLoggedIn = false;
  String? _userId;
  String? _nickname;

  bool get isLoggedIn => _isLoggedIn;
  String? get userId => _userId;
  String? get nickname => _nickname;

  Future<void> checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    final nickname = prefs.getString('nickname');

    if (userId != null) {
      _isLoggedIn = true;
      _userId = userId;
      _nickname = nickname;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    try {
      final data = await _apiService.login(email, password);
      _userId = data['id'].toString();
      _nickname = data['nickname'];
      _isLoggedIn = true;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userId', _userId!);
      await prefs.setString('nickname', _nickname!);
      await prefs.setString('accessToken', data['access_token']);

      // 🔹 로그인 성공 후 FCM 토큰 서버로 전송
      try {
        final fcmToken = await FirebaseMessaging.instance.getToken();
        if (fcmToken != null) {
          await _apiService.updateFcmToken(fcmToken);
          if (kDebugMode) {
            print('FCM Token updated on server: $fcmToken');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('Failed to update FCM token: $e');
        }
      }

      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signup(String email, String password, String nickname) async {
    try {
      await _apiService.signup(email, password, nickname);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> logout() async {
    _isLoggedIn = false;
    _userId = null;
    _nickname = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    notifyListeners();
  }
}
