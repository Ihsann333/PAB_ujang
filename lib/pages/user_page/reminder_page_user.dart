import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:kostly_pa/services/supabase_service.dart';

class ReminderPageUser extends StatefulWidget {
  const ReminderPageUser({super.key});

  @override
  State<ReminderPageUser> createState() => _ReminderPageUserState();
}

class _ReminderPageUserState extends State<ReminderPageUser> {
  List reminders = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchReminders();
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2E8DA),
      appBar: AppBar(
        title: Text(
          "Notifikasi",
          style: GoogleFonts.sora(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : reminders.isEmpty
          ? Center(
              child: Text(
                "Belum ada pengumuman",
                style: GoogleFonts.plusJakartaSans(color: Colors.grey[700]),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: reminders.length,
              itemBuilder: (context, index) {
                final r = reminders[index];

                return Card(
                  color: const Color(0xFFFFFBF7),
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFFE8DCCB)),
                  ),
                  child: ListTile(
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _reminderTitle(r),
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF2D241A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatReminderTime(r),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF7A6A58),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _reminderText(r),
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF5F5549),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
