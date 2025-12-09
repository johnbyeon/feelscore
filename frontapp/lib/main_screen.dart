import 'package:flutter/material.dart';
import 'write_page.dart';
import 'history_page.dart';
import 'home_page.dart';

import 'package:provider/provider.dart';
import 'providers/refresh_provider.dart';
import 'providers/user_provider.dart';
import 'screens/user_profile_page.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  late final List<Widget> _pages = [
    const HomePage(),
    WritePage(onPostSuccess: () => _onItemTapped(0)),
    const HistoryPage(),
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
    if (index == 2) {
      // History 탭 선택 시 새로고침 트리거
      context.read<RefreshProvider>().triggerRefreshHistory();
    } else if (index == 0) {
      // Home 탭 선택 시 새로고침 트리거
      context.read<RefreshProvider>().triggerRefreshHome();
    } else if (index == 3) {
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
            icon: Icon(Icons.history_rounded, size: 32),
            selectedIcon: Icon(Icons.history_edu_rounded, size: 32),
            label: 'History',
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
