import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/api_service.dart';
import '../providers/refresh_provider.dart';
import 'follow_list_page.dart';
import 'dm_chat_page.dart';
import '../widgets/profile/emotion_calendar.dart';
import 'profile_edit_page.dart';
import 'post_detail_screen.dart';
import 'blocked_users_page.dart';

class UserProfilePage extends StatefulWidget {
  final String userId;
  final String nickname;
  final String? profileImageUrl;

  const UserProfilePage({
    super.key,
    required this.userId,
    required this.nickname,
    this.profileImageUrl,
  });

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  bool _isFollowing = false;
  // ignore: unused_field
  bool _isLoading = true;

  int _followerCount = 0;
  int _followingCount = 0;

  // New: posts state
  List<dynamic> _posts = [];
  bool _isPostsLoading = true;

  // Tagged posts state
  List<dynamic> _taggedPosts = [];
  bool _isTaggedPostsLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStats();
    _fetchPosts();
    _fetchTaggedPosts();
  }

  Future<void> _fetchStats() async {
    try {
      final stats = await _apiService.getFollowStats(widget.userId);
      if (mounted) {
        setState(() {
          _followerCount = stats['followerCount'];
          _followingCount = stats['followingCount'];
          _isFollowing = stats['isFollowing'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // New: fetch posts for the user
  Future<void> _fetchPosts() async {
    try {
      // Api expects int userId
      final int uid = int.parse(widget.userId);
      final result = await _apiService.getPostsByUser(uid, page: 0, size: 100);
      // Assuming API returns a map with 'content' list
      final List<dynamic> posts = result['content'] ?? [];
      if (mounted) {
        setState(() {
          _posts = posts;
          _isPostsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _posts = [];
          _isPostsLoading = false;
        });
      }
    }
  }

  // Fetch tagged posts
  Future<void> _fetchTaggedPosts() async {
    try {
      final result = await _apiService.getTaggedPosts(widget.userId);
      if (mounted) {
        setState(() {
          _taggedPosts = result;
          _isTaggedPostsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _taggedPosts = [];
          _isTaggedPostsLoading = false;
        });
      }
    }
  }

  final ApiService _apiService = ApiService();

  Future<void> _toggleFollow() async {
    try {
      // Optimistic update
      setState(() {
        _isFollowing = !_isFollowing;
        if (_isFollowing) {
          _followerCount++;
        } else {
          _followerCount--;
        }
      });

      final success = await _apiService.toggleFollow(widget.userId);
      if (!success) {
        // Revert if failed
        _fetchStats();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update follow status: $e')),
        );
        _fetchStats(); // Revert
      }
    }
  }

  Future<void> _pickImageAndUpload() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final mimeType = lookupMimeType(pickedFile.path) ?? 'image/jpeg';
      final fileName = pickedFile.path.split('/').last;

      // 1. Get Presigned URL
      final presignedInfo = await _apiService.getUploadPresignedUrl(
        fileName,
        mimeType,
      );
      final presignedUrl = presignedInfo['presignedUrl']!;
      final objectKey = presignedInfo['objectKey']!;

      // 2. Upload to S3
      await _apiService.uploadFileToS3(presignedUrl, pickedFile, mimeType);

      // 3. Update Backend via UserProvider
      if (!mounted) return;
      await context.read<UserProvider>().updateProfileImage(objectKey);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile image updated!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating image: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen for refresh triggers
    final refreshProvider = context.watch<RefreshProvider>();
    if (refreshProvider.shouldRefreshProfile &&
        context.read<UserProvider>().userId == widget.userId) {
      // Only refresh if it's "My Profile" (or we could refresh all profiles if needed, but usually tab click is for "Me")
      // Actually, if we are in MainScreen, we are passing the logged-in user's ID.
      // So checking logic is fine.
      // Wait for build to finish before refreshing state
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchStats();
        _fetchPosts();
        context.read<RefreshProvider>().consumeRefreshProfile();
      });
    }

    final userProvider = context.watch<UserProvider>();
    final bool isMe = userProvider.userId == widget.userId;
    final String? displayProfileImage =
        isMe ? userProvider.profileImageUrl : widget.profileImageUrl;

    return Scaffold(
      // backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          widget.nickname,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: DefaultTabController(
        length: 2,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile Header
                      Row(
                        children: [
                          // Avatar
                          GestureDetector(
                            onTap:
                                isMe && !_isLoading
                                    ? _pickImageAndUpload
                                    : null,
                            child: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 40,
                                  backgroundImage:
                                      displayProfileImage != null
                                          ? NetworkImage(
                                            'https://feelscore-s3.s3.ap-northeast-2.amazonaws.com/$displayProfileImage',
                                          )
                                          : null,
                                  backgroundColor: Colors.grey[800],
                                  child:
                                      displayProfileImage == null
                                          ? const Icon(
                                            Icons.person,
                                            size: 40,
                                            color: Colors.white,
                                          )
                                          : null,
                                ),
                                if (isMe)
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).primaryColor,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color:
                                              Theme.of(
                                                context,
                                              ).scaffoldBackgroundColor,
                                          width: 2,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                if (_isLoading && isMe)
                                  Positioned.fill(
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: Colors.black26,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 40),
                          // Stats
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildStatColumn('${_posts.length}', 'Posts'),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) => FollowListPage(
                                              userId: widget.userId,
                                              nickname: widget.nickname,
                                              initialTabIndex: 0,
                                            ),
                                      ),
                                    );
                                  },
                                  child: _buildStatColumn(
                                    '$_followerCount',
                                    'Followers',
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) => FollowListPage(
                                              userId: widget.userId,
                                              nickname: widget.nickname,
                                              initialTabIndex: 1,
                                            ),
                                      ),
                                    ).then(
                                      (_) => _fetchStats(),
                                    ); // Refresh on return
                                  },
                                  child: _buildStatColumn(
                                    '$_followingCount',
                                    'Following',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Meta info
                      Text(
                        widget.nickname,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'FeelScore User',
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 20),
                      // Emotion History Calendar
                      EmotionCalendar(userId: widget.userId),
                      const SizedBox(height: 20),
                      // Action Button
                      if (isMe)
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => const ProfileEditPage(),
                                    ),
                                  ).then((value) {
                                    if (value == true) {
                                      // Refresh profile could be handled here if we had a method to reload user details
                                      // Context.read<UserProvider>().reload(); // if available
                                    }
                                  });
                                },
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: Colors.grey[400]!),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                child: const Text(
                                  '프로필 수정',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () async {
                                  await userProvider.logout();
                                  if (context.mounted) {
                                    Navigator.of(
                                      context,
                                    ).popUntil((route) => route.isFirst);
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: Colors.grey[400]!),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                child: const Text(
                                  '로그아웃',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 8),
                      // 차단 유저 보기 버튼 (내 프로필일 때만)
                      if (isMe)
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => const BlockedUsersPage(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.block, size: 18),
                            label: const Text('차단된 사용자'),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.grey[600]!),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _toggleFollow,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      _isFollowing
                                          ? Colors.grey[800]
                                          : Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                child: Text(
                                  _isFollowing ? 'Following' : 'Follow',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => DmChatPage(
                                            threadId: '', // New conversation
                                            otherUserId: widget.userId,
                                            otherUserNickname: widget.nickname,
                                            otherUserProfileUrl:
                                                widget.profileImageUrl,
                                          ),
                                    ),
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: Colors.grey[400]!),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                child: const Text(
                                  '메시지',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              SliverPersistentHeader(
                delegate: _SliverAppBarDelegate(
                  TabBar(
                    indicatorColor: Colors.white,
                    tabs: const [
                      Tab(icon: Icon(Icons.grid_on, color: Colors.white)),
                      Tab(
                        icon: Icon(
                          Icons.person_pin_outlined,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                pinned: true,
              ),
            ];
          },
          body: TabBarView(children: [_buildGridPosts(), _buildTaggedPosts()]),
        ),
      ),
    );
  }

  Widget _buildStatColumn(String count, String label) {
    return Container(
      color: Colors.transparent, // For HitTestBehavior
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Text(
            count,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildGridPosts() {
    if (_isPostsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_posts.isEmpty) {
      return const Center(child: Text('게시물이 없습니다.'));
    }
    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: _posts.length,
      itemBuilder: (context, index) {
        final post = _posts[index];
        final imageUrl = post['imageUrl'];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
            );
          },
          child:
              imageUrl != null
                  ? Image.network(
                    'https://feelscore-s3.s3.ap-northeast-2.amazonaws.com/$imageUrl',
                    fit: BoxFit.cover,
                  )
                  : Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.image, color: Colors.white),
                  ),
        );
      },
    );
  }

  Widget _buildTaggedPosts() {
    if (_isTaggedPostsLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_taggedPosts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_pin_outlined, size: 64, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(
              '태그된 게시글이 없습니다',
              style: TextStyle(color: Colors.grey[500], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: _taggedPosts.length,
      itemBuilder: (context, index) {
        final post = _taggedPosts[index];
        final imageUrl = post['imageUrl'];

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
            );
          },
          child:
              imageUrl != null
                  ? Image.network(
                    'https://feelscore-s3.s3.ap-northeast-2.amazonaws.com/$imageUrl',
                    fit: BoxFit.cover,
                  )
                  : Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.image, color: Colors.white),
                  ),
        );
      },
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
