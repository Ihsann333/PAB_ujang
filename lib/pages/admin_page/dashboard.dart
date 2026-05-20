import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kostly_pa/services/notification_service.dart';
import 'admin_ui.dart';
import 'monitor_page.dart';
import 'approval_page.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const MonitorPage(),
    const ApprovalPage(),
  ];

  @override
  void initState() {
    super.initState();
    AppNotificationService.startRealtimeSyncForCurrentUser();
  }

  @override
  void dispose() {
    AppNotificationService.stopRealtimeSync();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminPalette.background,
      body: _pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 18,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BottomNavigationBar(
            backgroundColor: Colors.white,
            currentIndex: _selectedIndex,
            selectedItemColor: AdminPalette.primary,
            unselectedItemColor: Colors.grey,
            elevation: 0,
            selectedLabelStyle: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
            ),
            unselectedLabelStyle: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w500,
            ),
            onTap: (index) => setState(() => _selectedIndex = index),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.analytics_outlined),
                label: "Monitor",
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.how_to_reg_outlined),
                label: "Approval",
              ),
            ],
          ),
        ),
      ),
    );
  }
}
