import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kostly_pa/pages/user_page/profile_page.dart';
import 'package:kostly_pa/pages/user_page/reminder_page_user.dart';
import 'package:kostly_pa/pages/user_page/user_home_page.dart';
import 'package:kostly_pa/pages/user_page/user_ui.dart';
import 'package:kostly_pa/services/notification_service.dart';

class UserDashboard extends StatefulWidget {
  const UserDashboard({super.key});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const UserHomePage(),
    const ReminderPageUser(),
    const UserProfilePage(),
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
      backgroundColor: UserPalette.background,
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
            onTap: (index) => setState(() => _selectedIndex = index),
            selectedItemColor: UserPalette.primary,
            unselectedItemColor: Colors.grey,
            elevation: 0,
            selectedLabelStyle: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
            ),
            unselectedLabelStyle: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w500,
            ),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_filled),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.notifications_rounded),
                label: 'Reminder',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_rounded),
                label: 'Profil',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
