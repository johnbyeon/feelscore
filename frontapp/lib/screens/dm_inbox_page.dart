import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/fcm_service.dart';
import 'dm_chat_page.dart';
import 'user_profile_page.dart';

class DmInboxPage extends StatefulWidget {
  const DmInboxPage({super.key});

  @override
  State<DmInboxPage> createState() => _DmInboxPageState();
}

class _DmInboxPageState extends State<DmInboxPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final ApiService _apiService = ApiService();
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  List<dynamic> _inbox = [];
  List<dynamic> _requests = [];
  List<dynamic> _followers = [];
  List<dynamic> _searchResults = [];
  bool _isLoading = true;
  bool _isSearching = false;
  StreamSubscription? _fcmSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 2, vsync: this);
    _fetchData();
    _fetchFollowers();

    _fcmSubscription = FCMService().onMessageReceived.listen((_) async {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) _fetchData();
    });

    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fcmSubscription?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchData();
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (_searchController.text.trim().isNotEmpty) {
        _searchUsers(_searchController.text.trim());
      } else {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    });
  }

  Future<void> _searchUsers(String query) async {
    setState(() => _isSearching = true);
    try {
      final results = await _apiService.searchUsers(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _fetchFollowers() async {
    try {
      final me = await _apiService.getMe();
      final myId = me['id']?.toString();
      if (myId != null) {
        final followers = await _apiService.getFollowers(myId);
        if (mounted) {
          setState(() => _followers = followers);
        }
      }
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> _fetchData() async {
    if (_inbox.isEmpty && _requests.isEmpty) {
      if (mounted) setState(() => _isLoading = true);
    }

    try {
      final inbox = await _apiService.getDmInbox();
      final requests = await _apiService.getDmRequests();
      if (mounted) {
        setState(() {
          _inbox = inbox;
          _requests = requests;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showFollowerActions(Map<String, dynamic> follower) {
    final userId = follower['userId']?.toString() ?? follower['id']?.toString();
    final nickname = follower['nickname'] ?? '알 수 없음';
    final profileUrl = follower['profileImageUrl'];

    showModalBottomSheet(
      context: context,
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.message),
                  title: const Text('메시지 보내기'),
                  onTap: () {
                    Navigator.pop(context);
                    _openChat(userId, nickname, profileUrl);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text('프로필 보기'),
                  onTap: () {
                    Navigator.pop(context);
                    if (userId != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => UserProfilePage(
                                userId: userId,
                                nickname: nickname,
                                profileImageUrl: profileUrl,
                              ),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
    );
  }

  void _openChat(String? userId, String nickname, String? profileUrl) {
    if (userId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => DmChatPage(
              threadId: '',
              otherUserId: userId,
              otherUserNickname: nickname,
              otherUserProfileUrl: profileUrl,
            ),
      ),
    ).then((_) => _fetchData());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('메시지'), centerTitle: true),
      body: Column(
        children: [
          // 검색창
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '검색',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                suffixIcon:
                    _searchController.text.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchResults = []);
                          },
                        )
                        : null,
              ),
            ),
          ),

          // 검색 결과 표시
          if (_searchController.text.isNotEmpty)
            _buildSearchResults()
          else ...[
            // 팔로워 가로 스크롤
            if (_followers.isNotEmpty) _buildFollowerBar(),

            // 탭바
            TabBar(
              controller: _tabController,
              tabs: [
                Tab(text: '메시지 (${_inbox.length})'),
                Tab(text: '요청 (${_requests.length})'),
              ],
            ),

            // 채팅 목록
            Expanded(
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildThreadList(_inbox, isRequest: false),
                          _buildThreadList(_requests, isRequest: true),
                        ],
                      ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFollowerBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 90,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: _followers.length,
            itemBuilder: (context, index) {
              final follower = _followers[index];
              final nickname = follower['nickname'] ?? 'User';
              final profileUrl = follower['profileImageUrl'];

              return GestureDetector(
                onTap: () => _showFollowerActions(follower),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.grey[800],
                        backgroundImage:
                            profileUrl != null
                                ? NetworkImage(
                                  'https://feelscore-s3.s3.ap-northeast-2.amazonaws.com/$profileUrl',
                                )
                                : null,
                        child:
                            profileUrl == null
                                ? const Icon(Icons.person, color: Colors.white)
                                : null,
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 60,
                        child: Text(
                          nickname,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Expanded(child: Center(child: CircularProgressIndicator()));
    }

    if (_searchResults.isEmpty) {
      return Expanded(
        child: Center(
          child: Text('검색 결과가 없습니다', style: TextStyle(color: Colors.grey[500])),
        ),
      );
    }

    return Expanded(
      child: ListView.builder(
        itemCount: _searchResults.length,
        itemBuilder: (context, index) {
          final user = _searchResults[index];
          final userId = user['id']?.toString();
          final nickname = user['nickname'] ?? '알 수 없음';
          final profileUrl = user['profileImageUrl'];

          return ListTile(
            leading: GestureDetector(
              onTap: () {
                if (userId != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => UserProfilePage(
                            userId: userId,
                            nickname: nickname,
                            profileImageUrl: profileUrl,
                          ),
                    ),
                  );
                }
              },
              child: CircleAvatar(
                radius: 24,
                backgroundColor: Colors.grey[800],
                backgroundImage:
                    profileUrl != null
                        ? NetworkImage(
                          'https://feelscore-s3.s3.ap-northeast-2.amazonaws.com/$profileUrl',
                        )
                        : null,
                child:
                    profileUrl == null
                        ? const Icon(Icons.person, color: Colors.white)
                        : null,
              ),
            ),
            title: GestureDetector(
              onTap: () {
                if (userId != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => UserProfilePage(
                            userId: userId,
                            nickname: nickname,
                            profileImageUrl: profileUrl,
                          ),
                    ),
                  );
                }
              },
              child: Text(nickname),
            ),
            trailing: ElevatedButton(
              onPressed: () => _openChat(userId, nickname, profileUrl),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: const Text('메시지'),
            ),
          );
        },
      ),
    );
  }

  Widget _buildThreadList(List<dynamic> threads, {required bool isRequest}) {
    if (threads.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isRequest ? Icons.mail_outline : Icons.chat_bubble_outline,
              size: 64,
              color: Colors.grey[700],
            ),
            const SizedBox(height: 16),
            Text(
              isRequest ? '새로운 메시지 요청이 없습니다' : '대화가 없습니다',
              style: TextStyle(color: Colors.grey[500], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchData,
      child: ListView.builder(
        itemCount: threads.length,
        itemBuilder: (context, index) {
          final thread = threads[index];
          return _buildThreadTile(thread, isRequest: isRequest);
        },
      ),
    );
  }

  Widget _buildThreadTile(
    Map<String, dynamic> thread, {
    required bool isRequest,
  }) {
    final threadId = thread['threadId']?.toString() ?? '';
    final otherUserNickname = thread['otherUserNickname'] ?? '알 수 없음';
    final otherUserProfileUrl = thread['otherUserProfileImageUrl'];
    String lastMessageContent = thread['lastMessageContent'] ?? '';
    if (lastMessageContent.startsWith('http') &&
        (lastMessageContent.contains('s3') ||
            lastMessageContent.contains('amazonaws'))) {
      lastMessageContent = '(사진)';
    }
    final lastMessageTime = thread['lastMessageTime'];
    final unreadCount = thread['unreadCount'] ?? 0;
    final otherUserId = thread['otherUserId']?.toString();

    String timeDisplay = '';
    if (lastMessageTime != null) {
      try {
        final dt = DateTime.parse(lastMessageTime);
        final now = DateTime.now();
        if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
          timeDisplay =
              '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
        } else {
          timeDisplay = '${dt.month}/${dt.day}';
        }
      } catch (_) {}
    }

    return ListTile(
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: Colors.grey[800],
        backgroundImage:
            otherUserProfileUrl != null
                ? NetworkImage(
                  'https://feelscore-s3.s3.ap-northeast-2.amazonaws.com/$otherUserProfileUrl',
                )
                : null,
        child:
            otherUserProfileUrl == null
                ? const Icon(Icons.person, color: Colors.white)
                : null,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              otherUserNickname,
              style: TextStyle(
                fontWeight:
                    unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (timeDisplay.isNotEmpty)
            Text(
              timeDisplay,
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
        ],
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              lastMessageContent,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: unreadCount > 0 ? Colors.white : Colors.grey[500],
                fontWeight:
                    unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
          if (unreadCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                unreadCount.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
        ],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => DmChatPage(
                  threadId: threadId,
                  otherUserId: otherUserId,
                  otherUserNickname: otherUserNickname,
                  otherUserProfileUrl: otherUserProfileUrl,
                  isRequest: isRequest,
                ),
          ),
        ).then((_) => _fetchData());
      },
      trailing: IconButton(
        icon: const Icon(Icons.close, size: 20, color: Colors.grey),
        onPressed: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: const Text('채팅방 나가기'),
                  content: const Text(
                    '정말 이 채팅방을 나가시겠습니까?\n나가면 대화 내용을 볼 수 없습니다.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('취소'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text(
                        '나가기',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
          );

          if (confirmed == true) {
            try {
              await _apiService.leaveThread(threadId);
              if (mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('채팅방을 나갔습니다.')));
                _fetchData();
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('채팅방 나가기에 실패했습니다.')),
                );
              }
            }
          }
        },
      ),
    );
  }
}
