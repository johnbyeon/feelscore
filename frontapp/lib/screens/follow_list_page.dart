import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import 'user_profile_page.dart';
import '../providers/user_provider.dart';
import 'dm_chat_page.dart';

class FollowListPage extends StatefulWidget {
  final String userId;
  final String nickname;
  final int initialTabIndex; // 0 for followers, 1 for followings

  const FollowListPage({
    super.key,
    required this.userId,
    required this.nickname,
    this.initialTabIndex = 0,
  });

  @override
  State<FollowListPage> createState() => _FollowListPageState();
}

class _FollowListPageState extends State<FollowListPage> {
  final ApiService _apiService = ApiService();
  Set<int> _myFollowingIds = {};
  bool _isLoadingFollowings = true;

  @override
  void initState() {
    super.initState();
    _fetchMyFollowings();
  }

  Future<void> _fetchMyFollowings() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (userProvider.userId == null) return;

    try {
      final followings = await _apiService.getFollowings(userProvider.userId!);
      if (mounted) {
        setState(() {
          _myFollowingIds = followings.map((u) => u['id'] as int).toSet();
          _isLoadingFollowings = false;
        });
      }
    } catch (e) {
      print('Error fetching my followings: $e');
      if (mounted) {
        setState(() {
          _isLoadingFollowings = false;
        });
      }
    }
  }

  void _onFollowToggled(int targetUserId, bool isNowFollowing) {
    setState(() {
      if (isNowFollowing) {
        _myFollowingIds.add(targetUserId);
      } else {
        _myFollowingIds.remove(targetUserId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final isMe = userProvider.userId == widget.userId;

    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTabIndex,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: Text(widget.nickname),
          elevation: 0,
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey,
            tabs: [Tab(text: "Followers"), Tab(text: "Following")],
          ),
        ),
        body:
            _isLoadingFollowings && isMe
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                  children: [
                    _UserListView(
                      fetchUsers:
                          ({query}) => _apiService.getFollowers(
                            widget.userId,
                            query: query,
                          ),
                      myFollowingIds: _myFollowingIds,
                      isMe: isMe,
                      tabType: 0, // Followers
                      onFollowAction: _onFollowToggled,
                    ),
                    _UserListView(
                      fetchUsers:
                          ({query}) => _apiService.getFollowings(
                            widget.userId,
                            query: query,
                          ),
                      myFollowingIds: _myFollowingIds,
                      isMe: isMe,
                      tabType: 1, // Following
                      onFollowAction: _onFollowToggled,
                    ),
                  ],
                ),
      ),
    );
  }
}

class _UserListView extends StatefulWidget {
  final Future<List<dynamic>> Function({String? query}) fetchUsers;
  final Set<int> myFollowingIds;
  final bool isMe;
  final int tabType; // 0: Followers, 1: Following
  final Function(int, bool) onFollowAction;

  const _UserListView({
    required this.fetchUsers,
    required this.myFollowingIds,
    required this.isMe,
    required this.tabType,
    required this.onFollowAction,
  });

  @override
  State<_UserListView> createState() => _UserListViewState();
}

class _UserListViewState extends State<_UserListView> {
  late Future<List<dynamic>> _usersFuture;
  final TextEditingController _searchController = TextEditingController();
  final ApiService _apiService = ApiService();
  Timer? _debounce;
  final Map<int, bool> _realtimeStatus = {};
  dynamic _statusUnsubscribeFn;

  @override
  void initState() {
    super.initState();
    _loadUsers(); // Initialize immediately to avoid LateInitializationError
    _searchController.addListener(_onSearchChanged);
    // Connect/Subscribe first, then load users AGAIN to avoid race conditions
    // (Snapshot should be taken after Delta stream is reliable)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _connectAndSubscribe();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    if (_statusUnsubscribeFn != null) _statusUnsubscribeFn();
    super.dispose();
  }

  Future<void> _connectAndSubscribe() async {
    print(
      'FollowList: _connectAndSubscribe called. Socket connected: ${SocketService().isConnected}',
    );
    if (!SocketService().isConnected) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      String? token = await _apiService.refreshToken();
      if (token != null) {
        print('FollowList: Connecting socket...');
        userProvider.setTokens(token, null);
        SocketService().connect(
          token,
          onConnect: () {
            print('FollowList: Socket connected. Forcing re-subscription.');
            _statusUnsubscribeFn = null;
            _subscribeToStatus();
            // Fetch users AFTER subscribing to catch any updates that happened during connection
            _loadUsers();
          },
        );
      }
    } else {
      print('FollowList: Socket already connected. Subscribing.');
      _subscribeToStatus();
      // Fetch users even if already connected, to ensure fresh snapshot
      _loadUsers();
    }
  }

  void _subscribeToStatus() {
    print(
      'FollowList: _subscribeToStatus called. UnsubscribeFn exists: ${_statusUnsubscribeFn != null}',
    );
    if (_statusUnsubscribeFn != null) return;

    print('FollowList: Subscribing to /topic/public');
    _statusUnsubscribeFn = SocketService().subscribe('/topic/public', (data) {
      print('FollowList: Received WebSocket Message: $data');
      if (data['type'] == 'USER_STATUS') {
        final userId = data['userId'];
        final status = data['status'];
        print(
          'FollowList: USER_STATUS received. User: $userId, Status: $status',
        );
        if (userId != null && status != null) {
          final uid = userId is int ? userId : int.parse(userId.toString());
          if (mounted) {
            setState(() {
              _realtimeStatus[uid] = (status == 'ONLINE');
              print(
                'FollowList: Updated state for User $uid -> ${status == 'ONLINE'}',
              );
            });
          }
        }
      }
    });
  }

  void _loadUsers({String? query}) {
    setState(() {
      _usersFuture = widget.fetchUsers(query: query).then((users) {
        print('FollowList: Loaded ${users.length} users from API');
        for (var u in users) {
          print(
            'FollowList: User ${u['nickname']} (ID: ${u['id']}) API isOnline: ${u['isOnline']}, online: ${u['online']}',
          );
        }
        return users;
      });
    });
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _loadUsers(query: _searchController.text);
    });
  }

  Future<void> _handleFollowToggle(int userId, bool isFollowing) async {
    try {
      final success = await _apiService.toggleFollow(userId.toString());
      if (success) {
        widget.onFollowAction(userId, !isFollowing);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update follow status: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: '검색',
                hintStyle: TextStyle(color: Colors.grey),
                prefixIcon: Icon(Icons.search, color: Colors.grey),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ),

        // List Title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              widget.tabType == 0 ? '모든 팔로워' : '모든 팔로잉',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),

        // User List
        Expanded(
          child: FutureBuilder<List<dynamic>>(
            future: _usersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(
                  child: Text(
                    "Error: ${snapshot.error}",
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                  child: Text(
                    "사용자를 찾을 수 없습니다",
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }

              final users = snapshot.data!;

              return RefreshIndicator(
                onRefresh: () async {
                  // 새로고침 로직
                  _loadUsers(query: _searchController.text);
                  try {
                    await _usersFuture;
                  } catch (e) {
                    // Ignore errors during refresh wait
                  }
                },
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final nickname = user['nickname'] ?? 'Unknown';
                    final email =
                        user['email'] ?? ''; // Assuming email is available
                    final profileImageUrl = user['profileImageUrl'];
                    final userId = user['id']; // int
                    final isFollowing = widget.myFollowingIds.contains(userId);
                    // Use realtime status if available, otherwise use API snapshot
                    final isOnline =
                        _realtimeStatus[userId] ??
                        (user['isOnline'] == true || user['online'] == true);
                    // 디버깅용 로그 Output
                    // if (isOnline) print('User $nickname is Online');

                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Stack(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder:
                                          (context) => UserProfilePage(
                                            userId: userId.toString(),
                                            nickname: nickname,
                                            profileImageUrl: profileImageUrl,
                                          ),
                                    ),
                                  );
                                },
                                child: CircleAvatar(
                                  radius: 25,
                                  backgroundColor: Colors.grey[800],
                                  backgroundImage:
                                      profileImageUrl != null
                                          ? NetworkImage(
                                            'https://feelscore-s3.s3.ap-northeast-2.amazonaws.com/$profileImageUrl',
                                          )
                                          : null,
                                  child:
                                      profileImageUrl == null
                                          ? const Icon(
                                            Icons.person,
                                            color: Colors.white,
                                            size: 25,
                                          )
                                          : null,
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color:
                                        isOnline
                                            ? Colors.greenAccent
                                            : Colors.redAccent,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.black,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),

                          // Check if current user is this user
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nickname,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                if (email.isNotEmpty)
                                  Text(
                                    email,
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 14,
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          // Action Button
                          if (userId.toString() !=
                              Provider.of<UserProvider>(
                                context,
                                listen: false,
                              ).userId)
                            _buildActionButton(
                              userId,
                              nickname,
                              profileImageUrl,
                              isFollowing,
                            ),

                          // Delete Button (X) - Only for Followers tab
                          if (widget.tabType == 0) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.grey,
                                size: 20,
                              ),
                              onPressed: () {
                                // TODO: Implement remove follower logic
                              },
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    int userId,
    String nickname,
    String? profileImageUrl,
    bool isFollowing,
  ) {
    String buttonText = '메시지';
    bool isFollowAction =
        false; // true = follow/unfollow action, false = navigate to DM

    if (widget.tabType == 0) {
      // Followers Tab
      // If I don't follow them back -> '맞팔로우'
      if (!isFollowing) {
        buttonText = '맞팔로우';
        isFollowAction = true;
      } else {
        // If I follow them -> '메시지'
        buttonText = '메시지';
        isFollowAction = false;
      }
    } else {
      // Following Tab (Global Search enabled)
      if (isFollowing) {
        // Special case: Existing Following -> Show Message AND Unfollow
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () async {
                try {
                  final threadId = await _apiService.checkDmThread(
                    userId.toString(),
                  );
                  if (!mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => DmChatPage(
                            threadId: threadId ?? '',
                            otherUserId: userId.toString(),
                            otherUserNickname: nickname,
                            otherUserProfileUrl: profileImageUrl,
                          ),
                    ),
                  );
                } catch (e) {
                  print('Error checking DM thread: $e');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2C2C2C),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: const Text(
                '메시지',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => _handleFollowToggle(userId, isFollowing),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2C2C2C),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: const Text(
                '언팔로우',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      } else {
        buttonText = '팔로우'; // Found via search, not currently following
        isFollowAction = true;
      }
    }

    return SizedBox(
      height: 32,
      child: ElevatedButton(
        onPressed: () async {
          if (isFollowAction) {
            // For '맞팔로우' (Follow Back) -> we want to Follow (so isFollowing is currently false)
            // For '언팔로우' (Unfollow) -> we want to Unfollow (so isFollowing is currently true)

            // However, the button determines the intent.
            // If button is '맞팔로우', we toggle (Follow).
            // If button is '언팔로우', we toggle (Unfollow).
            // Pass current state 'isFollowing' to toggle logic so it knows what to do.

            // Specifically:
            // Followers Tab: !isFollowing -> toggle -> Follows
            // Following Tab: isFollowing -> toggle -> Unfollows
            _handleFollowToggle(userId, isFollowing);
          } else {
            // Message Button Logic
            try {
              final threadId = await _apiService.checkDmThread(
                userId.toString(),
              );
              if (!context.mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => DmChatPage(
                        threadId: threadId ?? '',
                        otherUserId: userId.toString(),
                        otherUserNickname: nickname,
                        otherUserProfileUrl: profileImageUrl,
                      ),
                ),
              );
            } catch (e) {
              print('Error checking DM thread: $e');
            }
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2C2C2C), // Dark Grey
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: Text(
          buttonText,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
