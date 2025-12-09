import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/user_provider.dart';
import 'providers/refresh_provider.dart';
import 'services/api_service.dart';
import 'widgets/post_card.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();
  final List<dynamic> _posts = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 0;
  final int _size = 5;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchPosts();
    _scrollController.addListener(_onScroll);

    // Listen for refresh triggers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final refreshProvider = context.read<RefreshProvider>();
        refreshProvider.addListener(() {
          if (refreshProvider.shouldRefreshHistory && mounted) {
            refreshProvider.consumeRefreshHistory();
            _onRefresh();
          }
        });
      }
    });
  }

  Future<void> _onRefresh() async {
    setState(() {
      _posts.clear();
      _page = 0;
      _hasMore = true;
      _errorMessage = null;
    });
    await _fetchPosts();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // 스크롤이 바닥에 거의 도달했을 때 (200px 남았을 때) 다음 페이지 로딩
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore) {
      _fetchPosts();
    }
  }

  Future<void> _fetchPosts() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      if (userProvider.userId == null) {
        setState(() {
          _errorMessage = 'User not logged in';
          _isLoading = false;
        });
        return;
      }

      final response = await _apiService.getPostsByUser(
        int.parse(userProvider.userId!),
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

  @override
  Widget build(BuildContext context) {
    if (_posts.isEmpty && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _posts.isEmpty) {
      return Center(child: Text(_errorMessage!));
    }

    if (_posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_toggle_off_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              '최근 히스토리가 없습니다.',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My History'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _posts.clear();
            _page = 0;
            _hasMore = true;
            _errorMessage = null;
          });
          await _fetchPosts();
        },
        child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(16.0),
          itemCount: _posts.length + (_hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == _posts.length) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final post = _posts[index];
            return PostCard(post: post);
          },
        ),
      ),
    );
  }
}
