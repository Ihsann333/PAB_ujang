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
  static const String _kostPrefix = '[KOSTLY_KOST]';
  static const String _tenantPrefix = '[KOSTLY_TENANT]';
  static const String _titlePrefix = '[KOSTLY_TITLE]';
  static const String _bodyPrefix = '[KOSTLY_BODY]';

  final supabase = SupabaseService.client;
  List reminders = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchReminders();
  }

  Future<void> fetchReminders() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => isLoading = false);
        return;
      }

      final profile = await supabase
          .from('profiles')
          .select('kost_id')
          .eq('id', user.id)
          .single();
      final kostId = profile['kost_id'];

      if (kostId == null) {
        if (mounted) {
          setState(() {
            reminders = [];
            isLoading = false;
          });
        }
        return;
      }

      final userKostId = kostId.toString();
      final kost = await supabase
          .from('kosts')
          .select('owner_id')
          .eq('id', userKostId)
          .single();
      final ownerId = kost['owner_id'].toString();

      List data;
      try {
        data = await supabase
            .from('reminders')
            .select()
            .eq('owner_id', ownerId)
            .order('created_at', ascending: false);
      } catch (_) {
        data = await supabase
            .from('reminders')
            .select()
            .eq('user_id', ownerId)
            .order('created_at', ascending: false);
      }

      data = data
          .where((r) => _isReminderForThisUserAndKost(r, userKostId, user.id))
          .toList();

      if (mounted) {
        setState(() {
          reminders = data;
          isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  bool _isReminderForThisUserAndKost(
    Map reminder,
    String currentKostId,
    String currentUserId,
  ) {
    final directKost = reminder['kost_id']?.toString();
    if (directKost != null && directKost.isNotEmpty) {
      if (directKost != currentKostId) return false;
    }

    for (final field in ['message', 'pesan']) {
      final raw = reminder[field];
      if (raw is String) {
        final parsed = _parsePackedMessage(raw);
        final packedKostId = parsed?['kost_id'];
        if (packedKostId != null && packedKostId.isNotEmpty) {
          if (packedKostId != currentKostId) return false;
        }

        final packedTenantId = parsed?['tenant_id'];
        if (packedTenantId != null && packedTenantId.isNotEmpty) {
          return packedTenantId == currentUserId;
        }
      }
    }

    return true;
  }

  Map<String, String>? _parsePackedMessage(String raw) {
    if (!raw.contains(_titlePrefix) || !raw.contains(_bodyPrefix)) {
      return null;
    }

    String? kostId;
    String? tenantId;
    final titleIndex = raw.indexOf(_titlePrefix);
    final bodyIndex = raw.indexOf(_bodyPrefix);
    if (titleIndex < 0 || bodyIndex < 0 || bodyIndex <= titleIndex) {
      return null;
    }

    if (raw.startsWith(_kostPrefix)) {
      final tenantIndex = raw.indexOf(_tenantPrefix, _kostPrefix.length);
      if (tenantIndex >= 0 && tenantIndex < titleIndex) {
        kostId = raw.substring(_kostPrefix.length, tenantIndex);
        tenantId = raw.substring(tenantIndex + _tenantPrefix.length, titleIndex);
      } else if (titleIndex > _kostPrefix.length) {
        kostId = raw.substring(_kostPrefix.length, titleIndex);
      }
    }

    if (tenantId == null) {
      final tenantIndex = raw.indexOf(_tenantPrefix);
      if (tenantIndex >= 0 && tenantIndex < titleIndex) {
        tenantId = raw.substring(tenantIndex + _tenantPrefix.length, titleIndex);
      }
    }

    final title = raw.substring(titleIndex + _titlePrefix.length, bodyIndex);
    final body = raw.substring(bodyIndex + _bodyPrefix.length);
    final result = {'title': title, 'body': body};
    if (kostId != null && kostId.isNotEmpty) result['kost_id'] = kostId;
    if (tenantId != null && tenantId.isNotEmpty) result['tenant_id'] = tenantId;
    return result;
  }

  String _reminderTitle(Map r) {
    final dynamic title = r['title'];
    if (title is String && title.trim().isNotEmpty) return title;

    for (final field in ['message', 'pesan']) {
      final raw = r[field];
      if (raw is String && raw.trim().isNotEmpty) {
        final parsed = _parsePackedMessage(raw);
        return parsed != null ? parsed['title']! : raw;
      }
    }

    return 'Pengumuman';
  }

  String _reminderText(Map r) {
    for (final field in ['message', 'pesan', 'description']) {
      final raw = r[field];
      if (raw is String && raw.trim().isNotEmpty) {
        final parsed = _parsePackedMessage(raw);
        return parsed != null ? parsed['body']! : raw;
      }
    }
    return '';
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
