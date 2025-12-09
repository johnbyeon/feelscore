import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

class DmChatPage extends StatefulWidget {
  final String threadId;
  final String? otherUserId;
  final String otherUserNickname;
  final String? otherUserProfileUrl;
  final bool isRequest;

  const DmChatPage({
    super.key,
    required this.threadId,
    this.otherUserId,
    required this.otherUserNickname,
    this.otherUserProfileUrl,
    this.isRequest = false,
  });

  @override
  State<DmChatPage> createState() => _DmChatPageState();
}

class _DmChatPageState extends State<DmChatPage> {
  final ApiService _apiService = ApiService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<dynamic> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  Timer? _pollingTimer;
  String? _currentThreadId;
  late bool _isRequest;

  @override
  void initState() {
    super.initState();
    _isRequest = widget.isRequest;
    _currentThreadId = widget.threadId.isNotEmpty ? widget.threadId : null;
    _fetchMessages();
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_currentThreadId != null) {
        _fetchMessages(silent: true);
      }
    });
  }

  Future<void> _fetchMessages({bool silent = false}) async {
    if (_currentThreadId == null) {
      setState(() => _isLoading = false);
      return;
    }

    if (!silent) setState(() => _isLoading = true);

    try {
      final messages = await _apiService.getDmMessages(_currentThreadId!);
      setState(() {
        _messages = messages;
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      print('Error fetching messages: $e');
      if (!silent) setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      final response = await _apiService.sendDmMessage(
        threadId: _currentThreadId,
        receiverId: widget.otherUserId,
        content: content,
      );

      // If this was a new conversation, get the threadId from response
      if (_currentThreadId == null && response['threadId'] != null) {
        _currentThreadId = response['threadId'].toString();
      }

      await _fetchMessages();
    } catch (e) {
      print('Error sending message: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('메시지 전송에 실패했습니다.')));
      // Restore message if send failed
      _messageController.text = content;
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _acceptRequest() async {
    if (_currentThreadId == null) return;
    try {
      await _apiService.acceptDmRequest(_currentThreadId!);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('메시지 요청을 수락했습니다.')));
      setState(() {
        _isRequest = false;
      });
      // Refresh to update UI
      _fetchMessages();
    } catch (e) {
      print('Error accepting request: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('요청 수락에 실패했습니다.')));
    }
  }

  Future<void> _deleteRequest() async {
    if (_currentThreadId == null) return;
    try {
      await _apiService.deleteDmRequest(_currentThreadId!);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      print('Error deleting request: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('요청 삭제에 실패했습니다.')));
      }
    }
  }

  Future<void> _blockUser(String myUserId) async {
    if (widget.otherUserId == null) return;
    try {
      await _apiService.blockUser(myUserId, widget.otherUserId!);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('사용자를 차단했습니다.')));
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error blocking user: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('사용자 차단에 실패했습니다.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[300],
              backgroundImage:
                  widget.otherUserProfileUrl != null
                      ? NetworkImage(
                        'https://feelscore-s3.s3.ap-northeast-2.amazonaws.com/${widget.otherUserProfileUrl}',
                      )
                      : null,
              child:
                  widget.otherUserProfileUrl == null
                      ? const Icon(Icons.person, size: 18, color: Colors.white)
                      : null,
            ),
            const SizedBox(width: 12),
            Text(widget.otherUserNickname),
          ],
        ),
        actions: [
          if (_isRequest)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'accept') {
                  _acceptRequest();
                } else if (value == 'delete') {
                  _deleteRequest();
                } else if (value == 'block') {
                  final myUserId = context.read<UserProvider>().userId;
                  if (myUserId != null) {
                    _blockUser(myUserId);
                  }
                }
              },
              itemBuilder:
                  (context) => [
                    const PopupMenuItem(value: 'accept', child: Text('수락하기')),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('삭제하기', style: TextStyle(color: Colors.red)),
                    ),
                    const PopupMenuItem(
                      value: 'block',
                      child: Text('차단하기', style: TextStyle(color: Colors.red)),
                    ),
                  ],
            ),
        ],
      ),
      body: Column(
        children: [
          // Request Banner
          if (_isRequest)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.amber.withValues(alpha: 0.2),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 18, color: Colors.amber),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '메시지 요청입니다. 수락하면 대화할 수 있습니다.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      final myUserId = context.read<UserProvider>().userId;
                      if (myUserId != null) {
                        _blockUser(myUserId);
                      }
                    },
                    child: const Text(
                      '차단',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                  TextButton(
                    onPressed: _acceptRequest,
                    child: const Text('수락'),
                  ),
                ],
              ),
            ),

          // Message List
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _messages.isEmpty
                    ? Center(
                      child: Text(
                        '대화를 시작해보세요!',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    )
                    : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final isMine = msg['mine'] == true;
                        return _buildMessageBubble(msg, isMine);
                      },
                    ),
          ),

          // Input Area
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: const TextStyle(color: Colors.black87),
                      decoration: InputDecoration(
                        hintText: '메시지를 입력하세요...',
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
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _isSending ? null : _sendMessage,
                    icon:
                        _isSending
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : Icon(
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

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isMine) {
    final content = msg['content'] ?? '';
    final createdAt = msg['createdAt'];
    String timeDisplay = '';
    if (createdAt != null) {
      try {
        final dt = DateTime.parse(createdAt);
        timeDisplay =
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {}
    }

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          color:
              isMine ? Theme.of(context).colorScheme.primary : Colors.grey[200],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              content,
              style: TextStyle(
                color: isMine ? Colors.white : Colors.black87,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              timeDisplay,
              style: TextStyle(
                color:
                    isMine ? Colors.white.withValues(alpha: 0.7) : Colors.grey,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
