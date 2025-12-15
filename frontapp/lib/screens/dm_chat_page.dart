import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../providers/user_provider.dart';
import '../services/socket_service.dart';
import '../services/fcm_service.dart';
import '../widgets/chat/chat_input_bar.dart';
import '../widgets/chat/emotion_sticker_picker.dart';
import '../utils/emotion_asset_helper.dart';
import '../widgets/chat/sticker_text_editing_controller.dart';
import 'user_profile_page.dart';

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
  final StickerTextEditingController _messageController =
      StickerTextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<dynamic> _messages = [];
  bool _isLoading = true;
  dynamic _unsubscribeFn;
  dynamic _statusUnsubscribeFn;
  String? _currentThreadId;
  late bool _isRequest;
  bool _isConnected = false;
  late StreamSubscription<bool> _connectionSubscription;
  StreamSubscription? _fcmSubscription;
  XFile? _pendingImage;
  bool _otherUserIsOnline = false;
  bool _isStickerPickerVisible = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() {
          _isStickerPickerVisible = false;
        });
      }
    });

    WidgetsBinding.instance.addObserver(this);
    _isRequest = widget.isRequest;
    _currentThreadId = widget.threadId.isNotEmpty ? widget.threadId : null;

    if (_currentThreadId != null) {
      FCMService().setCurrentThreadId(_currentThreadId);
    }

    _fetchMessages();
    _fetchOtherUserStatus();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _connectAndSubscribe();
    });

    _connectionSubscription = SocketService().connectionStatus.listen((
      isConnected,
    ) {
      if (mounted) {
        setState(() {
          _isConnected = isConnected;
        });
        if (isConnected) {
          if (kDebugMode) print('Reconnected. Fetching missed messages...');
          _subscribeToChat();
          _subscribeToStatus();
          _fetchMessages(silent: true);
          _fetchOtherUserStatus();
        }
      }
    });

    _fcmSubscription = FCMService().onMessageReceived.listen((_) {
      if (kDebugMode) print('FCM signal received. Fetching messages...');
      _fetchMessages(silent: true);
    });
  }

  Future<void> _fetchOtherUserStatus() async {
    if (widget.otherUserId == null) return;
    try {
      final isOnline = await _apiService.getUserStatus(widget.otherUserId!);
      if (mounted) {
        setState(() {
          _otherUserIsOnline = isOnline;
        });
      }
    } catch (e) {
      if (kDebugMode) print('Error fetching user status: $e');
    }
  }

  Future<void> _connectAndSubscribe() async {
    String? token = await _apiService.refreshToken();
    if (token != null) {
      if (mounted) context.read<UserProvider>().setTokens(token, null);

      SocketService().connect(
        token,
        onConnect: () {
          _subscribeToChat();
          _subscribeToStatus();
        },
      );
      if (SocketService().isConnected) {
        _subscribeToChat();
        _subscribeToStatus();
      }
    }
  }

  void _subscribeToChat() {
    if (_currentThreadId == null || _unsubscribeFn != null) return;
    if (kDebugMode) print('Subscribing to: /sub/chat/room/$_currentThreadId');

    _unsubscribeFn = SocketService().subscribe(
      '/sub/chat/room/$_currentThreadId',
      (data) {
        if (kDebugMode) print('Socket Msg: $data');
        _onMessageReceived(data);
      },
    );
  }

  void _subscribeToStatus() {
    if (_statusUnsubscribeFn != null) return;
    if (kDebugMode) print('Subscribing to: /topic/public');

    _statusUnsubscribeFn = SocketService().subscribe('/topic/public', (data) {
      if (kDebugMode) print('Status Msg: $data');
      if (data['type'] == 'USER_STATUS') {
        _onUserStatusReceived(data);
      }
    });
  }

  void _onUserStatusReceived(dynamic data) {
    if (widget.otherUserId == null) return;
    final userId = data['userId'];
    final status = data['status'];
    if (userId.toString() == widget.otherUserId.toString()) {
      if (mounted) {
        setState(() {
          _otherUserIsOnline = (status == 'ONLINE');
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_currentThreadId != null) {
        FCMService().setCurrentThreadId(_currentThreadId);
        _apiService.markAsRead(_currentThreadId!).catchError((e) => print(e));
      }
      if (!SocketService().isConnected)
        _connectAndSubscribe();
      else
        _fetchMessages(silent: true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      FCMService().setCurrentThreadId(null);
    }
  }

  void _onMessageReceived(dynamic data) {
    if (mounted) {
      final isForeground =
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
      if (_currentThreadId != null && isForeground) {
        _apiService.markAsRead(_currentThreadId!).catchError((e) => print(e));
      }

      final senderId = data['senderId'];
      if (senderId != null &&
          widget.otherUserId != null &&
          senderId.toString() == widget.otherUserId.toString()) {
        if (!_otherUserIsOnline) {
          setState(() {
            _otherUserIsOnline = true;
          });
        }
      }

      setState(() {
        final newId = data['id'];
        if (!_messages.any((m) => m['id'] == newId)) {
          // Since ListView is reversed (index 0 is bottom/newest),
          // we must insert new messages at the start of the list.
          _messages.insert(0, data);
        }
      });
      _scrollToBottom();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FCMService().setCurrentThreadId(null);
    _connectionSubscription.cancel();
    _fcmSubscription?.cancel();
    if (_unsubscribeFn != null) _unsubscribeFn();
    if (_statusUnsubscribeFn != null) _statusUnsubscribeFn();
    _focusNode.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchMessages({bool silent = false}) async {
    if (_currentThreadId == null) {
      setState(() => _isLoading = false);
      return;
    }
    if (!silent) setState(() => _isLoading = true);

    try {
      var fetchedMessages = await _apiService.getDmMessages(_currentThreadId!);
      if (fetchedMessages.isNotEmpty) {
        fetchedMessages = fetchedMessages.reversed.toList();
      }
      _apiService.markAsRead(_currentThreadId!).catchError((e) => print(e));

      if (!mounted) return;
      setState(() {
        final fetchedIds = fetchedMessages.map((m) => m['id']).toSet();
        final localUnique =
            _messages.where((m) => !fetchedIds.contains(m['id'])).toList();
        _messages = [...fetchedMessages, ...localUnique];
        _messages.sort(
          (a, b) => (b['createdAt'] ?? '').compareTo(a['createdAt'] ?? ''),
        );
        _isLoading = false;
      });
      // With reverse: true, we correspond to offset 0.
      if (!silent) _scrollToBottom();
    } catch (e) {
      print('Error fetching messages: $e');
      if (!silent) setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage({String? content}) async {
    // If threadId is null, otherUserId is required to create a new thread.
    // If it's a request, the first message will create/accept the thread.
    if (_currentThreadId == null && widget.otherUserId == null) return;

    // 1. Handle Pending Image if exists
    if (_pendingImage != null) {
      await _handleImageUpload(_pendingImage!);
      setState(() {
        _pendingImage = null;
      });
      // If image upload successfully sends a message, we might not need to send text separately.
      // For now, let's assume _handleImageUpload takes care of sending the message.
      // If there's also text, it will be sent as a separate message.
    }

    // 2. Handle Text Content
    final textContent = content ?? _messageController.text.trim();
    if (textContent.isEmpty) return;

    // Clear controller for text message
    _messageController.clear();

    // Determine message type
    String type = 'TEXT';
    String? imageUrl;

    // Check if content is pure URL (from image upload)
    if (textContent.startsWith('http') &&
        (textContent.contains('s3') || textContent.contains('amazonaws'))) {
      type = 'IMAGE';
      imageUrl = textContent;
    }

    try {
      if (_currentThreadId == null || _isRequest) {
        // This is the first message or a message to an unaccepted request,
        // which needs to create the thread or accept the request implicitly.
        final response = await _apiService.sendDmMessage(
          threadId: _currentThreadId,
          receiverId: widget.otherUserId,
          content: textContent,
          type: type,
          imageUrl: imageUrl,
        );
        if (_currentThreadId == null && response['threadId'] != null) {
          _currentThreadId = response['threadId'].toString();
          FCMService().setCurrentThreadId(_currentThreadId);
          _subscribeToChat();
        }
        // After sending the first message, the request is implicitly accepted
        // or a new thread is created, so _isRequest should be false.
        setState(() {
          _isRequest = false;
        });
        await _fetchMessages(); // Fetch messages to include the newly sent one
      } else {
        // Existing thread, send via WebSocket if connected, else API
        if (_isConnected) {
          final payload = {
            'threadId': int.tryParse(_currentThreadId!),
            'receiverId':
                widget.otherUserId != null
                    ? int.tryParse(widget.otherUserId!)
                    : null,
            'content': textContent,
            'type': type,
            'imageUrl': imageUrl,
          };
          SocketService().sendMessage('/pub/chat/send', payload);
        } else {
          await _apiService.sendDmMessage(
            threadId: _currentThreadId,
            receiverId: widget.otherUserId,
            content: textContent,
            type: type,
            imageUrl: imageUrl,
          );
          await _fetchMessages(silent: true); // Fetch to update UI
        }
      }
      _scrollToBottom();
    } catch (e) {
      print('Error sending message: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('메시지 전송 실패')));
      // If sending failed, put the text back if it was from the controller
      if (content == null) _messageController.text = textContent;
    }
  }

  Future<void> _handleImageUpload(XFile file) async {
    if (!mounted) return;

    // 1. Show Progress Dialog
    final StreamController<double> progressController =
        StreamController<double>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                StreamBuilder<double>(
                  stream: progressController.stream,
                  initialData: 0.0,
                  builder: (context, snapshot) {
                    return Text(
                      '${(snapshot.data! * 100).toStringAsFixed(0)}% Uploading...',
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    // 2. Upload Logic
    try {
      final fileName = file.name;
      final mimeType =
          file.mimeType ?? lookupMimeType(fileName) ?? 'image/jpeg';

      // Get Presigned URL
      final presignedData = await _apiService.getUploadPresignedUrl(
        fileName,
        mimeType,
      );
      final presignedUrl = presignedData['presignedUrl'];
      final objectKey = presignedData['objectKey'];

      if (presignedUrl == null || objectKey == null) {
        throw Exception('Failed to obtain presigned URL or object key');
      }

      // Streaming Upload
      final totalBytes = await file.length();
      final request = http.StreamedRequest('PUT', Uri.parse(presignedUrl));
      request.contentLength = totalBytes;
      request.headers['Content-Type'] = mimeType;

      final fileStream = file.openRead();
      int bytesSent = 0;

      fileStream.listen(
        (chunk) {
          bytesSent += chunk.length;
          request.sink.add(chunk);
          progressController.add(bytesSent / totalBytes);
        },
        onDone: () {
          request.sink.close();
        },
        onError: (e) {
          request.sink.addError(e);
        },
      );

      final response = await request.send();
      if (response.statusCode != 200) {
        throw Exception('Upload failed with status ${response.statusCode}');
      }

      // Close Dialog
      if (mounted) Navigator.pop(context);
      progressController.close();

      // 3. Send Message with S3 URL
      final imageUrl =
          'https://feelscore-s3.s3.ap-northeast-2.amazonaws.com/$objectKey';
      _sendMessage(content: imageUrl);
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close dialog on error
      progressController.close();
      print('Image Upload Error: $e');
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('사진 업로드 실패: $e')));
    }
  }

  Future<void> _acceptRequest() async {
    if (_currentThreadId == null) return;
    try {
      await _apiService.acceptDmRequest(_currentThreadId!);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('메시지 요청을 수락했습니다.')));
      setState(() => _isRequest = false);
      _fetchMessages();
    } catch (e) {
      if (mounted)
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
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('요청 삭제에 실패했습니다.')));
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
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('사용자 차단에 실패했습니다.')));
    }
  }

  Future<void> _leaveThread() async {
    // 확인 다이얼로그 표시
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('채팅방 나가기'),
            content: const Text('정말 이 채팅방을 나가시겠습니까?\n나가면 대화 내용을 볼 수 없습니다.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('나가기', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        await _apiService.leaveThread(widget.threadId);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('채팅방을 나갔습니다.')));
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('채팅방 나가기에 실패했습니다.')));
        }
      }
    }
  }

  Future<void> _hideThread() async {
    try {
      await _apiService.hideDmThread(widget.threadId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('채팅방을 숨겼습니다.')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('채팅방 숨기기에 실패했습니다.')));
      }
    }
  }

  void _toggleStickerPicker() {
    if (_isStickerPickerVisible) {
      setState(() => _isStickerPickerVisible = false);
      FocusScope.of(context).requestFocus(_focusNode);
    } else {
      FocusScope.of(context).unfocus();
      setState(() => _isStickerPickerVisible = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUserId = context.read<UserProvider>().userId;

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () {
            if (widget.otherUserId != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => UserProfilePage(
                        userId: widget.otherUserId!,
                        nickname: widget.otherUserNickname,
                        profileImageUrl: widget.otherUserProfileUrl,
                      ),
                ),
              );
            }
          },
          child: Row(
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
                        ? const Icon(
                          Icons.person,
                          size: 18,
                          color: Colors.white,
                        )
                        : null,
              ),
              const SizedBox(width: 12),
              Text(widget.otherUserNickname),
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _otherUserIsOnline ? Colors.green : Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'accept')
                _acceptRequest();
              else if (value == 'delete')
                _deleteRequest();
              else if (value == 'block' && myUserId != null)
                _blockUser(myUserId);
              else if (value == 'leave')
                _leaveThread();
              else if (value == 'hide')
                _hideThread();
            },
            itemBuilder:
                (context) => [
                  if (_isRequest) ...[
                    const PopupMenuItem(value: 'accept', child: Text('수락하기')),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('삭제하기', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                  const PopupMenuItem(value: 'hide', child: Text('채팅방 숨기기')),
                  const PopupMenuItem(
                    value: 'block',
                    child: Text('차단하기', style: TextStyle(color: Colors.red)),
                  ),
                  const PopupMenuItem(
                    value: 'leave',
                    child: Text('채팅방 나가기', style: TextStyle(color: Colors.red)),
                  ),
                ],
          ),
        ],
      ),
      body: PopScope(
        canPop: !_isStickerPickerVisible,
        onPopInvoked: (didPop) {
          if (didPop) return;
          if (_isStickerPickerVisible) {
            setState(() {
              _isStickerPickerVisible = false;
            });
          }
        },
        child: Column(
          children: [
            if (_isRequest)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.amber.withOpacity(0.2),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 18,
                      color: Colors.amber,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        '메시지 요청입니다. 수락하면 대화할 수 있습니다.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                    TextButton(
                      onPressed:
                          () => myUserId != null ? _blockUser(myUserId) : null,
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
                        reverse: true, // Start from bottom
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final senderId = msg['senderId'];
                          bool isMine = false;
                          if (myUserId != null && senderId != null) {
                            isMine =
                                (senderId.toString() == myUserId.toString());
                          } else {
                            isMine = msg['mine'] == true;
                          }

                          // Logic to group messages (Reverse List: Index 0 is Newest)
                          bool showProfile = true;
                          bool showTime = true;

                          // Check Older Message (index + 1) for Profile Grouping
                          if (index < _messages.length - 1) {
                            final prevMsg = _messages[index + 1]; // Older
                            final prevSender = prevMsg['senderId'];
                            final prevTime = prevMsg['createdAt'];
                            final currTime = msg['createdAt'];

                            bool sameSender = false;
                            if (prevSender != null && senderId != null) {
                              sameSender =
                                  prevSender.toString() == senderId.toString();
                            }

                            bool closeTime = false;
                            if (prevTime != null && currTime != null) {
                              try {
                                final d1 = DateTime.parse(prevTime);
                                final d2 = DateTime.parse(currTime);
                                if (d1.difference(d2).inMinutes.abs() < 1)
                                  closeTime = true;
                              } catch (_) {}
                            }
                            // If older message is same sender & close time,
                            // then THIS message is NOT the start of the group.
                            // Profile is shown at the START (Top/Oldest) of the group.
                            // Msg B (Index 0). Older is Msg A (Index 1).
                            // If Msg A is same sender & close time,
                            // Msg B is NOT the start. So showProfile = false.
                            if (sameSender && closeTime) showProfile = false;
                          }

                          // Check Newer Message (index - 1) for Time Grouping
                          if (index > 0) {
                            final nextMsg = _messages[index - 1]; // Newer
                            final nextSender = nextMsg['senderId'];
                            final nextTime = nextMsg['createdAt'];
                            final currTime = msg['createdAt'];

                            bool sameSender = false;
                            if (nextSender != null && senderId != null) {
                              sameSender =
                                  nextSender.toString() == senderId.toString();
                            }

                            bool closeTime = false;
                            if (nextTime != null && currTime != null) {
                              try {
                                final d1 = DateTime.parse(currTime);
                                final d2 = DateTime.parse(nextTime);
                                if (d2.difference(d1).inMinutes.abs() < 1)
                                  closeTime = true;
                              } catch (_) {}
                            }
                            // Time is shown at the END (Bottom/Newest) of the group.
                            // Msg A (Index 1). Newer is Msg B (Index 0).
                            // If Msg B is same sender & close time,
                            // Msg A is NOT the end. So showTime = false.
                            if (sameSender && closeTime) showTime = false;
                          }

                          return _buildMessageBubble(
                            msg,
                            isMine,
                            showProfile,
                            showTime,
                          );
                        },
                      ),
            ),

            // Image Preview Container
            if (_pendingImage != null)
              Container(
                color: Colors.grey[900], // Background for preview
                width: double.infinity,
                height: 200,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Display image from XFile
                    kIsWeb
                        ? Image.network(
                          _pendingImage!
                              .path, // On web, XFile.path is a blob URL
                          fit: BoxFit.contain,
                          errorBuilder:
                              (_, __, ___) =>
                                  const Icon(Icons.error, color: Colors.white),
                        )
                        : FutureBuilder<Uint8List>(
                          future: _pendingImage!.readAsBytes(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                    ConnectionState.done &&
                                snapshot.hasData) {
                              return Image.memory(
                                snapshot.data!,
                                fit: BoxFit.contain,
                              );
                            } else if (snapshot.hasError) {
                              return const Icon(
                                Icons.error,
                                color: Colors.white,
                              );
                            }
                            return const CircularProgressIndicator(); // Or a placeholder
                          },
                        ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => setState(() => _pendingImage = null),
                      ),
                    ),
                  ],
                ),
              ),

            if (!_isRequest)
              ChatInputBar(
                controller: _messageController,
                focusNode: _focusNode,
                onSendPressed: () => _sendMessage(),
                onImageSelected: (file) {
                  setState(() {
                    _pendingImage = file;
                  });
                },
                onStickerIconPressed: _toggleStickerPicker,
              ),
            if (_isStickerPickerVisible)
              SizedBox(
                height: 250,
                child: EmotionStickerPicker(
                  onStickerSelected: (code) {
                    final text = _messageController.text;
                    final selection = _messageController.selection;
                    String newText;
                    int newOffset;

                    if (selection.isValid && selection.start >= 0) {
                      newText = text.replaceRange(
                        selection.start,
                        selection.end,
                        code,
                      );
                      newOffset = selection.start + code.length;
                    } else {
                      newText = text + code;
                      newOffset = newText.length;
                    }

                    _messageController.value = TextEditingValue(
                      text: newText,
                      selection: TextSelection.collapsed(offset: newOffset),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openFullScreenImage(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => Scaffold(
              backgroundColor: Colors.black,
              body: Stack(
                children: [
                  Center(
                    child: InteractiveViewer(child: Image.network(imageUrl)),
                  ),
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 10,
                    right: 20,
                    child: IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 30,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),
      ),
    );
  }

  Widget _buildMessageBubble(
    Map<String, dynamic> msg,
    bool isMine,
    bool showProfile,
    bool showTime,
  ) {
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

    Widget contentWidget;
    bool isImage = false;

    // Check for S3 URL
    if (content.startsWith('http') &&
        (content.contains('s3') || content.contains('amazonaws'))) {
      isImage = true;
    }

    if (isImage) {
      contentWidget = GestureDetector(
        onTap: () => _openFullScreenImage(context, content),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            content,
            width: 200,
            fit: BoxFit.cover,
            loadingBuilder: (ctx, child, progress) {
              if (progress == null) return child;
              return Container(
                width: 200,
                height: 200,
                alignment: Alignment.center,
                color: Colors.grey[900],
                child: CircularProgressIndicator(
                  value:
                      progress.expectedTotalBytes != null
                          ? progress.cumulativeBytesLoaded /
                              progress.expectedTotalBytes!
                          : null,
                ),
              );
            },
            errorBuilder:
                (context, error, stackTrace) => const Icon(
                  Icons.broken_image,
                  size: 50,
                  color: Colors.grey,
                ),
          ),
        ),
      );
    } else {
      // Mixed Content Rendering
      final stickerRegex = RegExp(r'^\(([A-Z]+)\)$');
      if (stickerRegex.hasMatch(content)) {
        // Single Sticker -> Big
        final emotionKey = stickerRegex.firstMatch(content)!.group(1)!;
        contentWidget = Image.asset(
          EmotionAssetHelper.getAssetPath(emotionKey),
          width: 120,
          height: 120,
          fit: BoxFit.contain,
        );
      } else {
        // Text or Mixed
        List<InlineSpan> spans = [];
        final splitRegex = RegExp(r'(\([A-Z]+\))');
        (content as String).splitMapJoin(
          splitRegex,
          onMatch: (Match m) {
            final code = m.group(0)!;
            final key = code.substring(1, code.length - 1);
            spans.add(
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  child: Image.asset(
                    EmotionAssetHelper.getAssetPath(key),
                    width: 20,
                    height: 20,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            );
            return code;
          },
          onNonMatch: (String n) {
            spans.add(TextSpan(text: n));
            return n;
          },
        );
        contentWidget = RichText(
          text: TextSpan(
            style: const TextStyle(color: Colors.white, fontSize: 15),
            children: spans,
          ),
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMine)
            SizedBox(
              width: 36,
              child:
                  showProfile
                      ? GestureDetector(
                        onTap: () {
                          if (widget.otherUserId != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => UserProfilePage(
                                      userId: widget.otherUserId!,
                                      nickname: widget.otherUserNickname,
                                      profileImageUrl:
                                          widget.otherUserProfileUrl,
                                    ),
                              ),
                            );
                          }
                        },
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.grey[700],
                          backgroundImage:
                              widget.otherUserProfileUrl != null
                                  ? NetworkImage(
                                    'https://feelscore-s3.s3.ap-northeast-2.amazonaws.com/${widget.otherUserProfileUrl}',
                                  )
                                  : null,
                          child:
                              widget.otherUserProfileUrl == null
                                  ? const Icon(Icons.person, size: 20)
                                  : null,
                        ),
                      )
                      : null,
            ),

          if (!isMine) const SizedBox(width: 8),

          if (isMine) ...[
            if (showTime)
              Padding(
                padding: const EdgeInsets.only(right: 4, top: 10),
                child: Text(
                  timeDisplay,
                  style: const TextStyle(color: Colors.grey, fontSize: 10),
                ),
              ),
            Flexible(
              child: Container(
                padding:
                    isImage || (contentWidget is Image)
                        ? EdgeInsets.zero
                        : const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                decoration:
                    (isImage || (contentWidget is Image))
                        ? null
                        : BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(16),
                        ),
                child: contentWidget,
              ),
            ),
          ] else ...[
            Flexible(
              child: Container(
                padding:
                    isImage || (contentWidget is Image)
                        ? EdgeInsets.zero
                        : const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                decoration:
                    (isImage || (contentWidget is Image))
                        ? null
                        : BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(16),
                        ),
                child: contentWidget,
              ),
            ),
            if (showTime)
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 10),
                child: Text(
                  timeDisplay,
                  style: const TextStyle(color: Colors.grey, fontSize: 10),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
