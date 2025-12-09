import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

class ApiService {
  // Android Emulator: 10.0.2.2, iOS Simulator: 127.0.0.1
  // static const String baseUrl = 'http://127.0.0.1:8080/api';
  
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:8080/api';
    if (Platform.isAndroid) return 'http://10.0.2.2:8080/api';
    return 'http://127.0.0.1:8080/api';
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

    final url = Uri.parse(
      '$baseUrl/s3/user/upload-presigned?originalFileName=$originalFileName&contentType=$contentType',
    );
    final response = await http.post(
      url,
      headers: {'Authorization': 'Bearer $token'},
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
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');

    if (token == null) {
      throw Exception('No access token found');
    }

    final url = Uri.parse('$baseUrl/v1/posts');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'content': content,
        'categoryId': categoryId,
        if (imageUrl != null) 'imageUrl': imageUrl,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Failed to create post: ${response.body}');
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
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');

    if (token == null) {
      throw Exception('No access token found');
    }

    final url = Uri.parse(
      '$baseUrl/v1/posts/user/$userId?page=$page&size=$size&sort=createdAt,desc',
    );
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Failed to get user posts: ${response.body}');
    }
  }

  Future<void> updateFcmToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('accessToken');

    if (accessToken == null) {
      throw Exception('No access token found');
    }

    final url = Uri.parse('$baseUrl/user/fcm-token');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({'token': token}),
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
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');

    if (token == null) {
      throw Exception('No access token found');
    }

    final url = Uri.parse(
      '$baseUrl/v1/posts/category/$categoryId?page=$page&size=$size&sort=createdAt,desc',
    );
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Failed to get category posts: ${response.body}');
    }
  }

  Future<List<dynamic>> getHomeStats() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');

    if (token == null) {
      throw Exception('No access token found');
    }

    final url = Uri.parse('$baseUrl/stats/home');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Failed to get home stats: ${response.body}');
    }
  }

  Future<void> updateUserProfileImage(String profileImageUrl) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');

    if (token == null) {
      throw Exception('No access token found');
    }

    final url = Uri.parse('$baseUrl/user/profile-image');
    final response = await http.patch(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'profileImageUrl': profileImageUrl}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update profile image: ${response.body}');
    }
  }

  Future<List<dynamic>> getFollowers(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');

    if (token == null) {
      throw Exception('No access token found');
    }

    final url = Uri.parse('$baseUrl/follows/$userId/followers');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Failed to get followers: ${response.body}');
    }
  }

  Future<List<dynamic>> getFollowings(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');

    if (token == null) {
      throw Exception('No access token found');
    }

    final url = Uri.parse('$baseUrl/follows/$userId/followings');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Failed to get followings: ${response.body}');
    }
  }

  Future<bool> toggleFollow(String targetUserId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');

    if (token == null) {
      throw Exception('No access token found');
    }

    final url = Uri.parse('$baseUrl/follows/$targetUserId');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

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
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');

    final url = Uri.parse('$baseUrl/posts/$postId/comments');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    final response = await http.get(url, headers: headers);

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
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');

    if (token == null) {
      throw Exception('No access token found');
    }

    final url = Uri.parse('$baseUrl/posts/$postId/comments');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'content': content}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Failed to create comment: ${response.body}');
    }
  }

  // Reactions (Empathy)
  Future<void> toggleReaction(String postId, String emotionType) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');

    if (token == null) {
      throw Exception('No access token found');
    }

    final url = Uri.parse('$baseUrl/posts/$postId/react');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'emotionType': emotionType}),
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

  Future<void> increasePostView(String postId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');

    final url = Uri.parse('$baseUrl/posts/$postId');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    // Call GET /posts/{id} triggers view count increase in backend
    final response = await http.get(url, headers: headers);

    if (response.statusCode != 200) {
      throw Exception('Failed to increase view count: ${response.body}');
    }
  }

  Future<void> toggleCommentReaction(
    String commentId,
    String emotionType,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');

    if (token == null) {
      throw Exception('No access token found');
    }

    final url = Uri.parse(
      '$baseUrl/posts/$commentId/comments/$commentId/react',
    ); // ERROR: Check Backend Controller path!
    // Backend CommentController path: @RequestMapping("/api/posts/{postId}/comments")
    // Post mapping: @PostMapping("/{commentId}/react")
    // So full URL is /api/posts/{postId}/comments/{commentId}/react
    // Wait, the backend logic for CommentController uses @RequestMapping("/api/posts/{postId}/comments").
    // But toggleReaction is @PostMapping("/{commentId}/react").
    // So path is /api/posts/{postId}/comments/{commentId}/react.
    // I need postId in toggleCommentReaction?
    // Let's check CommentController again.
    // YES. @RequestMapping("/api/posts/{postId}/comments")
    // So I need postId.
  }
>>>>>>> Stashed changes
}
