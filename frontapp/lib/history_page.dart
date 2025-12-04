import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/user_provider.dart';
import 'providers/refresh_provider.dart';
import 'services/api_service.dart';

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
        userProvider.userId!,
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
            final categoryName = post['categoryName'] ?? 'Unknown';
            final content = post['content'] ?? '';
            final date = post['createdAt']?.substring(0, 10) ?? '';
            final imageUrl = post['imageUrl'];
            final emotion = post['dominantEmotion']; // 감정 데이터

            String getEmotionText(String? emotion) {
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
                case 'NEUTRAL':
                  return '중립';
                default:
                  return '';
              }
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 16.0),
              elevation: 0,
              color: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.1),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '#$categoryName',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.6),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            if (emotion != null) ...[
                              Text(
                                getEmotionText(emotion),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ] else ...[
                              Row(
                                children: [
                                  SizedBox(
                                    width: 10,
                                    height: 10,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.secondary,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '감정분석중',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.secondary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(width: 8),
                            Container(
                              width: 1,
                              height: 12,
                              color: Colors.grey.withOpacity(0.5),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              date,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      content,
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (imageUrl != null && imageUrl.toString().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(
                            minHeight: 200, // 최소 높이 설정
                            maxHeight: 400, // 최대 높이 설정 (너무 길어지는 것 방지)
                          ),
                          child: Image.network(
                            'https://feelscore-s3.s3.ap-northeast-2.amazonaws.com/$imageUrl',
                            fit: BoxFit.cover, // 가로/세로 최소 사이즈에 맞춰 비율 유지하며 채움
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 200,
                                width: double.infinity,
                                color: Colors.grey[200],
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.image_not_supported_outlined,
                                      color: Colors.grey[400],
                                      size: 40,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '이미지를 불러올 수 없습니다',
                                      style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
