import 'package:flutter/material.dart';
import 'search_screen.dart';
import 'home_screen.dart';
import 'applications_screen.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';

class SeekerShell extends StatefulWidget {
  final int initialTab;
  const SeekerShell({super.key, this.initialTab = 0});

  @override
  State<SeekerShell> createState() => _SeekerShellState();
}

class _SeekerShellState extends State<SeekerShell> {
  late int _index;

  static const _screens = [
    SeekerSearchScreen(),
    SeekerHomeScreen(),
    SeekerApplicationsScreen(),
    SeekerChatScreen(),
    SeekerProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _index = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? Colors.white : Colors.black;
    const inactiveColor = Color(0xFF9E9E9E);
    final bgColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: _screens,
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Divider(
            height: 1,
            thickness: 1,
            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5E5),
          ),
          NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            elevation: 0,
            backgroundColor: bgColor,
            indicatorColor: Colors.transparent,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.search_outlined, color: inactiveColor),
                selectedIcon: Icon(Icons.search_rounded, color: activeColor),
                label: 'Поиск',
              ),
              NavigationDestination(
                icon: const Icon(Icons.work_outline, color: inactiveColor),
                selectedIcon: Icon(Icons.work_rounded, color: activeColor),
                label: 'Карьера',
              ),
              NavigationDestination(
                icon: const Icon(Icons.mail_outline, color: inactiveColor),
                selectedIcon: Icon(Icons.mail_rounded, color: activeColor),
                label: 'Отклики',
              ),
              NavigationDestination(
                icon: const Icon(Icons.chat_bubble_outline, color: inactiveColor),
                selectedIcon: Icon(Icons.chat_bubble_rounded, color: activeColor),
                label: 'Сообщения',
              ),
              NavigationDestination(
                icon: const Icon(Icons.person_outline_rounded, color: inactiveColor),
                selectedIcon: Icon(Icons.person_rounded, color: activeColor),
                label: 'Профиль',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
