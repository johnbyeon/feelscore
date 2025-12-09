import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'package:provider/provider.dart';
import 'providers/refresh_provider.dart';
import 'category_detail_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ApiService _apiService = ApiService();
  List<CategoryStat> _categoryStats = [];
  bool _isLoading = true;
  String? _errorMessage;
  final Set<int> _expandedCategoryIds = {};

  void _toggleExpanded(int id) {
    setState(() {
      if (_expandedCategoryIds.contains(id)) {
        _expandedCategoryIds.remove(id);
      } else {
        _expandedCategoryIds.add(id);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final refreshProvider = context.watch<RefreshProvider>();
    if (refreshProvider.shouldRefreshHome) {
      // 빌드 사이클 중에 상태 변경을 피하기 위해 미세한 지연 후 실행
      Future.microtask(() {
        _fetchStats();
        context.read<RefreshProvider>().consumeRefreshHome();
      });
    }
  }

  Future<void> _fetchStats() async {
    try {
      final data = await _apiService.getHomeStats();
      setState(() {
        _categoryStats = data
            .map((json) => CategoryStat.fromJson(json))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load stats: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_errorMessage != null) {
      return Scaffold(body: Center(child: Text(_errorMessage!)));
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Search Bar
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search emotions...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[200],
                ),
              ),
              const SizedBox(height: 20),
              // Category List
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _fetchStats,
                  child: ListView.builder(
                    itemCount: _categoryStats.length,
                    itemBuilder: (context, index) {
                      final category = _categoryStats[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              CategoryDetailPage(
                                                categoryId: category.categoryId,
                                                categoryName: category.name,
                                              ),
                                        ),
                                      );
                                    },
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(12),
                                      bottomLeft: Radius.circular(12),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16.0,
                                        vertical: 16.0,
                                      ), // Padding matched to look good
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            category.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                            ),
                                          ),
                                          if (category.dominantEmotion != null)
                                            Text(
                                              '${_getEmotionText(category.dominantEmotion!)}(${category.score})',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: _getScoreColor(
                                                  category.score,
                                                ),
                                              ),
                                            )
                                          else
                                            Text(
                                              '(${category.score})',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    _expandedCategoryIds.contains(
                                          category.categoryId,
                                        )
                                        ? Icons.expand_less
                                        : Icons.expand_more,
                                    color: Colors.grey[600],
                                  ),
                                  onPressed: () =>
                                      _toggleExpanded(category.categoryId),
                                ),
                              ],
                            ),
                            if (_expandedCategoryIds.contains(
                              category.categoryId,
                            ))
                              ...category.children.map((child) {
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            CategoryDetailPage(
                                              categoryId: child.categoryId,
                                              categoryName: child.name,
                                            ),
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16.0,
                                      vertical: 12.0,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            const SizedBox(
                                              width: 16,
                                            ), // Indentation
                                            Text(
                                              child.name,
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.grey[700],
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (child.dominantEmotion != null)
                                          Text(
                                            '${_getEmotionText(child.dominantEmotion!)}(${child.score})',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: _getScoreColor(
                                                child.score,
                                              ),
                                            ),
                                          )
                                        else
                                          Text(
                                            '(${child.score})',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            if (_expandedCategoryIds.contains(
                              category.categoryId,
                            ))
                              const SizedBox(height: 8),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 100) return Colors.green;
    if (score >= 50) return Colors.orange;
    return Colors.red; // 점수 기준은 임의로 조정 가능
  }

  String _getEmotionText(String emotion) {
    switch (emotion) {
      case 'JOY':
        return '기쁨';
      case 'SADNESS':
        return '슬픔';
      case 'ANGER':
        return '분노';
      case 'FEAR':
        return '두려움';
      case 'DISGUST':
        return '혐오';
      case 'SURPRISE':
        return '놀람';
      case 'CONTEMPT':
        return '경멸';
      case 'LOVE':
        return '사랑';
      case 'ANTICIPATION':
        return '기대';
      case 'TRUST':
        return '신뢰';
      case 'NEUTRAL':
        return '중립';
      default:
        return emotion;
    }
  }
}

class CategoryStat {
  final int categoryId;
  final String name;
  final String? dominantEmotion;
  final int score;
  final List<CategoryStat> children;

  CategoryStat({
    required this.categoryId,
    required this.name,
    this.dominantEmotion,
    required this.score,
    required this.children,
  });

  factory CategoryStat.fromJson(Map<String, dynamic> json) {
    return CategoryStat(
      categoryId: json['categoryId'],
      name: json['name'],
      dominantEmotion: json['dominantEmotion'],
      score: json['score'] ?? 0,
      children:
          (json['children'] as List<dynamic>?)
              ?.map((e) => CategoryStat.fromJson(e))
              .toList() ??
          [],
    );
  }
}
