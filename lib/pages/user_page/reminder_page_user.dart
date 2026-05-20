import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:kostly_pa/pages/user_page/user_ui.dart';
import 'package:kostly_pa/services/notification_service.dart';
import 'package:kostly_pa/services/supabase_service.dart';

class ReminderPageUser extends StatefulWidget {
  const ReminderPageUser({super.key});

  @override
  State<ReminderPageUser> createState() => _ReminderPageUserState();
}

class _ReminderPageUserState extends State<ReminderPageUser> {
  List reminders = [];
  bool isLoading = true;
  StreamSubscription<NotificationSyncEvent>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    fetchReminders();
    _notificationSubscription = AppNotificationService.events.listen((event) {
      if (!mounted) return;
      if (event.scope == 'user_reminders' || event.scope == 'user_payments') {
        fetchReminders();
      }
    });
  }

  Future<void> fetchReminders() async {
    try {
      final supabase = SupabaseService.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        setState(() => isLoading = false);
        return;
      }

      final profile = await supabase
          .from('profiles')
          .select('kost_id')
          .eq('id', user.id)
          .single();

      final kostId = profile['kost_id']?.toString();
      final data = await SupabaseService.getUserReminders();

      final filtered = data.where((r) {
        if (kostId == null || kostId.isEmpty) return false;
        return SupabaseService.isReminderForUser(
          r,
          currentKostId: kostId,
          currentUserId: user.id,
        );
      }).toList();

      if (mounted) {
        setState(() {
          reminders = List<Map<String, dynamic>>.from(filtered);
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('ERROR REMINDER USER: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  String _formatReminderTime(Map r) {
    final dynamic raw = r['reminder_at'] ?? r['created_at'] ?? r['waktu'];
    if (raw == null) return '--:--';

    final parsed = DateTime.tryParse(raw.toString());
    if (parsed == null) return '--:--';

    final local = parsed.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDay = DateTime(local.year, local.month, local.day);
    final dayDiff = today.difference(targetDay).inDays;

    if (dayDiff <= 0) return DateFormat('HH:mm').format(local);
    if (dayDiff == 1) return 'Kemarin';
    return DateFormat('dd/MM/yy').format(local);
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UserPalette.background,
      body: SafeArea(
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: UserPalette.primary),
              )
            : RefreshIndicator(
                onRefresh: fetchReminders,
                color: UserPalette.primary,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  children: [
                    const UserPageHeader(
                      title: 'Notifikasi',
                      subtitle:
                          'Lihat pengumuman dan pengingat terbaru dari kost Anda.',
                    ),
                    const SizedBox(height: 22),
                    const UserSectionHeader(
                      title: 'Semua Pengumuman',
                      subtitle: 'Daftar notifikasi yang relevan untuk akunmu.',
                    ),
                    const SizedBox(height: 14),
                    if (reminders.isEmpty)
                      const UserEmptyStateCard(
                        icon: Icons.notifications_off_rounded,
                        title: 'Belum Ada Pengumuman',
                        subtitle:
                            'Nanti notifikasi dari owner atau sistem akan muncul di sini.',
                      )
                    else
                      ...reminders.map((r) => _buildReminderCard(r)),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildReminderCard(Map r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: UserSurfaceCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: UserPalette.softAccent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.notifications_active_rounded,
                color: UserPalette.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          SupabaseService.reminderTitle(r),
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: UserPalette.primaryDark,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatReminderTime(r),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: UserPalette.muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    SupabaseService.reminderBody(r),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      height: 1.45,
                      color: const Color(0xFF5F5549),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
