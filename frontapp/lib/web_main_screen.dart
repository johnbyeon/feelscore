import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/refresh_provider.dart';
import 'providers/user_provider.dart';
import 'screens/user_profile_page.dart';
import 'write_page.dart';

import 'home_page.dart';
import 'screens/dm_inbox_page.dart';
import 'services/socket_service.dart';

class WebMainScreen extends StatefulWidget {
  const WebMainScreen({super.key});

  @override
  State<WebMainScreen> createState() => _WebMainScreenState();
}

class _WebMainScreenState extends State<WebMainScreen> {
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
    if (!SocketService().isConnected) {
      String? token = userProvider.accessToken;
      if (token != null) {
        SocketService().connect(
          token,
          onConnect: () {
            print('WebMainScreen: Global Socket Connected');
          },
        );
      }
    }
  }

  late final List<Widget> _pages = [
    const HomePage(),
    WritePage(onPostSuccess: () => _onItemTapped(0)),

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
    if (index == 0) {
      context.read<RefreshProvider>().triggerRefreshHome();
    } else if (index == 3) {
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
