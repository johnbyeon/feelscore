import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/emotion_asset_helper.dart';

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

  Map<String, dynamic>? _replyingTo;
  final FocusNode _commentFocusNode = FocusNode();
  final Set<int> _expandedCommentIds = {};

  bool _isSearchingUsers = false;
  List<dynamic> _userSuggestions = [];
  String _currentTagQuery = '';
  // ignore: unused_field
  int _tagStartIndex = -1;

  @override
  void initState() {
    super.initState();
    _fetchComments();
    _commentController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final text = _commentController.text;
    final selection = _commentController.selection;

    // Only search if cursor is valid
    if (selection.baseOffset < 0) return;

    // Detect if we are typing a tag
    // Simple logic: look for last '@' before cursor
    final textBeforeCursor = text.substring(0, selection.baseOffset);
    final lastAtParams = textBeforeCursor.lastIndexOf('@');

    if (lastAtParams >= 0) {
      // Check if it's a valid tag start (start of line or preceded by space)
      bool isValidStart =
          lastAtParams == 0 || textBeforeCursor[lastAtParams - 1] == ' ';

      if (isValidStart) {
        final query = textBeforeCursor.substring(lastAtParams + 1);
        // Only trigger search if query doesn't contain spaces (simple tag logic)
        if (!query.contains(' ')) {
          setState(() {
            _isSearchingUsers = true;
            _currentTagQuery = query;
            _tagStartIndex = lastAtParams;
          });
          _searchUsers(query);
          return;
        }
      }
    }

    if (_isSearchingUsers) {
      setState(() {
        _isSearchingUsers = false;
        _userSuggestions = [];
      });
    }
  }

  Future<void> _searchUsers(String query) async {
    try {
      // Use getFollowings API for suggestions
      // We might need a dedicated search API later, but followings is good for MVP
      final users = await _apiService.getFollowings('me', query: query);
      if (mounted && _isSearchingUsers && _currentTagQuery == query) {
        setState(() {
          _userSuggestions = users;
        });
      }
    } catch (e) {
      print('Error searching users: $e');
    }
  }

  void _selectUserTag(dynamic user) {
    final nickname = user['nickname'];
    final text = _commentController.text;
    final selection = _commentController.selection;

    // Find the tag we are replacing
    final textBeforeCursor = text.substring(0, selection.baseOffset);
    final lastAtParams = textBeforeCursor.lastIndexOf('@');

    if (lastAtParams >= 0) {
      final newText = text.replaceRange(
        lastAtParams,
        selection.baseOffset,
        '@$nickname ',
      );
      _commentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: (lastAtParams + nickname.length + 2).toInt(),
        ), // +1 for @, +1 for space
      );
    }

    setState(() {
      _isSearchingUsers = false;
      _userSuggestions = [];
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
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
    final parentId = _replyingTo?['id'];

    _commentController.clear();
    _commentFocusNode.unfocus();

    setState(() {
      _replyingTo = null;
    });

    try {
      await _apiService.createComment(
        widget.postId,
        content,
        parentId: parentId,
      );
      await _fetchComments(); // Refresh list
    } catch (e) {
      print('Error creating comment: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('댓글 작성에 실패했습니다.')));
    }
  }

  void _handleReply(Map<String, dynamic> comment) {
    setState(() {
      _replyingTo = comment;
    });
    _commentFocusNode.requestFocus();
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
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[700],
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
                        return _buildCommentTree(_comments[index]);
                      },
                    ),
          ),
          if (_replyingTo != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey[900],
              child: Row(
                children: [
                  Text(
                    "답글 작성 중: ${_replyingTo!['userNickname'] ?? '익명'}",
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _cancelReply,
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          if (_isSearchingUsers && _userSuggestions.isNotEmpty)
            Container(
              constraints: BoxConstraints(maxHeight: 150),
              decoration: BoxDecoration(
                color: Colors.grey[850],
                border: Border(top: BorderSide(color: Colors.grey[800]!)),
              ),
              child: ListView.builder(
                itemCount: _userSuggestions.length,
                itemBuilder: (context, index) {
                  final user = _userSuggestions[index];
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 12,
                      backgroundImage:
                          user['profileImageUrl'] != null
                              ? NetworkImage(
                                'https://feelscore-s3.s3.ap-northeast-2.amazonaws.com/${user['profileImageUrl']}',
                              )
                              : null,
                      child:
                          user['profileImageUrl'] == null
                              ? Icon(
                                Icons.person,
                                size: 12,
                                color: Colors.white,
                              )
                              : null,
                    ),
                    title: Text(
                      user['nickname'] ?? 'Unknown',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () => _selectUserTag(user),
                  );
                },
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey[800]!)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      focusNode: _commentFocusNode,
                      controller: _commentController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText:
                            _replyingTo != null ? '답글을 입력하세요...' : '댓글 달기...',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor:
                            Theme.of(context).inputDecorationTheme.fillColor,
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

  void _cancelReply() {
    setState(() {
      _replyingTo = null;
    });
    _commentFocusNode.unfocus();
  }

  Widget _buildCommentTree(dynamic comment) {
    final children = comment['children'] as List<dynamic>? ?? [];
    final commentId = comment['id'] as int;
    final isExpanded = _expandedCommentIds.contains(commentId);

    if (children.isEmpty) {
      return _buildCommentRow(comment);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCommentRow(comment),
        Padding(
          padding: const EdgeInsets.only(left: 48.0, bottom: 12.0),
          child: GestureDetector(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedCommentIds.remove(commentId);
                } else {
                  _expandedCommentIds.add(commentId);
                }
              });
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 24, height: 1, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  isExpanded ? "답글 접기" : "답글 ${children.length}개 더 보기",
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 32.0),
            child: Column(
              children: children.map((c) => _buildCommentTree(c)).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildCommentRow(dynamic comment) {
    final userProfile = comment['userProfileImageUrl'];
    final nickname = comment['userNickname'] ?? '익명';
    final content = comment['content'] ?? '';
    final date = comment['createdAt']?.substring(0, 10) ?? '';
    final commentId = comment['id'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey[800],
            backgroundImage:
                userProfile != null
                    ? NetworkImage(
                      'https://feelscore-s3.s3.ap-northeast-2.amazonaws.com/$userProfile',
                    )
                    : null,
            child:
                userProfile == null
                    ? const Icon(Icons.person, size: 20, color: Colors.white)
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
                      style: TextStyle(color: Colors.grey[500], fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(content, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    GestureDetector(
                      onTap:
                          () => _showReactionPicker(comment['id'].toString()),
                      child: Text(
                        "공감하기",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () => _handleReply(comment),
                      child: Text(
                        "답글 달기",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (comment['reactionCounts'] != null)
                      ...((comment['reactionCounts'] as Map<String, dynamic>)
                          .entries
                          .map((entry) {
                            if ((entry.value as int) > 0) {
                              return Padding(
                                padding: const EdgeInsets.only(left: 4.0),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[800],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    children: [
                                      Image.asset(
                                        EmotionAssetHelper.getAssetPath(
                                          entry.key,
                                        ),
                                        width: 16,
                                        height: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        "${entry.value}",
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
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
                            Image.asset(
                              EmotionAssetHelper.getAssetPath(eKey),
                              width: 40,
                              height: 40,
                            ),
                            const SizedBox(height: 4),
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
