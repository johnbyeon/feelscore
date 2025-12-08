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
    String userId, {
    int page = 0,
    int size = 10,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');

    if (token == null) {
      throw Exception('No access token found');
    }

    final url = Uri.parse(
      '$baseUrl/v1/posts/user/$userId?page=$page&size=$size',
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
      throw Exception('Failed to get posts by user: ${response.body}');
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
}
