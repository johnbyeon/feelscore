import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'user_profile_page.dart';

class FollowListPage extends StatefulWidget {
  final String userId;
  final String nickname;
  final int initialTabIndex; // 0 for followers, 1 for followings

  const FollowListPage({
    super.key,
    required this.userId,
    required this.nickname,
    this.initialTabIndex = 0,
  });

  @override
  State<FollowListPage> createState() => _FollowListPageState();
}

class _FollowListPageState extends State<FollowListPage> {
  final ApiService _apiService = ApiService();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTabIndex,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.nickname),
          elevation: 0,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          foregroundColor: Theme.of(context).textTheme.titleLarge?.color,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey,
            tabs: [Tab(text: "Followers"), Tab(text: "Following")],
          ),
        ),
        body: TabBarView(
          children: [
            _UserListView(
              fetchUsers: () => _apiService.getFollowers(widget.userId),
            ),
            _UserListView(
              fetchUsers: () => _apiService.getFollowings(widget.userId),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserListView extends StatefulWidget {
  final Future<List<dynamic>> Function() fetchUsers;

  const _UserListView({required this.fetchUsers});

  @override
  State<_UserListView> createState() => _UserListViewState();
}

class _UserListViewState extends State<_UserListView> {
  late Future<List<dynamic>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _usersFuture = widget.fetchUsers();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _usersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text("No users found", style: TextStyle(color: Colors.grey)),
          );
        }

        final users = snapshot.data!;

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            final nickname = user['nickname'];
            final profileImageUrl = user['profileImageUrl'];
            final userId = user['id'].toString();

            return ListTile(
              leading: CircleAvatar(
                radius: 20,
                backgroundImage:
                    profileImageUrl != null
                        ? NetworkImage(
                          'https://feelscore-s3.s3.ap-northeast-2.amazonaws.com/$profileImageUrl',
                        )
                        : null,
                backgroundColor: Colors.grey[800],
                child:
                    profileImageUrl == null
                        ? const Icon(Icons.person, color: Colors.white)
                        : null,
              ),
              title: Text(
                nickname,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder:
                        (context) => UserProfilePage(
                          userId: userId,
                          nickname: nickname,
                          profileImageUrl: profileImageUrl,
                        ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
