import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class CategoryService {
  final ApiService _apiService = ApiService();
  static const String _versionKey = 'category_version';
  static const String _dataKey = 'category_data';

  // 앱 시작 시 호출: 버전 확인 및 업데이트
  Future<void> checkAndFetchCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localVersion = prefs.getInt(_versionKey) ?? 0;

      final serverVersionInfo = await _apiService.getLatestCategoryVersion();
      final serverVersion = serverVersionInfo['version'] as int;

      if (serverVersion > localVersion) {
        // print('New category version found: $serverVersion (Local: $localVersion)');
        final categories = await _apiService.getCategoriesByVersion(
          serverVersion,
        );

        await prefs.setInt(_versionKey, serverVersion);
        await prefs.setString(_dataKey, jsonEncode(categories));
        // print('Category data updated to version $serverVersion');
      } else {
        // print('Category data is up to date (Version: $localVersion)');
      }
    } catch (e) {
      // print('Failed to check/fetch categories: $e');
    }
  }

  // 로컬에 저장된 카테고리 목록 반환
  Future<List<dynamic>> getCachedCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final dataString = prefs.getString(_dataKey);
    if (dataString != null) {
      return jsonDecode(dataString);
    }
    return [];
  }

  // 검색어에 맞는 카테고리 필터링 (재귀적으로 검색)
  Future<List<Map<String, dynamic>>> searchCategories(String query) async {
    if (query.isEmpty) return [];

    final allCategories = await getCachedCategories();
    final List<Map<String, dynamic>> results = [];

    void searchRecursive(List<dynamic> categories) {
      for (var category in categories) {
        final name = category['name'].toString();
        // 검색어와 일치하는지 확인 (대소문자 무시)
        if (name.toLowerCase().contains(query.toLowerCase())) {
          results.add({
            'id': category['id'],
            'name': name,
            'depth': category['depth'],
          });
        }

        // 자식 카테고리 검색
        if (category['children'] != null) {
          searchRecursive(category['children']);
        }
      }
    }

    searchRecursive(allCategories);
    return results;
  }
}
