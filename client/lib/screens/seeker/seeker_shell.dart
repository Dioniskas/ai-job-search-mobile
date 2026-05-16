import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'resume_screen.dart';
import 'applications_screen.dart';
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
    SeekerHomeScreen(),
    SeekerSearchScreen(),
    SeekerResumeScreen(),
    SeekerApplicationsScreen(),
    SeekerProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _index = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        indicatorColor: Theme.of(context).colorScheme.primaryContainer,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: Color(0xFF2563EB)),
            label: 'Главная',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon:
                Icon(Icons.search_rounded, color: Color(0xFF2563EB)),
            label: 'Поиск',
          ),
          NavigationDestination(
            icon: Icon(Icons.description_outlined),
            selectedIcon:
                Icon(Icons.description_rounded, color: Color(0xFF2563EB)),
            label: 'Резюме',
          ),
          NavigationDestination(
            icon: Icon(Icons.send_outlined),
            selectedIcon:
                Icon(Icons.send_rounded, color: Color(0xFF2563EB)),
            label: 'Отклики',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon:
                Icon(Icons.person_rounded, color: Color(0xFF2563EB)),
            label: 'Профиль',
          ),
        ],
      ),
    );
  }
}
