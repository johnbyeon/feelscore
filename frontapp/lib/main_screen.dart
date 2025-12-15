import 'package:flutter/material.dart';
import 'write_page.dart';

import 'home_page.dart';

import 'package:provider/provider.dart';
import 'providers/refresh_provider.dart';
import 'providers/user_provider.dart';
import 'screens/user_profile_page.dart';
import 'services/socket_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initSocket();
    });
  }

  Future<void> _initSocket() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    // UserProvider might typically have the token if we just logged in.
    // However, if we need to refresh, ApiService might be needed.
    // For now, let's assume valid token or use ApiService to refresh if needed.
    // We can rely on SocketService logic.

    // Better: let's use the logic from FollowListPage but simpler.
    // Use userProvider token if available.
    if (!SocketService().isConnected) {
      // We need ApiService to be safe about tokens?
      // Let's import it first if not present.
      // Or access via context? ApiService might not be a provider.
      // It is a singleton usually or created.
      // Let's simply check if we have a token in UserProvider.
      String? token = userProvider.accessToken;
      // If token is null, we might need to refresh?
      // Assuming AuthWrapper handles basic auth check.
      if (token != null) {
        SocketService().connect(
          token,
          onConnect: () {
            print('MainScreen: Global Socket Connected');
          },
        );
      }
    }
  }

  late final List<Widget> _pages = [
    const HomePage(),
    WritePage(onPostSuccess: () => _onItemTapped(0)),

    Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        return UserProfilePage(
          userId: userProvider.userId ?? '',
          nickname: userProvider.nickname ?? 'Guest',
          profileImageUrl: userProvider.profileImageUrl,
        );
      },
    ),
  ];

  void _onItemTapped(int index) {
    if (index == 0) {
      // Home 탭 선택 시 새로고침 트리거
      context.read<RefreshProvider>().triggerRefreshHome();
    } else if (index == 2) {
      // Profile 탭 선택 시 새로고침 트리거
      context.read<RefreshProvider>().triggerRefreshProfile();
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined, size: 32),
            selectedIcon: Icon(Icons.home_rounded, size: 32),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline, size: 32),
            selectedIcon: Icon(Icons.add_circle_rounded, size: 32),
            label: 'Write',
          ),

          NavigationDestination(
            icon: Icon(Icons.person_outline, size: 32),
            selectedIcon: Icon(Icons.person_rounded, size: 32),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
