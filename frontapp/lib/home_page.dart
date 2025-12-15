import 'dart:async';
import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'services/fcm_service.dart';
import 'package:provider/provider.dart';
import 'providers/refresh_provider.dart';
import 'providers/user_provider.dart';
import 'widgets/home/status_bar.dart';
import 'widgets/home/category_ticker.dart';
import 'widgets/home/feed_card.dart';
import 'screens/dm_inbox_page.dart';
import 'screens/activity_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final ApiService _apiService = ApiService();

  // Data State
  List<CategoryStat> _categoryStats = [];
  List<dynamic> _feedPosts = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _unreadMessageCount = 0;
  int _unreadNotificationCount = 0;

  StreamSubscription? _fcmSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchData();

    // Listen for incoming messages to refresh Unread Count
    _fcmSubscription = FCMService().onMessageReceived.listen((_) {
      _quietRefreshUnreadCount();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fcmSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchData();
    }
  }

  // Helper for silent refresh
  Future<void> _quietRefreshUnreadCount() async {
    print(
      "DEBUG_FRONTEND: _quietRefreshUnreadCount Triggered (likely by FCM/Socket)",
    );
    try {
      final count = await _apiService.getUnreadTotalCount();
      final notifCount = await _apiService.getUnreadNotificationCount();
      print(
        "DEBUG_FRONTEND: _quietRefreshUnreadCount fetched count=$count, notifCount=$notifCount",
      );
      if (mounted) {
        setState(() {
          _unreadMessageCount = count;
          _unreadNotificationCount = notifCount;
        });
      }
    } catch (_) {}
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final refreshProvider = context.watch<RefreshProvider>();
    if (refreshProvider.shouldRefreshHome) {
      Future.microtask(() {
        _fetchData();
        context.read<RefreshProvider>().consumeRefreshHome();
      });
    }
  }

  Future<void> _fetchData({bool fetchUnreads = true}) async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch Stats (for Ticker)
      final statsData = await _apiService.getHomeStats(period: 'ALL');
      final stats =
          statsData.map((json) => CategoryStat.fromJson(json)).toList();

      // 2. Fetch Feed Posts
      List<dynamic> posts = [];
      if (stats.isNotEmpty) {
        final firstCatId = stats.first.categoryId;
        try {
          final postsData = await _apiService.getPostsByCategory(
            firstCatId,
            size: 10,
          );
          posts = postsData['content'] ?? [];
        } catch (e) {
          print('Failed to fetch posts for feed: $e');
        }
      }

      // 3. Fetch Unread Counts (Optional)
      int unreadCount = _unreadMessageCount;
      int unreadNotif = _unreadNotificationCount;

      if (fetchUnreads) {
        try {
          unreadCount = await _apiService.getUnreadTotalCount();
        } catch (e) {
          print('Error fetching unread count: $e');
        }

        try {
          unreadNotif = await _apiService.getUnreadNotificationCount();
        } catch (e) {
          // Error fetching notif count
        }
      }

      if (!mounted) return;

      setState(() {
        _categoryStats = stats;
        _feedPosts = posts;
        if (fetchUnreads) {
          _unreadMessageCount = unreadCount;
          _unreadNotificationCount = unreadNotif;
          print(
            "DEBUG_FRONTEND: _fetchData updating _unreadNotificationCount to $unreadNotif",
          );
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (e.toString().toLowerCase().contains('unauthorized')) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.read<UserProvider>().logout();
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/login', (route) => false);
          }
        });
        return;
      }
      setState(() {
        _errorMessage = 'Failed to load data: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    print(
      "DEBUG_FRONTEND: build called. _unreadNotificationCount=$_unreadNotificationCount",
    );
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // 1. App Bar
            SliverAppBar(
              backgroundColor: Colors.black,
              title: Row(
                children: [
                  Image.asset('assets/images/icon.png', width: 48, height: 48),
                  const SizedBox(width: 8),
                  const Text(
                    'Feel Score',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              floating: true,
              actions: [
                Stack(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.notifications_none,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ActivityPage(),
                          ),
                        ).then((_) {
                          // Optimistic Update: Clear red dot immediately
                          setState(() {
                            _unreadNotificationCount = 0;
                          });
                        }); // Refresh on return
                      },
                    ),
                    if (_unreadNotificationCount > 0)
                      Positioned(
                        right: 12,
                        top: 12,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                Stack(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.mark_chat_unread_outlined,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const DmInboxPage(),
                          ),
                        ).then((_) => _fetchData());
                      },
                    ),
                    if (_unreadMessageCount > 0)
                      Positioned(
                        right: 12,
                        top: 12,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),

            // 2. Status Bar (Friends)
            const SliverToBoxAdapter(child: StatusBar()),

            // 3. Category Ticker
            SliverToBoxAdapter(
              child: CategoryTicker(categories: _categoryStats),
            ),

            // 4. Feed Header
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '인기 급상승 게시물',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Icon(Icons.unfold_more, color: Colors.grey, size: 20),
                  ],
                ),
              ),
            ),

            // 5. Feed List
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                return FeedCard(post: _feedPosts[index]);
              }, childCount: _feedPosts.length),
            ),

            // Bottom Padding
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }
}

class CategoryStat {
  final int categoryId;
  final String name;
  final String? dominantEmotion;
  final int score;
  final int commentCount;
  final String? trend; // UP, DOWN, STABLE, NONE or null
  final List<CategoryStat> children;

  CategoryStat({
    required this.categoryId,
    required this.name,
    this.dominantEmotion,
    required this.score,
    this.commentCount = 0,
    this.trend,
    required this.children,
  });

  factory CategoryStat.fromJson(Map<String, dynamic> json) {
    return CategoryStat(
      categoryId: json['categoryId'],
      name: json['name'],
      dominantEmotion: json['dominantEmotion'],
      score: json['score'] ?? 0,
      commentCount: json['commentCount'] ?? 0,
      trend: json['trend'],
      children:
          (json['children'] as List<dynamic>?)
              ?.map((e) => CategoryStat.fromJson(e))
              .toList() ??
          [],
    );
  }
}
