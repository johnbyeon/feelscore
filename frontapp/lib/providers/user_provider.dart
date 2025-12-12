import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // import 추가
import 'package:flutter/foundation.dart'; // kDebugMode import 추가
import '../services/fcm_service.dart';

class UserProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  bool _isLoggedIn = false;
  String? _userId;
  String? _nickname;
  String? _profileImageUrl;
  String? _accessToken;
  String? _refreshToken; // Add refreshToken field

  bool get isLoggedIn => _isLoggedIn;
  String? get userId => _userId;
  String? get nickname => _nickname;
  String? get profileImageUrl => _profileImageUrl;
  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken; // Getter

  Future<void> checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    final nickname = prefs.getString('nickname');
    final profileImageUrl = prefs.getString('profileImageUrl');
    final accessToken = prefs.getString('accessToken');
    final refreshToken = prefs.getString('refreshToken'); // Load refreshToken

    if (userId != null && accessToken != null) {
      _isLoggedIn = true;
      _userId = userId;
      // Update FCMService with current user ID
      FCMService().setCurrentUserId(_userId);
      _nickname = nickname;
      _profileImageUrl = profileImageUrl;
      _accessToken = accessToken;
      _refreshToken = refreshToken;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    try {
      final data = await _apiService.login(email, password);
      _userId = data['id'].toString();
      _nickname = data['nickname'];
      _profileImageUrl = data['profileImageUrl'];
      _accessToken = data['access_token'];
      _refreshToken = data['refresh_token']; // Get refresh token from response
      _isLoggedIn = true;

      // Update FCMService with current user ID
      FCMService().setCurrentUserId(_userId);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userId', _userId!);
      await prefs.setString('nickname', _nickname!);
      await prefs.setString('accessToken', _accessToken!);
      if (_refreshToken != null) {
        await prefs.setString(
          'refreshToken',
          _refreshToken!,
        ); // Save refreshToken
      }
      if (_profileImageUrl != null) {
        await prefs.setString('profileImageUrl', _profileImageUrl!);
      } else {
        await prefs.remove('profileImageUrl');
      }

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

  Future<void> updateProfileImage(String profileImageUrl) async {
    try {
      await _apiService.updateUserProfileImage(profileImageUrl);
      _profileImageUrl = profileImageUrl;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profileImageUrl', profileImageUrl);

      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  // Method to update tokens from ApiService refresh
  Future<void> setTokens(String newAccessToken, String? newRefreshToken) async {
    _accessToken = newAccessToken;
    if (newRefreshToken != null) {
      _refreshToken = newRefreshToken;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('accessToken', newAccessToken);
    if (newRefreshToken != null) {
      await prefs.setString('refreshToken', newRefreshToken);
    }
    notifyListeners();
  }

  Future<void> logout() async {
    _isLoggedIn = false;
    _userId = null;
    _nickname = null;
    _profileImageUrl = null;
    _accessToken = null;
    _refreshToken = null;

    // Clear FCMService user ID
    FCMService().setCurrentUserId(null);

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    notifyListeners();
  }
}
