import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/api_service.dart';
import '../providers/refresh_provider.dart';
import 'follow_list_page.dart';
import 'dm_chat_page.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchStats();
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
        // Error handling can be silent or retry, but let's just log or ignore for now as UI will show 0
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
                                _buildStatColumn('0', 'Posts'),
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
                        'FellScore User',
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 16),
                      // Action Button
                      if (isMe)
                        SizedBox(
                          width: double.infinity,
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
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            child: const Text(
                              '로그아웃',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
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
                                    color: Colors.black87,
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
            ];
          },
          body: Column(
            children: [
              TabBar(
                indicatorColor: Colors.white,
                tabs: [
                  Tab(icon: Icon(Icons.grid_on, color: Colors.white)),
                  Tab(
                    icon: Icon(Icons.person_pin_outlined, color: Colors.white),
                  ),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildGridPosts(),
                    const Center(child: Text('No tagged posts')),
                  ],
                ),
              ),
            ],
          ),
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
    // Placeholder grid
    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: 0, // Mock count
      itemBuilder: (context, index) {
        return Container(
          color: Colors.grey[300],
          child: const Icon(Icons.image, color: Colors.white),
        );
      },
    );
  }
}
