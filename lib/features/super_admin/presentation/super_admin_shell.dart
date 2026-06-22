import 'package:flutter/material.dart';
import 'pages/pages.dart';

class SuperAdminShell extends StatefulWidget {
  const SuperAdminShell({Key? key}) : super(key: key);

  @override
  State<SuperAdminShell> createState() => _SuperAdminShellState();
}

class _SuperAdminShellState extends State<SuperAdminShell> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const SuperAdminDashboard(),
    const BranchManagementPage(),
    const RoyaltyManagementPage(),
    const ReportsPage(),
  ];

  final List<String> _pageLabels = [
    'Dashboard',
    'Branches',
    'Royalties',
    'Reports',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.dashboard),
            label: _pageLabels[0],
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.store),
            label: _pageLabels[1],
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.attach_money),
            label: _pageLabels[2],
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.assessment),
            label: _pageLabels[3],
          ),
        ],
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}
