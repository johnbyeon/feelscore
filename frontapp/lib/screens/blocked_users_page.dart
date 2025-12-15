import 'package:flutter/material.dart';
import '../services/api_service.dart';

class BlockedUsersPage extends StatefulWidget {
  const BlockedUsersPage({super.key});

  @override
  State<BlockedUsersPage> createState() => _BlockedUsersPageState();
}

class _BlockedUsersPageState extends State<BlockedUsersPage> {
  final ApiService _apiService = ApiService();
  List<dynamic> _blockedUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchBlockedUsers();
  }

  Future<void> _fetchBlockedUsers() async {
    setState(() => _isLoading = true);
    try {
      final users = await _apiService.getBlockList();
      setState(() {
        _blockedUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('차단 목록을 불러오는데 실패했습니다.')));
      }
    }
  }

  Future<void> _unblockUser(String blockedUserId, String nickname) async {
    // 확인 다이얼로그 표시
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('차단 해제'),
            content: Text('$nickname님의 차단을 해제하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('해제', style: TextStyle(color: Colors.blue)),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        await _apiService.unblockUser(blockedUserId);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('$nickname님의 차단을 해제했습니다.')));
          _fetchBlockedUsers(); // 리스트 새로고침
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('차단 해제에 실패했습니다.')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('차단된 사용자'), centerTitle: true),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _blockedUsers.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.block, size: 64, color: Colors.grey[600]),
                    const SizedBox(height: 16),
                    Text(
                      '차단된 사용자가 없습니다',
                      style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                    ),
                  ],
                ),
              )
              : RefreshIndicator(
                onRefresh: _fetchBlockedUsers,
                child: ListView.builder(
                  itemCount: _blockedUsers.length,
                  itemBuilder: (context, index) {
                    final user = _blockedUsers[index];
                    final blockedUserId =
                        user['blockedUserId']?.toString() ?? '';
                    final nickname = user['blockedUserNickname'] ?? '알 수 없음';
                    final profileUrl = user['blockedUserProfileImage'];

                    return ListTile(
                      leading: CircleAvatar(
                        radius: 24,
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
                      title: Text(nickname),
                      trailing: TextButton(
                        onPressed: () => _unblockUser(blockedUserId, nickname),
                        child: const Text(
                          '차단 해제',
                          style: TextStyle(color: Colors.blue),
                        ),
                      ),
                    );
                  },
                ),
              ),
    );
  }
}
