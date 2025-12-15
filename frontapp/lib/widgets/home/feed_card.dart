import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/follow_provider.dart';
import '../../providers/user_provider.dart';
import '../../utils/emotion_asset_helper.dart';
import '../../services/api_service.dart';
import '../comment_sheet.dart';
import '../../screens/user_profile_page.dart';

class FeedCard extends StatefulWidget {
  final Map<String, dynamic> post;

  const FeedCard({super.key, required this.post});

  @override
  State<FeedCard> createState() => _FeedCardState();
}

class _FeedCardState extends State<FeedCard> {
  final ApiService _apiService = ApiService();
  Map<String, int> _reactionCounts = {};
  String? _myReaction;
  bool _isEmpathyExpanded = false;

  @override
  void initState() {
    super.initState();
    _initializeReactionCounts();
    _fetchReactionStats();

    // Check follow status using Provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authorId =
          widget.post['authorId']?.toString() ??
          widget.post['userId']?.toString();
      if (authorId != null) {
        context.read<FollowProvider>().checkFollowStatus(authorId);
      }
    });
  }

  void _initializeReactionCounts() {
    if (widget.post['reactionCounts'] != null) {
      final Map<String, dynamic> countsRaw = widget.post['reactionCounts'];
      final Map<String, int> counts = {};
      countsRaw.forEach((key, value) {
        counts[key] =
            value is int ? value : int.tryParse(value.toString()) ?? 0;
      });
      setState(() {
        _reactionCounts = counts;
      });
    }
  }

  Future<void> _fetchReactionStats() async {
    try {
      final postId = widget.post['id'].toString();
      final stats = await _apiService.getReactionStats(postId);

      final Map<String, dynamic> countsRaw = stats['reactionCounts'] ?? {};
      final Map<String, int> counts = {};
      countsRaw.forEach((key, value) {
        counts[key] =
            value is int ? value : int.tryParse(value.toString()) ?? 0;
      });

      setState(() {
        _reactionCounts = counts;
        _myReaction = stats['myReaction'];
      });
    } catch (e) {
      print('Error fetching reaction stats: $e');
    }
  }

  Future<void> _toggleReaction(String emotionKey) async {
    try {
      final postId = widget.post['id'].toString();

      setState(() {
        if (_myReaction == emotionKey) {
          _myReaction = null;
          _reactionCounts[emotionKey] = (_reactionCounts[emotionKey] ?? 1) - 1;
        } else {
          if (_myReaction != null) {
            _reactionCounts[_myReaction!] =
                (_reactionCounts[_myReaction!] ?? 1) - 1;
          }
          _myReaction = emotionKey;
          _reactionCounts[emotionKey] = (_reactionCounts[emotionKey] ?? 0) + 1;
        }
      });

      await _apiService.toggleReaction(postId, emotionKey);
      _fetchReactionStats();
    } catch (e) {
      print('Error toggling reaction: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authorName =
        widget.post['userNickname'] ?? widget.post['authorName'] ?? '익명';

    final profileUrl = widget.post['userProfileImageUrl'];
    final imageUrl = widget.post['imageUrl'];
    final content = widget.post['content'] ?? '';
    final date = widget.post['createdAt']?.substring(0, 10) ?? '';
    final categoryName = widget.post['categoryName'] ?? 'General';
    final authorId =
        widget.post['authorId']?.toString() ??
        widget.post['userId']?.toString();

    // Watch FollowProvider
    final isFollowing =
        authorId != null
            ? context.watch<FollowProvider>().isFollowing(authorId)
            : false;

    // Sort reactions
    final sortedReactions =
        _reactionCounts.entries.where((e) => e.value > 0).toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    if (authorId != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => UserProfilePage(
                                userId: authorId,
                                nickname: authorName,
                                profileImageUrl: profileUrl,
                              ),
                        ),
                      );
                    }
                  },
                  child: CircleAvatar(
                    radius: 20,
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
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            authorName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18, // Increased font size
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (authorId != null &&
                              authorId !=
                                  context.read<UserProvider>().userId) ...[
                            GestureDetector(
                              onTap: () {
                                context.read<FollowProvider>().toggleFollow(
                                  authorId,
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12, // Increased padding
                                  vertical: 6, // Increased padding
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      isFollowing
                                          ? Colors.grey[800]
                                          : Colors.blueAccent,
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      isFollowing
                                          ? Border.all(color: Colors.grey[600]!)
                                          : null,
                                ),
                                child: Text(
                                  isFollowing ? '팔로잉' : '팔로우',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13, // Increased font size
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. Main Image
          if (imageUrl != null && imageUrl.isNotEmpty)
            Image.network(
              'https://feelscore-s3.s3.ap-northeast-2.amazonaws.com/$imageUrl',
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder:
                  (context, error, stackTrace) => Container(
                    height: 300,
                    color: Colors.grey[900],
                    child: const Center(
                      child: Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
            ),

          // 3. Actions & Reactions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Empathize Button (Expandable) - Left
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isEmpathyExpanded = !_isEmpathyExpanded;
                        });
                      },
                      child: Row(
                        children: [
                          Image.asset(
                            EmotionAssetHelper.getAssetPath(
                              _myReaction ?? 'NEUTRAL',
                            ),
                            width: 26,
                            height: 26,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "", // Text removed
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color:
                                  _myReaction != null
                                      ? Colors.red
                                      : Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Comment Button - Right
                    GestureDetector(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder:
                              (context) => CommentSheet(
                                postId: widget.post['id'].toString(),
                              ),
                        );
                      },
                      child: Row(
                        children: [
                          const Icon(
                            Icons.chat_bubble_outline,
                            color: Colors.white,
                            size: 26,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${widget.post['commentCount'] ?? 0}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // Emotion Chips (Right aligned)
                    Row(
                      children:
                          sortedReactions.take(3).map((entry) {
                            return Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: _buildReactionChip(entry.key, entry.value),
                            );
                          }).toList(),
                    ),
                  ],
                ),

                // Expandable Empathy List
                if (_isEmpathyExpanded) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      alignment: WrapAlignment.center,
                      children:
                          EmotionAssetHelper.emotionList.map((eKey) {
                            final isSelected = _myReaction == eKey;
                            return Tooltip(
                              message: _getEmotionText(eKey), // Add Tooltip
                              child: GestureDetector(
                                onTap: () {
                                  _toggleReaction(eKey);
                                  setState(() {
                                    _isEmpathyExpanded = false;
                                  });
                                },
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(
                                        isSelected ? 4 : 0,
                                      ),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border:
                                            isSelected
                                                ? Border.all(
                                                  color: Colors.blueAccent,
                                                  width: 2,
                                                )
                                                : null,
                                      ),
                                      child: Image.asset(
                                        EmotionAssetHelper.getAssetPath(eKey),
                                        width: 40,
                                        height: 40,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // Footer Content
                Text(
                  content,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '#$categoryName',
                      style: TextStyle(
                        color: Colors.blueAccent[100],
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      date,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReactionChip(String emotion, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            EmotionAssetHelper.getAssetPath(emotion),
            width: 20, // Increased size
            height: 20,
          ),
          const SizedBox(width: 6),
          Text(
            _getEmotionText(emotion), // Added text
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13, // Increased size
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: const TextStyle(
              color: Colors.white70, // Slightly dimmer for count distinction
              fontSize: 13,
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  String _getEmotionText(String? emotion) {
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
        return '';
    }
  }
}
