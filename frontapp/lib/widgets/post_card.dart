import 'package:flutter/material.dart';
import '../screens/user_profile_page.dart';
import '../services/api_service.dart';
import '../utils/emotion_asset_helper.dart';
import 'comment_sheet.dart';

class PostCard extends StatefulWidget {
  final Map<String, dynamic> post;

  const PostCard({super.key, required this.post});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _isEmpathyExpanded = false;
  final ApiService _apiService = ApiService();

  // Empathy Stats
  Map<String, int> _reactionCounts = {};
  String? _myReaction; // EmotionType string

  @override
  void initState() {
    super.initState();
    _initializeReactionCounts();

    _fetchReactionStats();
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
        // _myReaction is difficult to sync from list response unless we add it to ListResponse
        // Currently ListResponse does NOT have 'myReaction'.
        // So we still wait for _fetchReactionStats for _myReaction.
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

      // Optimistic Update
      setState(() {
        if (_myReaction == emotionKey) {
          // Toggle OFF
          _myReaction = null;
          _reactionCounts[emotionKey] = (_reactionCounts[emotionKey] ?? 1) - 1;
        } else {
          // Switch or Toggle ON
          if (_myReaction != null) {
            _reactionCounts[_myReaction!] =
                (_reactionCounts[_myReaction!] ?? 1) - 1;
          }
          _myReaction = emotionKey;
          _reactionCounts[emotionKey] = (_reactionCounts[emotionKey] ?? 0) + 1;
        }
      });

      await _apiService.toggleReaction(postId, emotionKey);

      // Re-fetch to sync
      _fetchReactionStats();
    } catch (e) {
      print('Error toggling reaction: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('공감 처리에 실패했습니다.')));
      _fetchReactionStats(); // Revert
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryName = widget.post['categoryName'] ?? 'Unknown';
    final content = widget.post['content'] ?? '';
    final date = widget.post['createdAt']?.substring(0, 10) ?? '';
    final imageUrl = widget.post['imageUrl'];
    final emotion = widget.post['dominantEmotion']; // AI Analysis
    final authorId =
        widget.post['authorId']?.toString() ??
        widget.post['userId']?.toString();
    final authorNickname =
        widget.post['userNickname'] ?? widget.post['authorName'] ?? '익명';
    final authorProfileImage = widget.post['userProfileImageUrl'];

    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Image (Top)
          if (imageUrl != null && imageUrl.toString().isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: SizedBox(
                width: double.infinity,
                child: Image.network(
                  'https://feelscore-s3.s3.ap-northeast-2.amazonaws.com/$imageUrl',
                  fit: BoxFit.fitWidth,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 200,
                      width: double.infinity,
                      color: Colors.grey[900],
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

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 2. Content & Tags (Middle)
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
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.6),
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
                            _getEmotionText(emotion),
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
                                  color:
                                      Theme.of(context).colorScheme.secondary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '감정분석중',
                                style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.secondary,
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
                          color: Colors.grey.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          date,
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Reaction Summary (only show if any reactions exist)
                Builder(
                  builder: (context) {
                    // Filter emotions with count > 0 and sort by count descending
                    final sortedReactions =
                        _reactionCounts.entries
                            .where((e) => e.value > 0)
                            .toList()
                          ..sort((a, b) => b.value.compareTo(a.value));

                    if (sortedReactions.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    return Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children:
                          sortedReactions.map((entry) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer
                                    .withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Image.asset(
                                    EmotionAssetHelper.getAssetPath(entry.key),
                                    width: 20,
                                    height: 20,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _getEmotionText(entry.key),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${entry.value}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.normal,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.8),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                    );
                  },
                ),

                const SizedBox(height: 12),
                Text(
                  content,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),

                // 3. Author Info & Actions (Bottom)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Author
                    GestureDetector(
                      onTap: () {
                        if (authorId != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => UserProfilePage(
                                    userId: authorId,
                                    nickname: authorNickname,
                                    profileImageUrl: authorProfileImage,
                                  ),
                            ),
                          );
                        }
                      },
                      behavior: HitTestBehavior.translucent,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.grey[800],
                              backgroundImage:
                                  authorProfileImage != null
                                      ? NetworkImage(
                                        'https://feelscore-s3.s3.ap-northeast-2.amazonaws.com/$authorProfileImage',
                                      )
                                      : null,
                              child:
                                  authorProfileImage == null
                                      ? const Icon(
                                        Icons.person,
                                        size: 16,
                                        color: Colors.white,
                                      )
                                      : null,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              authorNickname,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Actions (Empathize & Comment) - SWAPPED
                    Row(
                      children: [
                        // Empathize Button (Expandable)
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _isEmpathyExpanded = !_isEmpathyExpanded;
                            });
                          },
                          child: Row(
                            children: [
                              // Default to Neutral image (trigger), or my reaction if exists?
                              // User said "Neutral as default... touch -> expands".
                              // But if I already reacted, it might be nice to show THAT.
                              // However, strictly following "Neutral as default" for the trigger button appearance:
                              Image.asset(
                                EmotionAssetHelper.getAssetPath(
                                  _myReaction ?? 'NEUTRAL',
                                ), // Show current reaction or Neutral
                                width: 24,
                                height: 24,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "", // Text removed
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      _myReaction != null ? Colors.red : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Comment Button
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
                              const Icon(Icons.mode_comment_outlined, size: 20),
                              const SizedBox(width: 4),
                              Text(
                                '${widget.post['commentCount'] ?? 0}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // 4. Expandable Empathy List
                if (_isEmpathyExpanded) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Wrap(
                      spacing: 16, // Increased spacing for images
                      runSpacing: 16,
                      alignment: WrapAlignment.center,
                      children:
                          _emotionList.map((eKey) {
                            final isSelected = _myReaction == eKey;
                            return Tooltip(
                              message: _getEmotionText(
                                eKey,
                              ), // Preview on long press
                              child: GestureDetector(
                                onTap: () {
                                  _toggleReaction(eKey);
                                  setState(() {
                                    _isEmpathyExpanded =
                                        false; // Close on select
                                  });
                                },
                                child: Container(
                                  padding: EdgeInsets.all(isSelected ? 4 : 0),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border:
                                        isSelected
                                            ? Border.all(
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.primary,
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
                              ),
                            );
                          }).toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // List of all 11 Emotions defined in Backend EmotionType
  static const List<String> _emotionList = [
    'JOY',
    'SADNESS',
    'ANGER',
    'FEAR',
    'DISGUST',
    'SURPRISE',
    'CONTEMPT',
    'LOVE',
    'ANTICIPATION',
    'TRUST',
    'NEUTRAL',
  ];

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
