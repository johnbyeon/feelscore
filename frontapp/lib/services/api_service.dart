import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

class ApiService {
  // 1. Android Emulator: 10.0.2.2
  // 2. iOS Simulator: 127.0.0.1
  // 1. Android Emulator: 10.0.2.2
  // 2. iOS Simulator: 127.0.0.1
  // 3. Real Device: Use your computer's local IP or DDNS
  static const String? _manualIp =
      '192.168.0.32'; // Local IP found via ifconfig

  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:8080/api';
    if (_manualIp != null) return 'http://$_manualIp:8080/api';
    if (Platform.isAndroid) return 'http://10.0.2.2:8080/api';
    return 'http://127.0.0.1:8080/api';
  }

  // Helper: Refresh Token
  Future<String?> refreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString('refreshToken');
    if (refreshToken == null) return null;

    try {
      final url = Uri.parse('$baseUrl/auth/refresh');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newAccessToken = data['access_token'];
        // Note: Refresh response might not include new refresh token,
        // so we only update access token unless backend sends it.
        // Assuming backend only returns access_token based on our implementation.
        await prefs.setString('accessToken', newAccessToken);
        return newAccessToken;
      }
    } catch (e) {
      if (kDebugMode) print('Token Refresh Failed: $e');
    }
    return null;
  }

  // Helper: Authenticated Request with Retry
  Future<http.Response> _authorizedRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? extraHeaders,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('accessToken');

    if (token == null) throw Exception('No access token found');

    // Build URL & Headers
    // Path can be full URL or relative
    // If path starts with http, use it as is. Else append to baseUrl.
    final url =
        path.startsWith('http') ? Uri.parse(path) : Uri.parse('$baseUrl$path');

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }

    // Function to execute HTTP call
    Future<http.Response> performRequest(String currentToken) async {
      headers['Authorization'] = 'Bearer $currentToken';
      switch (method.toUpperCase()) {
        case 'POST':
          return http.post(
            url,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          );
        case 'GET':
          return http.get(url, headers: headers);
        case 'PUT':
          return http.put(
            url,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          );
        case 'DELETE':
          return http.delete(url, headers: headers);
        case 'PATCH':
          return http.patch(
            url,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          );
        default:
          throw Exception('Unsupported method');
      }
    }

    var response = await performRequest(token);

    // If 401, try refresh
    if (response.statusCode == 401) {
      final newToken = await refreshToken();
      if (newToken != null) {
        response = await performRequest(newToken);
      }
    }
    return response;
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final url = Uri.parse('$baseUrl/auth/login');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to login: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> signup(
    String email,
    String password,
    String nickname,
  ) async {
    final url = Uri.parse('$baseUrl/auth/join');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'nickname': nickname,
      }),
    );

    if (response.statusCode == 201) {
      // AuthController returns 201 Created
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to signup: ${response.body}');
    }
  }

  Future<Map<String, String>> getUploadPresignedUrl(
    String originalFileName,
    String contentType,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');

    if (token == null) {
      throw Exception('No access token found');
    }

    final response = await _authorizedRequest(
      'POST',
      '/s3/user/upload-presigned?originalFileName=$originalFileName&contentType=$contentType',
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      return {
        'presignedUrl': data['presignedUrl'],
        'objectKey': data['objectKey'],
      };
    } else {
      throw Exception('Failed to get presigned URL: ${response.body}');
    }
  }

  Future<String> getDownloadPresignedUrl(
    String objectKey, {
    int expirationMinutes = 5,
  }) async {
    final response = await _authorizedRequest(
      'GET',
      '/s3/user/download-presigned?objectKey=$objectKey&expirationMinutes=$expirationMinutes',
    );

    if (response.statusCode == 200) {
      return response.body; // Returns URL string
    } else {
      throw Exception('Failed to get download presigned URL: ${response.body}');
    }
  }

  Future<void> uploadFileToS3(
    String presignedUrl,
    XFile file,
    String contentType,
  ) async {
    final response = await http.put(
      Uri.parse(presignedUrl),
      headers: {'Content-Type': contentType},
      body: await file.readAsBytes(),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to upload file to S3: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> createPost(
    String content,
    int categoryId, {
    String? imageUrl,
  }) async {
    final response = await _authorizedRequest(
      'POST',
      '/v1/posts',
      body: {
        'content': content,
        'categoryId': categoryId,
        if (imageUrl != null) 'imageUrl': imageUrl,
      },
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Failed to create post: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> updatePost(
    int postId,
    String content,
    int categoryId, {
    String? imageUrl,
  }) async {
    final response = await _authorizedRequest(
      'PUT',
      '/v1/posts/$postId',
      body: {
        'content': content,
        'categoryId': categoryId,
        if (imageUrl != null) 'imageUrl': imageUrl,
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Failed to update post: ${response.body}');
    }
  }

  Future<void> deletePost(int postId) async {
    final response = await _authorizedRequest('DELETE', '/v1/posts/$postId');

    if (response.statusCode != 204) {
      throw Exception('Failed to delete post: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> getPostsByEmotion(
    String emotionType, {
    int page = 0,
    int size = 10,
  }) async {
    final response = await _authorizedRequest(
      'GET',
      '/v1/posts/emotion/$emotionType?page=$page&size=$size&sort=createdAt,desc',
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Failed to get posts by emotion: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> getLatestCategoryVersion() async {
    final url = Uri.parse('$baseUrl/category-versions/latest');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception(
        'Failed to get latest category version: ${response.body}',
      );
    }
  }

  Future<List<dynamic>> getCategoriesByVersion(int version) async {
    final url = Uri.parse('$baseUrl/category-versions/$version/categories');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Failed to get categories by version: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> getPostsByUser(
    int userId, {
    int page = 0,
    int size = 10,
  }) async {
    final response = await _authorizedRequest(
      'GET',
      '/v1/posts/user/$userId?page=$page&size=$size&sort=createdAt,desc',
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Failed to get user posts: ${response.body}');
    }
  }

  Future<void> updateFcmToken(String token) async {
    final response = await _authorizedRequest(
      'POST',
      '/user/fcm-token',
      body: {'token': token},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update FCM token: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> getPostsByCategory(
    int categoryId, {
    int page = 0,
    int size = 10,
  }) async {
    final response = await _authorizedRequest(
      'GET',
      '/v1/posts/category/$categoryId?page=$page&size=$size&sort=createdAt,desc',
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Failed to get category posts: ${response.body}');
    }
  }

  Future<List<dynamic>> getHomeStats({String period = 'ALL'}) async {
    final response = await _authorizedRequest(
      'GET',
      '/stats/home?period=$period',
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Failed to get home stats: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> getGlobalEmotionCount() async {
    final response = await _authorizedRequest('GET', '/v1/stats/global/count');

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Failed to get global emotion count: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> getGlobalEmotionScore() async {
    final response = await _authorizedRequest('GET', '/v1/stats/global/score');

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Failed to get global emotion score: ${response.body}');
    }
  }

  Future<List<dynamic>> getCategoryEmotionRanking(int categoryId) async {
    final response = await _authorizedRequest(
      'GET',
      '/v1/stats/categories/$categoryId/ranking',
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception(
        'Failed to get category emotion ranking: ${response.body}',
      );
    }
  }

  Future<void> updateUserProfileImage(String profileImageUrl) async {
    final response = await _authorizedRequest(
      'PATCH',
      '/user/profile-image',
      body: {'profileImageUrl': profileImageUrl},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update profile image: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> getMe() async {
    final response = await _authorizedRequest('GET', '/user/me');

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Failed to get user info: ${response.body}');
    }
  }

  Future<List<dynamic>> getFollowers(String userId) async {
    final response = await _authorizedRequest(
      'GET',
      '/follows/$userId/followers',
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Failed to get followers: ${response.body}');
    }
  }

  Future<List<dynamic>> getFollowings(String userId) async {
    final response = await _authorizedRequest(
      'GET',
      '/follows/$userId/followings',
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Failed to get followings: ${response.body}');
    }
  }

  Future<bool> toggleFollow(String targetUserId) async {
    final response = await _authorizedRequest('POST', '/follows/$targetUserId');

    if (response.statusCode == 200) {
      return response.body == 'true';
    } else {
      throw Exception('Failed to toggle follow: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> getFollowStats(String targetUserId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');

    // Token is optional for stats, but sending it allows checking isFollowing
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    final url = Uri.parse('$baseUrl/follows/$targetUserId/stats');
    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Failed to get follow stats: ${response.body}');
    }
  }

  // Comments
  Future<List<dynamic>> getComments(String postId) async {
    final response = await _authorizedRequest('GET', '/posts/$postId/comments');

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Failed to get comments: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> createComment(
    String postId,
    String content,
  ) async {
    final response = await _authorizedRequest(
      'POST',
      '/posts/$postId/comments',
      body: {'content': content},
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Failed to create comment: ${response.body}');
    }
  }

  // Reactions (Empathy)
  Future<void> toggleReaction(String postId, String emotionType) async {
    final response = await _authorizedRequest(
      'POST',
      '/posts/$postId/react',
      body: {'emotionType': emotionType},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to toggle reaction: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> getReactionStats(String postId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');

    final url = Uri.parse('$baseUrl/posts/$postId/react');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Failed to get reaction stats: ${response.body}');
    }
  }

  Future<void> toggleCommentReaction(
    int postId,
    int commentId,
    String emotionType,
  ) async {
    final response = await _authorizedRequest(
      'POST',
      '/posts/$postId/comments/$commentId/react',
      body: {'emotionType': emotionType},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to toggle comment reaction: ${response.body}');
    }
  }

  // ========== DM (Direct Message) APIs ==========

  /// Get DM inbox (list of threads)
  Future<List<dynamic>> getDmInbox() async {
    final response = await _authorizedRequest('GET', '/dm/inbox');

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    } else {
      throw Exception('Failed to get DM inbox: ${response.body}');
    }
  }

  /// Get DM requests (message requests from non-followers)
  Future<List<dynamic>> getDmRequests() async {
    final response = await _authorizedRequest('GET', '/dm/requests');

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    } else {
      throw Exception('Failed to get DM requests: ${response.body}');
    }
  }

  /// Get messages in a specific thread
  Future<List<dynamic>> getDmMessages(String threadId) async {
    final response = await _authorizedRequest(
      'GET',
      '/dm/threads/$threadId/messages',
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      // Backend returns Page<DmMessageResponse>, so we extract 'content'
      if (data is Map<String, dynamic> && data.containsKey('content')) {
        return data['content'] as List<dynamic>;
      }
      // Fallback if it is a list (legacy)
      return data as List<dynamic>;
    } else {
      throw Exception('Failed to get DM messages: ${response.body}');
    }
  }

  /// Send a DM message
  /// If threadId is provided, sends to that thread.
  /// If receiverId is provided (and no threadId), creates or finds a thread with that user.
  Future<Map<String, dynamic>> sendDmMessage({
    String? receiverId,
    String? threadId,
    required String content,
  }) async {
    final body = <String, dynamic>{'content': content};
    if (receiverId != null) body['receiverId'] = int.parse(receiverId);
    if (threadId != null) body['threadId'] = int.parse(threadId);

    final response = await _authorizedRequest(
      'POST',
      '/dm/message',
      body: body,
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    } else {
      throw Exception('Failed to send DM message: ${response.body}');
    }
  }

  /// Accept a DM request
  Future<void> acceptDmRequest(String threadId) async {
    final response = await _authorizedRequest(
      'POST',
      '/dm/requests/$threadId/accept',
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to accept DM request: ${response.body}');
    }
  }

  /// Delete/reject a DM request
  Future<void> deleteDmRequest(String threadId) async {
    final response = await _authorizedRequest(
      'DELETE',
      '/dm/requests/$threadId',
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete DM request: ${response.body}');
    }
  }

  /// Hide a DM thread (leave conversation)
  Future<void> hideDmThread(String threadId) async {
    final response = await _authorizedRequest(
      'POST',
      '/dm/threads/$threadId/hide',
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to hide DM thread: ${response.body}');
    }
  }

  /// Leave a DM thread (permanently)
  Future<void> leaveDmThread(String threadId) async {
    final response = await _authorizedRequest(
      'DELETE',
      '/dm/threads/$threadId/leave',
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to leave DM thread: ${response.body}');
    }
  }

  /// Mark thread messages as read
  Future<void> markAsRead(String threadId) async {
    final response = await _authorizedRequest(
      'POST',
      '/dm/threads/$threadId/read',
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to mark as read: ${response.body}');
    }
  }

  // 차단하기
  Future<void> blockUser(String myUserId, String blockedUserId) async {
    final response = await _authorizedRequest(
      'POST',
      '/blocks/$blockedUserId?userId=$myUserId',
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to block user: ${response.body}');
    }
  }

  Future<void> unblockUser(String blockedUserId) async {
    final response = await _authorizedRequest(
      'DELETE',
      '/blocks/$blockedUserId',
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to unblock user: ${response.body}');
    }
  }

  Future<List<dynamic>> getBlockList() async {
    final response = await _authorizedRequest('GET', '/blocks');

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Failed to get block list: ${response.body}');
    }
  }
}
