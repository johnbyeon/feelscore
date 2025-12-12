import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

import '../services/socket_service.dart';
import '../services/fcm_service.dart';

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

class _DmChatPageState extends State<DmChatPage> with WidgetsBindingObserver {
  final ApiService _apiService = ApiService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<dynamic> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  // Timer? _pollingTimer; // Polling removed
  dynamic _unsubscribeFn;
  String? _currentThreadId;
  late bool _isRequest;
  bool _isConnected = false;
  late StreamSubscription<bool> _connectionSubscription;
  StreamSubscription? _fcmSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Observe lifecycle
    _isRequest = widget.isRequest;
    _currentThreadId = widget.threadId.isNotEmpty ? widget.threadId : null;

    // Set active thread ID for notification suppression
    if (_currentThreadId != null) {
      FCMService().setCurrentThreadId(_currentThreadId);
    }

    // 1. 기존 메시지 로딩
    _fetchMessages();

    // 2. 소켓 연결 및 구독
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _connectAndSubscribe();
    });

    // 3. 연결 상태 모니터링
    _connectionSubscription = SocketService().connectionStatus.listen((
      isConnected,
    ) {
      if (mounted) {
        setState(() {
          _isConnected = isConnected;
        });
        if (isConnected) {
          if (kDebugMode)
            print('Reconnected to WebSocket. Fetching missed messages...');
          _subscribeToChat(); // 재연결 시 재구독
          _fetchMessages(silent: true); // Get any missing history
        }
      }
    });

    // 4. FCM Trigger (Hybrid Delivery)
    // If WebSocket fails but FCM arrives, trigger fetch to ensure message is shown.
    _fcmSubscription = FCMService().onMessageReceived.listen((_) {
      if (kDebugMode)
        print('FCM Notification signal received. Fetching messages...');
      _fetchMessages(silent: true);
    });
  }

  Future<void> _connectAndSubscribe() async {
    // 1. Refresh token to ensure we have a valid one for WebSocket
    // WebSocket connection failure loop can occur if token is expired.
    String? token = await _apiService.refreshToken();

    if (token != null) {
      // Update UserProvider with new token to keep it in sync
      if (mounted) {
        context.read<UserProvider>().setTokens(token, null);
      }

      SocketService().connect(
        token,
        onConnect: () {
          _subscribeToChat();
        },
      );
      // 만약 이미 연결된 상태라면 바로 구독 시도
      if (SocketService().isConnected) {
        _subscribeToChat();
      }
    }
  }

  void _subscribeToChat() {
    if (_currentThreadId == null) return;

    // 중복 구독 방지
    if (_unsubscribeFn != null) return;

    if (kDebugMode) print('Subscribing to: /sub/chat/room/$_currentThreadId');

    _unsubscribeFn = SocketService().subscribe(
      '/sub/chat/room/$_currentThreadId',
      (data) {
        if (kDebugMode) print('Received message via socket: $data');
        _onMessageReceived(data);
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App came to foreground
      if (_currentThreadId != null) {
        FCMService().setCurrentThreadId(
          _currentThreadId,
        ); // Restore suppression
        _apiService.markAsRead(_currentThreadId!).catchError((e) => print(e));
      }

      // Check connection on resume
      if (!SocketService().isConnected) {
        _connectAndSubscribe();
      } else {
        _fetchMessages(silent: true);
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // App went to background/inactive -> Allow notifications
      FCMService().setCurrentThreadId(null);
    }
  }

  void _onMessageReceived(dynamic data) {
    if (mounted) {
      // Mark as read ONLY if app is in foreground
      final isForeground =
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

      if (_currentThreadId != null && isForeground) {
        _apiService.markAsRead(_currentThreadId!).catchError((e) {
          print('Error marking as read on message receive: $e');
        });
      }

      setState(() {
        // De-duplication check
        final newId = data['id'];
        final exists = _messages.any((m) => m['id'] == newId);

        if (!exists) {
          _messages.add(data);
        } else {
          if (kDebugMode)
            print('Duplicate message received via socket, ignoring: $newId');
        }
      });
      _scrollToBottom();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Remove observer
    // Clear active thread ID to resume notifications
    FCMService().setCurrentThreadId(null);
    _connectionSubscription.cancel();
    _fcmSubscription?.cancel();
    // _pollingTimer?.cancel();
    if (_unsubscribeFn != null) {
      _unsubscribeFn(); // stomp_dart_client unsubscribe
    }
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // _startPolling() removed

  Future<void> _fetchMessages({bool silent = false}) async {
    if (_currentThreadId == null) {
      setState(() => _isLoading = false);
      return;
    }

    if (!silent) setState(() => _isLoading = true);

    try {
      var fetchedMessages = await _apiService.getDmMessages(_currentThreadId!);

      if (kDebugMode) {
        print('DEBUG: Fetched ${fetchedMessages.length} messages from API');
      }

      // Backend sends Sort DESC (Newest First) -> Response: [Msg10(Latest), Msg9, ... Msg1]
      // Chat UI needs Chronological [Msg1, ... Msg9, Msg10(Latest)]
      // So we reverse it.
      if (fetchedMessages.isNotEmpty) {
        fetchedMessages = fetchedMessages.reversed.toList();
      }

      // Mark as read immediately after loading
      _apiService.markAsRead(_currentThreadId!).catchError((e) {
        print('Error marking as read: $e');
      });

      if (!mounted) return;

      setState(() {
        final fetchedIds = fetchedMessages.map((m) => m['id']).toSet();
        // Keep messages that are NOT in the fetched list (potentially newer socket messages)
        // But since we fetch the LATEST, local unique usually means pending sends or really new ones.
        final localUnique =
            _messages.where((m) => !fetchedIds.contains(m['id'])).toList();

        _messages = [...fetchedMessages, ...localUnique];

        // Ensure chronological sort (Oldest -> Newest)
        _messages.sort((a, b) {
          final tA = a['createdAt'] ?? '';
          final tB = b['createdAt'] ?? '';
          return tA.compareTo(tB);
        });

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

    // Web CJK input workaround: Delay clear to prevent 'Range end' assertion error
    Future.delayed(Duration.zero, () {
      if (mounted) _messageController.clear();
    });

    // 1. 첫 메시지(쓰레드 생성 전)이거나 요청 상태면 HTTP 사용
    if (_currentThreadId == null || _isRequest) {
      setState(() => _isSending = true);
      try {
        final response = await _apiService.sendDmMessage(
          threadId: _currentThreadId,
          receiverId: widget.otherUserId,
          content: content,
        );

        if (_currentThreadId == null && response['threadId'] != null) {
          _currentThreadId = response['threadId'].toString();
          FCMService().setCurrentThreadId(
            _currentThreadId,
          ); // Update suppression
          _subscribeToChat(); // ID 생겼으니 구독
        }
        await _fetchMessages(); // 목록 갱신
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('메시지 전송 실패')));
        _messageController.text = content; // Restore
      } finally {
        setState(() => _isSending = false);
      }
      return;
    }

    // 2. 이미 방이 있으면 WebSocket 전송
    try {
      if (kDebugMode) {
        print('--------------------------------------------------');
        print('🚀 [Front] Sending Message via WebSocket');
        print(
          'ThreadID: $_currentThreadId (Type: ${_currentThreadId.runtimeType})',
        );
        print(
          'ReceiverID: ${widget.otherUserId} (Type: ${widget.otherUserId.runtimeType})',
        );
        print('Content: $content');
        print('--------------------------------------------------');
      }

      final payload = {
        'threadId':
            _currentThreadId != null ? int.tryParse(_currentThreadId!) : null,
        'receiverId':
            widget.otherUserId != null
                ? int.tryParse(widget.otherUserId!)
                : null,
        'content': content,
      };

      if (kDebugMode) {
        print('🚀 [Front] Constructed Payload: $payload');
      }

      SocketService().sendMessage('/pub/chat/send', payload);

      // 소켓은 Fire & Forget에 가까우므로 별도 로딩 상태 없이 UI는 서버에서 오는 응답(Subscription)으로 업데이트
      // 혹은 Optimistic Update 가능
    } catch (e) {
      print('Socket Send Error: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('메시지 전송 오류')));
      _messageController.text = content;
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
              backgroundColor: Colors.grey[800],
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
            const SizedBox(width: 8),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _isConnected ? Colors.green : Colors.red,
                shape: BoxShape.circle,
              ),
            ),
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
                        final myUserId = context.read<UserProvider>().userId;
                        final senderId = msg['senderId'];

                        bool isMine = false;
                        if (myUserId != null && senderId != null) {
                          isMine = (senderId.toString() == myUserId.toString());
                        } else {
                          // Fallback to payload 'mine' if valid IDs aren't available
                          isMine = msg['mine'] == true;
                        }

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
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: '메시지를 입력하세요...',
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
              isMine ? Theme.of(context).colorScheme.primary : Colors.grey[800],
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
            Text(content, style: TextStyle(color: Colors.white, fontSize: 15)),
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
