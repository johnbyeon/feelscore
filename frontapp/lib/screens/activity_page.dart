import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'post_detail_screen.dart';
import 'user_profile_page.dart';
import 'dm_chat_page.dart';

class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  final ApiService _apiService = ApiService();
  List<dynamic> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _apiService.getMyNotifications(page: 0, size: 50);
      List<dynamic> notifications = response['content'] ?? [];

      // Mark as read immediately when fetched
      try {
        await _apiService.markNotificationsAsRead();
        // SUCCESS: Update local data to reflect isRead = true
        for (var n in notifications) {
          n['isRead'] = true;
        }
      } catch (e) {
        print('Error marking notifications as read: $e');
        // If API fails, keep original isRead values from server
      }

      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (e) {
      // Fallback or error
      print('Error fetching notifications: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Helper to group notifications
  Map<String, List<dynamic>> _groupNotifications(List<dynamic> notifications) {
    final Map<String, List<dynamic>> grouped = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final last7Days = today.subtract(const Duration(days: 7));
    final thisMonthStart = DateTime(now.year, now.month, 1);

    for (var notif in notifications) {
      String? createdStr = notif['createdAt'];
      if (createdStr == null) continue;
      DateTime created = DateTime.parse(createdStr);
      DateTime dateOnly = DateTime(created.year, created.month, created.day);

      String key;
      if (dateOnly == today) {
        key = '오늘';
      } else if (dateOnly == yesterday) {
        key = '어제';
      } else if (dateOnly.isAfter(last7Days)) {
        key = '최근 7일';
      } else if (dateOnly.isAfter(thisMonthStart)) {
        key = '이번 달';
      } else {
        key = '이전 활동';
      }

      if (grouped[key] == null) grouped[key] = [];
      grouped[key]!.add(notif);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    final groupedMap = _groupNotifications(_notifications);
    final sortedKeys = <String>[];
    // Define order
    if (groupedMap.containsKey('오늘')) sortedKeys.add('오늘');
    if (groupedMap.containsKey('어제')) sortedKeys.add('어제');
    if (groupedMap.containsKey('최근 7일')) sortedKeys.add('최근 7일');
    if (groupedMap.containsKey('이번 달')) sortedKeys.add('이번 달');
    if (groupedMap.containsKey('이전 활동')) sortedKeys.add('이전 활동');

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          '활동',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _handleMarkAllRead,
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('모두 읽음'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TextButton(
              onPressed: _handleClearAll,
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              child: const Text('모두 삭제'),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchNotifications,
        color: Colors.white,
        backgroundColor: Colors.grey[900],
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: sortedKeys.length,
          itemBuilder: (context, sectionIndex) {
            final key = sortedKeys[sectionIndex];
            final items = groupedMap[key]!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                  child: Text(
                    key,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ...items
                    .map(
                      (notif) => NotificationItem(
                        notification: notif,
                        onTap:
                            () => _removeNotification(
                              notif['notificationId'] ?? notif['id'],
                            ),
                      ),
                    )
                    .toList(),
              ],
            );
          },
        ),
      ),
    );
  }

  void _removeNotification(int id) {
    setState(() {
      _notifications.removeWhere((n) => (n['notificationId'] ?? n['id']) == id);
    });
  }

  Future<void> _handleMarkAllRead() async {
    try {
      await _apiService.markNotificationsAsRead();
      setState(() {
        for (var n in _notifications) {
          n['isRead'] = true;
        }
      });
    } catch (e) {
      print('Error marking all read: $e');
    }
  }

  Future<void> _handleClearAll() async {
    // Show confirmation dialog? Or just clear.
    // Let's ask for confirmation for safety.
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Text(
              '알림 모두 삭제',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              '모든 알림을 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소', style: TextStyle(color: Colors.white)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('삭제'),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    try {
      await _apiService.clearAllNotifications();
      setState(() {
        _notifications.clear();
      });
    } catch (e) {
      print('Error clearing notifications: $e');
    }
  }
}

class NotificationItem extends StatefulWidget {
  final Map<String, dynamic> notification;
  final VoidCallback onTap;

  const NotificationItem({
    super.key,
    required this.notification,
    required this.onTap,
  });

  @override
  State<NotificationItem> createState() => _NotificationItemState();
}

class _NotificationItemState extends State<NotificationItem> {
  final ApiService _apiService = ApiService();

  String _getEmotionEmoji(String? type) {
    switch (type) {
      case 'LIKE':
        return '👍';
      case 'LOVE':
        return '❤️';
      case 'HAHA':
        return '😆';
      case 'SAD':
        return '😢';
      case 'ANGRY':
        return '😡';
      case 'WOW':
        return '😮';
      default:
        return '❤️';
    }
  }

  Widget _buildReactionIcon(String? type) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        color: Colors.black,
        shape: BoxShape.circle,
      ),
      child: Text(_getEmotionEmoji(type), style: const TextStyle(fontSize: 14)),
    );
  }

  String _getTimeAgo(String? createdAt) {
    if (createdAt == null) return '';
    final dt = DateTime.parse(createdAt);
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}일';
    if (diff.inHours > 0) return '${diff.inHours}시간';
    if (diff.inMinutes > 0) return '${diff.inMinutes}분';
    return '방금';
  }

  Future<void> _handleTap() async {
    final id =
        widget.notification['notificationId'] ?? widget.notification['id'];
    // 1. Capture Navigator and data before async gap or unmounting
    final navigator = Navigator.of(context);
    final type = widget.notification['type'];
    final relatedId = widget.notification['relatedId'];
    final senderId = widget.notification['senderId'];
    final senderNickname = widget.notification['senderNickname'] ?? 'Unknown';
    final senderProfile = widget.notification['senderProfileImage'];

    if (relatedId == null && type != 'FOLLOW') {
      // Just mark as read and remove
      try {
        await _apiService.markNotificationAsRead(id);
      } catch (e) {
        print("Failed to mark as read: $e");
      }
      widget.onTap();
      return;
    }

    // 2. Call API to mark as read (fire and forget to not delay UI)
    _apiService.markNotificationAsRead(id).catchError((e) {
      print("Failed to mark as read: $e");
    });

    // 3. Perform optimistic removal from UI (This unmounts the widget)
    widget.onTap();

    // 4. Navigate using captured navigator
    try {
      if (type == 'POST_REACTION' ||
          type == 'COMMENT' ||
          type == 'COMMENT_REACTION') {
        final post = await _apiService.getPost(relatedId);
        navigator.push(
          MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
        );
      } else if (type == 'FOLLOW') {
        final targetId = relatedId ?? senderId;
        navigator.push(
          MaterialPageRoute(
            builder:
                (_) => UserProfilePage(
                  userId: targetId.toString(),
                  nickname: senderNickname,
                  profileImageUrl: senderProfile,
                ),
          ),
        );
      } else if (type == 'DM') {
        navigator.push(
          MaterialPageRoute(
            builder:
                (_) => DmChatPage(
                  threadId: relatedId.toString(),
                  otherUserId: senderId.toString(),
                  otherUserNickname: senderNickname,
                  otherUserProfileUrl: senderProfile,
                ),
          ),
        );
      }
    } catch (e) {
      print('Navigation error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final senderProfile = widget.notification['senderProfileImage'];
    final senderNickname = widget.notification['senderNickname'] ?? 'Unknown';
    final type = widget.notification['type'];
    final reactionType = widget.notification['reactionType'];
    final content = widget.notification['content'] ?? '';
    final imageUrl = widget.notification['relatedContentImageUrl'];
    final createdAt = widget.notification['createdAt'];
    final isRead = widget.notification['isRead'] ?? false;

    // Text Span Logic with White/White70
    List<InlineSpan> textSpans = [
      TextSpan(
        text: '$senderNickname님',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    ];

    if (type == 'POST_REACTION' || type == 'COMMENT_REACTION') {
      textSpans.add(const TextSpan(text: '이 회원님의 '));
      textSpans.add(TextSpan(text: type == 'POST_REACTION' ? '게시물을' : '댓글을'));
      textSpans.add(const TextSpan(text: ' 공감합니다'));
    } else if (type == 'COMMENT') {
      textSpans.add(const TextSpan(text: '이 회원님의 게시물에 댓글을 남겼습니다 : '));
      textSpans.add(
        TextSpan(text: content, style: const TextStyle(color: Colors.grey)),
      );
    } else if (type == 'FOLLOW') {
      textSpans.add(const TextSpan(text: '이 회원님을 팔로우하기 시작했습니다.'));
    } else {
      textSpans.add(TextSpan(text: ' $content'));
    }

    Widget profileWidget = Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 22,
          backgroundImage:
              senderProfile != null
                  ? NetworkImage(
                    senderProfile.startsWith('http')
                        ? senderProfile
                        : '${ApiService.baseUrl}/$senderProfile',
                  )
                  : null,
          backgroundColor: Colors.grey[800],
          child:
              senderProfile == null
                  ? const Icon(Icons.person, color: Colors.white)
                  : null,
        ),
        if (reactionType != null)
          Positioned(
            right: -2,
            bottom: -2,
            child: _buildReactionIcon(reactionType),
          ),
      ],
    );

    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Red Dot for Unread
            if (!isRead)
              Padding(
                padding: const EdgeInsets.only(top: 18, right: 8),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            profileWidget,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        height: 1.4,
                      ),
                      children: textSpans,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getTimeAgo(createdAt),
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
            if (imageUrl != null) ...[
              const SizedBox(width: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  imageUrl.startsWith('http')
                      ? imageUrl
                      : '${ApiService.baseUrl}/$imageUrl',
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (c, o, s) => Container(
                        color: Colors.grey[900],
                        width: 48,
                        height: 48,
                      ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
