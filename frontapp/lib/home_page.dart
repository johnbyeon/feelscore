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
  final TextEditingController _searchController = TextEditingController();
  List<CategoryStat> _categoryStats = []; // Main stats from API
  List<CategoryStat> _allCategories = []; // Flattened list for searching
  List<CategoryStat> _displayedCategories =
      []; // Categories to show in main list
  List<CategoryStat> _searchSuggestions = []; // Current search matches
  bool _showSuggestions = false;

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

  String _selectedPeriod = 'ALL';

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final refreshProvider = context.watch<RefreshProvider>();
    if (refreshProvider.shouldRefreshHome) {
      Future.microtask(() {
        _fetchStats();
        context.read<RefreshProvider>().consumeRefreshHome();
      });
    }
  }

  Future<void> _fetchStats() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final data = await _apiService.getHomeStats(period: _selectedPeriod);
      final stats = data.map((json) => CategoryStat.fromJson(json)).toList();

      // Flatten for search
      final all = <CategoryStat>[];
      for (var cat in stats) {
        all.add(cat);
        if (cat.children.isNotEmpty) {
          all.addAll(cat.children);
        }
      }

      setState(() {
        _categoryStats = stats;
        _allCategories = all;
        if (!_showSuggestions && _searchController.text.isEmpty) {
          _displayedCategories = stats;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load stats: $e';
        _isLoading = false;
      });
    }
  }

  void _onPeriodChanged(String period) {
    if (_selectedPeriod == period) return;
    setState(() {
      _selectedPeriod = period;
    });
    _fetchStats();
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedPeriod == value;
    return GestureDetector(
      onTap: () => _onPeriodChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  void _onSearchChanged(String query) {
    if (query.isEmpty) {
      setState(() {
        _showSuggestions = false;
        _displayedCategories = _categoryStats;
      });
      return;
    }

    final lowerQuery = query.toLowerCase();
    final matches =
        _allCategories.where((cat) {
          return cat.name.toLowerCase().contains(lowerQuery);
        }).toList();

    setState(() {
      _searchSuggestions = matches;
      _showSuggestions = true;
    });
  }

  void _onSuggestionSelected(CategoryStat category) {
    setState(() {
      _searchController.text = category.name;
      _showSuggestions = false;
      _displayedCategories = [category];
    });
    FocusScope.of(context).unfocus();
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
              // Period Filter
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('전체', 'ALL'),
                    const SizedBox(width: 8),
                    _buildFilterChip('월간', 'MONTH'),
                    const SizedBox(width: 8),
                    _buildFilterChip('주간', 'WEEK'),
                    const SizedBox(width: 8),
                    _buildFilterChip('일간', 'DAY'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Search Bar
              TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: const TextStyle(
                  color: Colors.black87,
                ), // Updated text color
                decoration: InputDecoration(
                  hintText: 'Search emotions...',
                  hintStyle: const TextStyle(
                    color: Colors.grey,
                  ), // Updated hint color
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  suffixIcon:
                      _searchController.text.isNotEmpty
                          ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                              FocusScope.of(context).unfocus();
                            },
                          )
                          : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[200],
                ),
              ),
              const SizedBox(height: 20),

              // Content with Stack for Suggestions
              Expanded(
                child: Stack(
                  children: [
                    // Main List
                    RefreshIndicator(
                      onRefresh: _fetchStats,
                      child: ListView.builder(
                        itemCount: _displayedCategories.length,
                        itemBuilder: (context, index) {
                          final category = _displayedCategories[index];
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
                                              builder:
                                                  (context) =>
                                                      CategoryDetailPage(
                                                        categoryId:
                                                            category.categoryId,
                                                        categoryName:
                                                            category.name,
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
                                              if (category.dominantEmotion !=
                                                  null)
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
                                      onPressed:
                                          () => _toggleExpanded(
                                            category.categoryId,
                                          ),
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
                                            builder:
                                                (context) => CategoryDetailPage(
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

                    // Suggestions Overlay
                    if (_showSuggestions && _searchSuggestions.isNotEmpty)
                      Container(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        child: ListView.builder(
                          itemCount: _searchSuggestions.length,
                          itemBuilder: (context, index) {
                            final suggestion = _searchSuggestions[index];
                            return ListTile(
                              title: Text(suggestion.name),
                              trailing: Text(
                                'Score: ${suggestion.score}',
                                style: TextStyle(color: Colors.grey),
                              ),
                              onTap: () => _onSuggestionSelected(suggestion),
                            );
                          },
                        ),
                      ),
                  ],
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
