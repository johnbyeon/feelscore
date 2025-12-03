import 'package:flutter/material.dart';
import 'write_page.dart';
import 'history_page.dart';
import 'home_page.dart';

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
    const Center(child: Text('Profile')), // Placeholder for Profile
  ];

  void _onItemTapped(int index) {
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
