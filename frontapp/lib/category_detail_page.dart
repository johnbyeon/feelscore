import 'dart:async';
import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'services/category_service.dart';
import 'widgets/post_card.dart';

class CategoryDetailPage extends StatefulWidget {
  final int categoryId;
  final String categoryName;
  final int categoryDepth; // 1: 최상위, 2: 하위
  final int? parentId; // 하위 카테고리일 경우 부모 ID

  const CategoryDetailPage({
    super.key,
    required this.categoryId,
    required this.categoryName,
    this.categoryDepth = 1,
    this.parentId,
  });

  @override
  State<CategoryDetailPage> createState() => _CategoryDetailPageState();
}

class _CategoryDetailPageState extends State<CategoryDetailPage> {
  final ApiService _apiService = ApiService();
  final CategoryService _categoryService = CategoryService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  // State
  List<dynamic> _posts = [];
  List<dynamic> _subcategories = [];
  List<dynamic> _topCategories = []; // 최상위 카테고리 목록
  bool _isLoading = false;
  bool _hasMore = true;
  bool _isSearching = false;
  bool _isDropdownExpanded = false;
  int _page = 0;
  final int _size = 10;
  String? _errorMessage;
  Timer? _debounce;

  // 현재 선택된 탭 (0: 전체, 1: 월간, 2: 주간, 3: 일간)
  int _selectedPeriodIndex = 0;
  final List<String> _periodTabs = ['전체', '월간', '주간', '일간'];

  @override
  void initState() {
    super.initState();
    _fetchPosts();
    _fetchSubcategories();
    _fetchTopCategories();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore &&
        !_isSearching) {
      _fetchPosts();
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (_searchController.text.trim().isNotEmpty) {
        _performSearch(_searchController.text.trim());
      } else {
        // 검색어가 비면 게시글 목록으로 복귀
        setState(() {
          _isSearching = false;
          _posts = [];
          _page = 0;
          _hasMore = true;
        });
        _fetchPosts();
      }
    });
  }

  Future<void> _fetchSubcategories() async {
    try {
      final children = await _apiService.getCategoryChildren(widget.categoryId);
      setState(() {
        _subcategories = children;
      });
    } catch (e) {
      print('Failed to fetch subcategories: $e');
    }
  }

  Future<void> _fetchTopCategories() async {
    try {
      if (widget.categoryDepth == 2 && widget.parentId != null) {
        // 하위 카테고리인 경우: 같은 부모 아래 형제 카테고리 가져오기
        final siblings = await _apiService.getCategoryChildren(
          widget.parentId!,
        );
        setState(() {
          _topCategories = siblings;
        });
      } else {
        // 최상위 카테고리인 경우: depth=1 카테고리만
        final categories = await _categoryService.getCachedCategories();
        final topOnly =
            categories
                .where((c) => c['depth'] == 1 || c['parentId'] == null)
                .toList();
        setState(() {
          _topCategories = topOnly;
        });
      }
    } catch (e) {
      print('Failed to fetch top categories: $e');
    }
  }

  void _showCategorySelector() {
    if (_topCategories.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '카테고리 선택',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(color: Colors.grey, height: 1),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _topCategories.length,
                  itemBuilder: (context, index) {
                    final cat = _topCategories[index];
                    final isSelected = cat['id'] == widget.categoryId;
                    return ListTile(
                      title: Text(
                        cat['name'] ?? '',
                        style: TextStyle(
                          color: isSelected ? Colors.blue : Colors.white,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing:
                          isSelected
                              ? const Icon(Icons.check, color: Colors.blue)
                              : null,
                      onTap: () {
                        Navigator.pop(context); // Close bottom sheet
                        if (!isSelected) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => CategoryDetailPage(
                                    categoryId: cat['id'],
                                    categoryName: cat['name'],
                                    categoryDepth: widget.categoryDepth,
                                    parentId: widget.parentId,
                                  ),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _fetchPosts() async {
    if (_isLoading || _isSearching) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _apiService.getPostsByCategory(
        widget.categoryId,
        page: _page,
        size: _size,
      );

      final List<dynamic> newPosts = response['content'];
      final bool last = response['last'];

      setState(() {
        _posts.addAll(newPosts);
        _isLoading = false;
        _page++;
        _hasMore = !last;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load posts: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isSearching = true;
      _isLoading = true;
      _posts = [];
    });

    try {
      final response = await _apiService.searchPosts(query, page: 0, size: 50);
      final List<dynamic> results = response['content'] ?? [];

      setState(() {
        _posts = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Search failed: $e';
        _isLoading = false;
      });
    }
  }

  void _navigateToSubcategory(int id, String name) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => CategoryDetailPage(
              categoryId: id,
              categoryName: name,
              categoryDepth: 2,
              parentId: widget.categoryId, // 현재 카테고리가 부모
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: GestureDetector(
          onTap: _showCategorySelector,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.categoryName,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.keyboard_arrow_down,
                color: Colors.white,
                size: 20,
              ),
            ],
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 1. 하위 카테고리 드롭다운 (AppBar 바로 아래)
          if (_subcategories.isNotEmpty) _buildCategoryDropdown(),

          // 2. 기간 탭
          _buildPeriodTabs(),

          // 3. 검색창
          _buildSearchBar(),

          // 4. 게시글 목록
          Expanded(child: _buildPostList()),
        ],
      ),
    );
  }

  Widget _buildPeriodTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_periodTabs.length, (index) {
          final isSelected = _selectedPeriodIndex == index;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedPeriodIndex = index;
                  // TODO: 기간별 필터링 구현
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.grey[600]!,
                  ),
                ),
                child: Text(
                  _periodTabs[index],
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.grey[400],
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(8),
        ),
        child: TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: '검색',
            hintStyle: TextStyle(color: Colors.grey[500]),
            prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
            suffixIcon:
                _searchController.text.isNotEmpty
                    ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                    : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _isDropdownExpanded = !_isDropdownExpanded;
            });
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '하위 카테고리 페이지로 가기',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Icon(
                  _isDropdownExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ),
        // 드롭다운 리스트
        if (_isDropdownExpanded)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children:
                  _subcategories.map((sub) {
                    return ListTile(
                      title: Text(
                        sub['name'] ?? '',
                        style: const TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        _navigateToSubcategory(sub['id'], sub['name']);
                      },
                    );
                  }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildPostList() {
    if (_posts.isEmpty && _isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_errorMessage != null && _posts.isEmpty) {
      return Center(
        child: Text(
          _errorMessage!,
          style: const TextStyle(color: Colors.white),
        ),
      );
    }

    if (_posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isSearching ? Icons.search_off : Icons.article_outlined,
              size: 64,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              _isSearching ? '검색 결과가 없습니다' : '이 카테고리에 작성된 글이 없습니다.',
              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _posts.clear();
          _page = 0;
          _hasMore = true;
          _errorMessage = null;
          _isSearching = false;
          _searchController.clear();
        });
        await _fetchPosts();
      },
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16.0),
        itemCount: _posts.length + (_hasMore && !_isSearching ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _posts.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(color: Colors.white),
              ),
            );
          }

          final post = _posts[index];
          return PostCard(post: post);
        },
      ),
    );
  }
}
