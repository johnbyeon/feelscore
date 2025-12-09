import 'package:flutter/material.dart';
import '../services/api_service.dart';

class CommentSheet extends StatefulWidget {
  final String postId;

  const CommentSheet({super.key, required this.postId});

  @override
  State<CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<CommentSheet> {
  final ApiService _apiService = ApiService();
  final TextEditingController _commentController = TextEditingController();
  List<dynamic> _comments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchComments();
  }

  Future<void> _fetchComments() async {
    try {
      final comments = await _apiService.getComments(widget.postId);
      setState(() {
        _comments = comments;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching comments: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty) return;

    final content = _commentController.text.trim();
    _commentController.clear();
    FocusScope.of(context).unfocus();

    try {
      await _apiService.createComment(widget.postId, content);
      await _fetchComments(); // Refresh list
    } catch (e) {
      print('Error creating comment: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('댓글 작성에 실패했습니다.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '댓글',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),

          // List
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _comments.isEmpty
                    ? Center(
                      child: Text(
                        '첫 번째 댓글을 남겨보세요!',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _comments.length,
                      itemBuilder: (context, index) {
                        final comment = _comments[index];
                        final userProfile = comment['userProfileImageUrl'];
                        final nickname = comment['userNickname'] ?? '익명';
                        final content = comment['content'] ?? '';
                        final date =
                            comment['createdAt']?.substring(0, 10) ?? '';

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.grey[300],
                                backgroundImage:
                                    userProfile != null
                                        ? NetworkImage(
                                          'https://feelscore-s3.s3.ap-northeast-2.amazonaws.com/$userProfile',
                                        )
                                        : null,
                                child:
                                    userProfile == null
                                        ? const Icon(
                                          Icons.person,
                                          size: 20,
                                          color: Colors.white,
                                        )
                                        : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          nickname,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          date,
                                          style: TextStyle(
                                            color: Colors.grey[500],
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      content,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    const SizedBox(height: 8),
                                    // Reactions Row
                                    Row(
                                      children: [
                                        GestureDetector(
                                          onTap:
                                              () => _showReactionPicker(
                                                comment['id'].toString(),
                                              ),
                                          child: Text(
                                            "공감하기",
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // Display Counts
                                        if (comment['reactionCounts'] != null)
                                          ...((comment['reactionCounts']
                                                  as Map<String, dynamic>)
                                              .entries
                                              .map((entry) {
                                                if ((entry.value as int) > 0) {
                                                  return Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          left: 4.0,
                                                        ),
                                                    child: Container(
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                            horizontal: 4,
                                                            vertical: 2,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.grey[200],
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              4,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        "${_getEmotionText(entry.key)} ${entry.value}",
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          color: Colors.black87,
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                }
                                                return SizedBox.shrink();
                                              })
                                              .toList()),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
          ),

          // Input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      style: const TextStyle(
                        color: Colors.black87,
                      ), // Updated text color
                      decoration: InputDecoration(
                        hintText: '댓글 달기...',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _submitComment,
                    icon: Icon(
                      Icons.send,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleCommentReaction(
    String commentId,
    String emotionKey,
  ) async {
    try {
      // Optimistic or just refresh
      await _apiService.toggleCommentReaction(
        int.parse(widget.postId),
        int.parse(commentId),
        emotionKey,
      );
      _fetchComments();
    } catch (e) {
      print('Error reaction comment: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('공감 처리에 실패했습니다.')));
    }
  }

  void _showReactionPicker(String commentId) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: 300,
          child: Column(
            children: [
              Text("공감하기", style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children:
                    _emotionList.map((eKey) {
                      return GestureDetector(
                        onTap: () {
                          _toggleCommentReaction(commentId, eKey);
                          Navigator.pop(context);
                        },
                        child: Column(
                          children: [
                            Icon(
                              Icons.emoji_emotions_outlined,
                              size: 30,
                            ), // Placeholder icon
                            Text(
                              _getEmotionText(eKey),
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

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
