import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'vacancies_screen.dart';
import 'candidates_screen.dart';
import 'applications_screen.dart';
import 'profile_screen.dart';

class EmployerShell extends StatefulWidget {
  final int initialTab;
  const EmployerShell({super.key, this.initialTab = 0});

  @override
  State<EmployerShell> createState() => _EmployerShellState();
}

class _EmployerShellState extends State<EmployerShell> {
  late int _index;

  static const _screens = [
    EmployerHomeScreen(),
    EmployerVacanciesScreen(),
    EmployerCandidatesScreen(),
    EmployerApplicationsScreen(),
    EmployerProfileScreen(),
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
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon:
                Icon(Icons.dashboard_rounded, color: Color(0xFF2563EB)),
            label: 'Главная',
          ),
          NavigationDestination(
            icon: Icon(Icons.work_outline_rounded),
            selectedIcon:
                Icon(Icons.work_rounded, color: Color(0xFF2563EB)),
            label: 'Вакансии',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline_rounded),
            selectedIcon:
                Icon(Icons.people_rounded, color: Color(0xFF2563EB)),
            label: 'Кандидаты',
          ),
          NavigationDestination(
            icon: Icon(Icons.inbox_outlined),
            selectedIcon:
                Icon(Icons.inbox_rounded, color: Color(0xFF2563EB)),
            label: 'Отклики',
          ),
          NavigationDestination(
            icon: Icon(Icons.business_outlined),
            selectedIcon:
                Icon(Icons.business_rounded, color: Color(0xFF2563EB)),
            label: 'Профиль',
          ),
        ],
      ),
    );
  }
}
