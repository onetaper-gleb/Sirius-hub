import 'package:flutter/material.dart';

import 'forum/forum_screen.dart';
import 'news/news_screen.dart';
import 'profile/profile_screen.dart';
import 'schedule/schedule_screen.dart';
import 'schedule/widgets/free_room_dialog.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _titles = ['Новости', 'Форум', 'Расписание', 'Профиль'];

  late final List<Widget> _pages = [
    const NewsScreen(),
    Navigator(
      key: const ValueKey('forum_navigator'),
      onGenerateRoute: (settings) =>
          MaterialPageRoute(builder: (context) => const ForumScreen()),
    ),
    const ScheduleScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          if (_index == 2)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue,
                  elevation: 0,
                  side: const BorderSide(color: Colors.blue, width: 1),
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => const FreeRoomDialog(),
                  );
                },
                icon: const Icon(Icons.manage_search, size: 20),
                label: const Text(
                  'Свободные ауд.',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ),
        ],
      ),
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          setState(() => _index = i);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.newspaper_outlined),
            selectedIcon: Icon(Icons.newspaper),
            label: 'Новости',
          ),
          NavigationDestination(
            icon: Icon(Icons.forum_outlined),
            selectedIcon: Icon(Icons.forum),
            label: 'Форум',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today),
            label: 'Расписание',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Профиль',
          ),
        ],
      ),
    );
  }
}
