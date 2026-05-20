import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kostly_pa/services/notification_service.dart';
import 'home_page.dart';
import 'owner_ui.dart';
import 'reminder_page.dart';
import 'profile_page.dart';

class OwnerDashboard extends StatefulWidget {
  const OwnerDashboard({super.key});

  @override
  State<OwnerDashboard> createState() => _OwnerDashboardState();
}

class _OwnerDashboardState extends State<OwnerDashboard> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const OwnerHomePage(),
    const ReminderPage(),
    const OwnerProfilePage(),
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
      backgroundColor: OwnerPalette.background,
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
            selectedItemColor: OwnerPalette.primary,
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
                icon: Icon(Icons.home_filled),
                label: "Home",
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.notifications_rounded),
                label: "Reminder",
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_rounded),
                label: "Profil",
              ),
            ],
          ),
        ),
      ),
    );
  }
}
