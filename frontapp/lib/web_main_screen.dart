import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/refresh_provider.dart';
import 'providers/user_provider.dart';
import 'screens/user_profile_page.dart';
import 'write_page.dart';
import 'history_page.dart';
import 'home_page.dart';
import 'screens/dm_inbox_page.dart';

class WebMainScreen extends StatefulWidget {
  const WebMainScreen({super.key});

  @override
  State<WebMainScreen> createState() => _WebMainScreenState();
}

class _WebMainScreenState extends State<WebMainScreen> {
  int _selectedIndex = 0;

  late final List<Widget> _pages = [
    const HomePage(),
    WritePage(onPostSuccess: () => _onItemTapped(0)),
    const HistoryPage(),
    const DmInboxPage(),
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
      context.read<RefreshProvider>().triggerRefreshHistory();
    } else if (index == 4) {
      context.read<RefreshProvider>().triggerRefreshProfile();
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onItemTapped,
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: Text('Home'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.add_circle_outline),
                selectedIcon: Icon(Icons.add_circle_rounded),
                label: Text('Write'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.history_rounded),
                selectedIcon: Icon(Icons.history_edu_rounded),
                label: Text('History'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.mail_outline),
                selectedIcon: Icon(Icons.mail_rounded),
                label: Text('Messages'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person_rounded),
                label: Text('Profile'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: IndexedStack(index: _selectedIndex, children: _pages),
          ),
        ],
      ),
    );
  }
}
