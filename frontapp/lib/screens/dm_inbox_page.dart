import 'dart:async'; // Added
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/fcm_service.dart'; // Added
import 'dm_chat_page.dart';

class DmInboxPage extends StatefulWidget {
  const DmInboxPage({super.key});

  @override
  State<DmInboxPage> createState() => _DmInboxPageState();
}

class _DmInboxPageState extends State<DmInboxPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final ApiService _apiService = ApiService();
  late TabController _tabController;

  List<dynamic> _inbox = [];
  List<dynamic> _requests = [];
  bool _isLoading = true;
  StreamSubscription? _fcmSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 2, vsync: this);
    _fetchData();

    // Listen for incoming messages to refresh Inbox
    _fcmSubscription = FCMService().onMessageReceived.listen((_) async {
      print('DmInboxPage: Received message notification, refreshing list...');
      // Wait a bit to ensure backend DB is updated
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) _fetchData();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fcmSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      print('DmInboxPage: App resumed, refreshing list...');
      _fetchData();
    }
  }

  Future<void> _fetchData() async {
    // Only show loading if empty, otherwise silent update
    if (_inbox.isEmpty && _requests.isEmpty) {
      if (mounted) setState(() => _isLoading = true);
    }

    try {
      final inbox = await _apiService.getDmInbox();
      print('DEBUG: Inbox fetched. Item count: ${inbox.length}');
      if (inbox.isNotEmpty) {
        for (var t in inbox) {
          print(
            'DEBUG: Thread ${t['threadId']} unreadCount: ${t['unreadCount']}',
          );
        }
      }
      final requests = await _apiService.getDmRequests();
      if (mounted) {
        setState(() {
          _inbox = inbox;
          _requests = requests;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching DM data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('메시지'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: '채팅방 (${_inbox.length})'),
            Tab(text: '요청 (${_requests.length})'),
          ],
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                controller: _tabController,
                children: [
                  _buildThreadList(_inbox, isRequest: false),
                  _buildThreadList(_requests, isRequest: true),
                ],
              ),
    );
  }

  Widget _buildThreadList(List<dynamic> threads, {required bool isRequest}) {
    if (threads.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isRequest ? Icons.mail_outline : Icons.chat_bubble_outline,
              size: 64,
              color: Colors.grey[700],
            ),
            const SizedBox(height: 16),
            Text(
              isRequest ? '새로운 메시지 요청이 없습니다' : '대화가 없습니다',
              style: TextStyle(color: Colors.grey[500], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchData,
      child: ListView.builder(
        itemCount: threads.length,
        itemBuilder: (context, index) {
          final thread = threads[index];
          return _buildThreadTile(thread, isRequest: isRequest);
        },
      ),
    );
  }

  Widget _buildThreadTile(
    Map<String, dynamic> thread, {
    required bool isRequest,
  }) {
    // Parse thread data from DmThreadSummaryResponse
    final threadId = thread['threadId']?.toString() ?? '';
    final otherUserNickname = thread['otherUserNickname'] ?? '알 수 없음';
    final otherUserProfileUrl = thread['otherUserProfileImageUrl'];
    final lastMessageContent = thread['lastMessageContent'] ?? '';
    final lastMessageTime = thread['lastMessageTime'];
    final unreadCount = thread['unreadCount'] ?? 0;
    final otherUserId = thread['otherUserId']?.toString();

    String timeDisplay = '';
    if (lastMessageTime != null) {
      try {
        final dt = DateTime.parse(lastMessageTime);
        final now = DateTime.now();
        if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
          timeDisplay =
              '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
        } else {
          timeDisplay = '${dt.month}/${dt.day}';
        }
      } catch (_) {}
    }

    return ListTile(
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: Colors.grey[800],
        backgroundImage:
            otherUserProfileUrl != null
                ? NetworkImage(
                  'https://feelscore-s3.s3.ap-northeast-2.amazonaws.com/$otherUserProfileUrl',
                )
                : null,
        child:
            otherUserProfileUrl == null
                ? const Icon(Icons.person, color: Colors.white)
                : null,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              otherUserNickname,
              style: TextStyle(
                fontWeight:
                    unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (timeDisplay.isNotEmpty)
            Text(
              timeDisplay,
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
        ],
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              lastMessageContent,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: unreadCount > 0 ? Colors.white : Colors.grey[500],
                fontWeight:
                    unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
          if (unreadCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                unreadCount.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
        ],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => DmChatPage(
                  threadId: threadId,
                  otherUserId: otherUserId,
                  otherUserNickname: otherUserNickname,
                  otherUserProfileUrl: otherUserProfileUrl,
                  isRequest: isRequest,
                ),
          ),
        ).then((_) => _fetchData()); // Refresh on return
      },
    );
  }
}
