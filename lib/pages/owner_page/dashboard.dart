import 'package:flutter/material.dart';
import 'home_page.dart';
import 'reminder_page.dart';
import 'profile_page.dart';

class OwnerDashboard extends StatefulWidget {
  const OwnerDashboard({super.key});

  @override
  State<OwnerDashboard> createState() => _OwnerDashboardState();
}

class _OwnerDashboardState extends State<OwnerDashboard> {
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const OwnerHomePage(),
      const ReminderPage(),
      const OwnerProfilePage(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFE8DCCB),
      body: pages[selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        selectedItemColor: const Color(0xFF9C5A1A),
        unselectedItemColor: Colors.grey,
        onTap: (i) => setState(() => selectedIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard, size: 28), label: "Dashboard"),
          BottomNavigationBarItem(icon: Icon(Icons.alarm, size: 28), label: "Reminder"),
          BottomNavigationBarItem(icon: Icon(Icons.person, size: 28), label: "Profil"),
        ],
      ),
    );
  }
}