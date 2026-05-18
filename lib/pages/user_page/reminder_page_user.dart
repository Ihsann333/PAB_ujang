import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:kostly_pa/services/notification_service.dart'; // ✅ TAMBAHAN
import 'package:kostly_pa/services/supabase_service.dart';
import 'package:kostly_pa/pages/user_page/user_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // ✅ TAMBAHAN

class ReminderPageUser extends StatefulWidget {
  const ReminderPageUser({super.key});

  @override
  State<ReminderPageUser> createState() => _ReminderPageUserState();
}

class _ReminderPageUserState extends State<ReminderPageUser> {
  List reminders = [];
  bool isLoading = true;
  RealtimeChannel? _reminderChannel; // ✅ TAMBAHAN

  @override
  void initState() {
    super.initState();
    fetchReminders();
    _subscribeReminders(); // ✅ TAMBAHAN
  }

  // ✅ TAMBAHAN: Realtime listener agar notifikasi muncul otomatis
  Future<void> _subscribeReminders() async {
    final supabase = SupabaseService.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    // Ambil kost_id user dulu
    final profile = await supabase
        .from('profiles')
        .select('kost_id')
        .eq('id', user.id)
        .maybeSingle();

    final kostId = profile?['kost_id']?.toString();
    if (kostId == null) return;

    // Listen realtime ke tabel reminders
    _reminderChannel = supabase
        .channel('reminders-user-$kostId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'reminders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'kost_id',
            value: kostId,
          ),
          callback: (payload) async {
            final newRow = payload.newRecord;
            final message = newRow['message']?.toString() ?? '';
            final parsed = SupabaseService.parseReminder(message);

            // Cek apakah reminder ini untuk semua atau khusus user ini
            final tenantId = parsed?['tenant_id'];
            if (tenantId != null && tenantId != user.id) return;

            final title = parsed?['title'] ?? 'Pengumuman Kost';
            final body = parsed?['body'] ?? message;

            // Tampilkan notifikasi lokal ke penghuni
            await AppNotificationService.show(title: title, body: body);

            // Refresh list reminder
            fetchReminders();
          },
        )
        .subscribe();
  }

  // ✅ Ambil dari service (sinkron dengan Home)
  Future<void> fetchReminders() async {
    try {
      final supabase = SupabaseService.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        setState(() => isLoading = false);
        return;
      }

      // 🔥 ambil kost_id user
      final profile = await supabase
          .from('profiles')
          .select('kost_id')
          .eq('id', user.id)
          .single();

      final kostId = profile['kost_id']?.toString();

      final data = await SupabaseService.getUserReminders();

      // 🔥 FILTER (INI KUNCI NYA)
      final filtered = data.where((r) {
        final reminderKost = r['kost_id']?.toString();

        // filter berdasarkan kost
        if (kostId != null && reminderKost != null) {
          if (kostId != reminderKost) return false;
        }

        // cek kalau ada tenant khusus
        final parsed = SupabaseService.parseReminder(
          r['message'] ?? r['pesan'] ?? '',
        );

        if (parsed != null && parsed['tenant_id'] != null) {
          return parsed['tenant_id'] == user.id;
        }

        return true;
      }).toList();

      if (mounted) {
        setState(() {
          reminders = List<Map<String, dynamic>>.from(filtered);
          isLoading = false;
        });
      }
    } catch (e) {
      print("ERROR: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  // 🔽 Ambil title (pakai parser service kalau perlu)
  String _reminderTitle(Map r) {
    final dynamic title = r['title'];
    if (title is String && title.trim().isNotEmpty) return title;

    for (final field in ['message', 'pesan']) {
      final raw = r[field];
      if (raw is String && raw.trim().isNotEmpty) {
        final parsed = SupabaseService.parseReminder(raw);
        return parsed != null ? parsed['title']! : raw;
      }
    }

    return 'Pengumuman';
  }

  // 🔽 Ambil isi pesan
  String _reminderText(Map r) {
    for (final field in ['message', 'pesan', 'description']) {
      final raw = r[field];
      if (raw is String && raw.trim().isNotEmpty) {
        final parsed = SupabaseService.parseReminder(raw);
        return parsed != null ? parsed['body']! : raw;
      }
    }
    return '';
  }

  // 🔽 Format waktu (TIDAK DIUBAH)
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
    _reminderChannel?.unsubscribe(); // ✅ TAMBAHAN
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
                          _reminderTitle(r),
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
                    _reminderText(r),
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
