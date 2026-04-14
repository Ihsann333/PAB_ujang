import 'package:flutter/material.dart';
import 'monitor_page.dart';
import 'approval_page.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int selectedIndex = 0;

  final List<Widget> pages = [
    const MonitorPage(),
    const ApprovalPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2E8DA),
      body: pages[selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        selectedItemColor: const Color(0xFF9C5A1A),
        unselectedItemColor: Colors.grey,
        onTap: (i) => setState(() => selectedIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.analytics_outlined), label: "Monitor"),
          BottomNavigationBarItem(icon: Icon(Icons.how_to_reg_outlined), label: "Approval"),
        ],
      ),
    );
  }
}