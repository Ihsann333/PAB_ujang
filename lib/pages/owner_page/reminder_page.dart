import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:kostly_pa/services/supabase_service.dart';

class ReminderPage extends StatefulWidget {
  const ReminderPage({super.key});

  @override
  State<ReminderPage> createState() => _ReminderPageState();
}

class _ReminderPageState extends State<ReminderPage> {
  static const String _titlePrefix = '[KOSTLY_TITLE]';
  static const String _bodyPrefix = '[KOSTLY_BODY]';
  static const String _kostPrefix = '[KOSTLY_KOST]';

  final supabase = SupabaseService.client;
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _msgCtrl = TextEditingController();

  List myKosts = [];
  String? selectedKostId;
  bool isSending = false;
  List reminders = [];
  bool isLoadingReminders = true;

  @override
  void initState() {
    super.initState();
    _fetchMyKosts();
    fetchReminders();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchMyKosts() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final data = await supabase
          .from('kosts')
          .select('id,name,is_approved')
          .eq('owner_id', userId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          myKosts = data as List;
          if (selectedKostId == null && myKosts.isNotEmpty) {
            selectedKostId = myKosts.first['id'].toString();
          }
        });
      }
    } catch (_) {}
  }

  Future<void> fetchReminders() async {
    if (!mounted) return;
    setState(() => isLoadingReminders = true);
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) setState(() => isLoadingReminders = false);
        return;
      }

      List data;
      try {
        data = await supabase
            .from('reminders')
            .select()
            .eq('owner_id', userId)
            .order('created_at', ascending: false);
      } catch (_) {
        data = await supabase
            .from('reminders')
            .select()
            .eq('user_id', userId)
            .order('created_at', ascending: false);
      }

      if (mounted) {
        setState(() {
          reminders = data;
          isLoadingReminders = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoadingReminders = false);
    }
  }
  

  Future<void> sendReminder() async {
  if (_titleCtrl.text.isEmpty || _msgCtrl.text.isEmpty) return;
  
  if (selectedKostId == null || selectedKostId!.isEmpty) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pilih kost tujuan terlebih dahulu")),
      );
    }
    return;
  }

  // --- TAMBAHKAN LOGIKA PENGECEKAN DI SINI ---
  final selectedKost = myKosts.firstWhere(
    (k) => k['id'].toString() == selectedKostId,
    orElse: () => null,
  );

  if (selectedKost == null || selectedKost['is_approved'] != true) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Kost belum disetujui (ACC). Reminder tidak dapat dikirim."),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
    return;
  }
  // -------------------------------------------

  setState(() => isSending = true);
  try {
    // ... sisa kode pengiriman yang sudah ada ...
    final reminderAt = DateTime.now();
    // (Lanjutkan dengan kode insert kamu yang di bawahnya)

      final ownerId = supabase.auth.currentUser?.id;
      if (ownerId == null) throw Exception("User belum login");

      bool inserted = false;
      Object? lastError;

      final nowIso = DateTime.now().toIso8601String();
      final title = _titleCtrl.text.trim();
      final text = _msgCtrl.text.trim();
      final packedText = _packTitleAndMessage(title, text, selectedKostId!);
      final reminderAtIso = reminderAt.toIso8601String();

      final payloads = <Map<String, dynamic>>[
        // Variasi modern
        {'owner_id': ownerId, 'kost_id': selectedKostId, 'title': title, 'message': packedText, 'reminder_at': reminderAtIso, 'created_at': nowIso},
        {'user_id': ownerId, 'kost_id': selectedKostId, 'title': title, 'message': packedText, 'reminder_at': reminderAtIso, 'created_at': nowIso},
        {'owner_id': ownerId, 'kost_id': selectedKostId, 'title': title, 'message': packedText, 'created_at': nowIso},
        {'user_id': ownerId, 'kost_id': selectedKostId, 'title': title, 'message': packedText, 'created_at': nowIso},
        // Tanpa kolom title (jika tabel tidak punya title)
        {'owner_id': ownerId, 'kost_id': selectedKostId, 'message': packedText, 'reminder_at': reminderAtIso, 'created_at': nowIso},
        {'user_id': ownerId, 'kost_id': selectedKostId, 'message': packedText, 'reminder_at': reminderAtIso, 'created_at': nowIso},
        {'owner_id': ownerId, 'kost_id': selectedKostId, 'message': packedText, 'created_at': nowIso},
        {'user_id': ownerId, 'kost_id': selectedKostId, 'message': packedText, 'created_at': nowIso},
        // Variasi kolom Indonesia (legacy)
        {'owner_id': ownerId, 'kost_id': selectedKostId, 'judul': title, 'pesan': packedText, 'waktu': reminderAtIso, 'created_at': nowIso},
        {'user_id': ownerId, 'kost_id': selectedKostId, 'judul': title, 'pesan': packedText, 'waktu': reminderAtIso, 'created_at': nowIso},
        // Minimal payload terakhir (tetap menyertakan relasi owner + kost)
        {'owner_id': ownerId, 'kost_id': selectedKostId, 'message': packedText},
        {'user_id': ownerId, 'kost_id': selectedKostId, 'message': packedText},
      ];

      for (final payload in payloads) {
        if (inserted) break;
        final cleanedPayload = <String, dynamic>{};
        payload.forEach((key, value) {
          if (value != null) cleanedPayload[key] = value;
        });
        try {
          await supabase.from('reminders').insert(cleanedPayload);
          inserted = true;
        } catch (e) {
          lastError = e;
        }
      }

      if (!inserted) {
        throw Exception("Gagal menyimpan reminder. Detail: $lastError");
      }

      _titleCtrl.clear();
      _msgCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Reminder berhasil dikirim")),
        );
      }
      fetchReminders();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal kirim reminder: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => isSending = false);
    }
  }

  String _reminderText(Map r) {
    final dynamic message = r['message'];
    if (message is String && message.trim().isNotEmpty) {
      final parsed = _parsePackedMessage(message);
      return parsed != null ? parsed['body']! : message;
    }
    final dynamic pesan = r['pesan'];
    if (pesan is String && pesan.trim().isNotEmpty) {
      final parsed = _parsePackedMessage(pesan);
      return parsed != null ? parsed['body']! : pesan;
    }
    final dynamic description = r['description'];
    if (description is String && description.trim().isNotEmpty) {
      final parsed = _parsePackedMessage(description);
      return parsed != null ? parsed['body']! : description;
    }
    return '-';
  }

  String _reminderTitle(Map r) {
    final dynamic title = r['title'];
    if (title is String && title.trim().isNotEmpty) return title;
    final dynamic judul = r['judul'];
    if (judul is String && judul.trim().isNotEmpty) return judul;
    final dynamic message = r['message'];
    if (message is String && message.trim().isNotEmpty) {
      final parsed = _parsePackedMessage(message);
      if (parsed != null && parsed['title']!.trim().isNotEmpty) return parsed['title']!;
    }
    final dynamic pesan = r['pesan'];
    if (pesan is String && pesan.trim().isNotEmpty) {
      final parsed = _parsePackedMessage(pesan);
      if (parsed != null && parsed['title']!.trim().isNotEmpty) return parsed['title']!;
    }
    return 'Reminder';
  }

  String _formatReminderTime(Map r) {
    final dynamic raw = r['reminder_at'] ?? r['waktu'] ?? r['created_at'];
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

  Future<void> _deleteReminder(Map r) async {
    try {
      bool deleted = false;

      if (r['id'] != null) {
        await supabase.from('reminders').delete().eq('id', r['id']);
        deleted = true;
      }

      if (!deleted) {
        final ownerId = supabase.auth.currentUser?.id;
        final createdAt = r['created_at'];
        if (ownerId != null && createdAt != null) {
          try {
            await supabase
                .from('reminders')
                .delete()
                .eq('owner_id', ownerId)
                .eq('created_at', createdAt);
            deleted = true;
          } catch (_) {
            await supabase
                .from('reminders')
                .delete()
                .eq('user_id', ownerId)
                .eq('created_at', createdAt);
            deleted = true;
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Reminder berhasil dihapus")),
        );
      }
      fetchReminders();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal hapus reminder: $e")),
        );
      }
    }
  }

  Future<void> _confirmDeleteReminder(Map r) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        contentPadding: EdgeInsets.zero,
        content: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBF7),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE9D7C2)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF5A3A17).withOpacity(0.14),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFFE7E8), Color(0xFFFFD4D7)],
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Color(0xFFE24D56),
                      child: Icon(Icons.delete_outline, color: Colors.white, size: 18),
                    ),
                    SizedBox(width: 10),
                    Text(
                      "Hapus Reminder",
                      style: GoogleFonts.sora(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF2D241A),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(18, 18, 18, 6),
                child: Text(
                  "Yakin ingin menghapus reminder ini?",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    color: const Color(0xFF4B4339),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF7B6A56),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(
                        "Batal",
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF7B6A56),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE24D56),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(
                        "Hapus",
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (ok == true) {
      await _deleteReminder(r);
    }
  }

  String _packTitleAndMessage(String title, String message, String kostId) {
    return '$_kostPrefix$kostId$_titlePrefix$title$_bodyPrefix$message';
  }

  Map<String, String>? _parsePackedMessage(String raw) {
    if (!raw.contains(_titlePrefix) || !raw.contains(_bodyPrefix)) return null;

    String work = raw;
    String? kostId;
    if (work.startsWith(_kostPrefix)) {
      final titleStart = work.indexOf(_titlePrefix);
      if (titleStart > _kostPrefix.length) {
        kostId = work.substring(_kostPrefix.length, titleStart);
      }
    }

    final titleIndex = work.indexOf(_titlePrefix);
    final bodyIndex = work.indexOf(_bodyPrefix);
    if (titleIndex < 0 || bodyIndex < 0 || bodyIndex <= titleIndex) return null;

    final title = work.substring(titleIndex + _titlePrefix.length, bodyIndex);
    final body = work.substring(bodyIndex + _bodyPrefix.length);
    final result = {'title': title, 'body': body};
    if (kostId != null && kostId.isNotEmpty) result['kost_id'] = kostId;
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2E8DA),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              "Kirim Reminder",
              style: GoogleFonts.sora(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF2D241A),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFCF7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFEADBC9)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF5A3A17).withOpacity(0.07),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _titleCtrl,
                    decoration: InputDecoration(
                      labelText: "Judul Reminder",
                      labelStyle: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF6F6256),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8F0E4),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _msgCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: "Isi Pesan",
                      labelStyle: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF6F6256),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8F0E4),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F0E4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedKostId,
                        isExpanded: true,
                        hint: Text("Pilih Kost Tujuan", style: GoogleFonts.plusJakartaSans()),
                        items: myKosts.map((k) {
                          bool isApproved = k['is_approved'] == true;
                          return DropdownMenuItem<String>(
                            value: k['id'].toString(),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    k['name']?.toString() ?? 'Kost',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: isApproved ? const Color(0xFF2D241A) : Colors.grey,
                                    ),
                                  ),
                                ),
                                if (!isApproved)
                                  const Icon(Icons.lock_clock, size: 16, color: Colors.orange),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) => setState(() => selectedKostId = value),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 14),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9C5A1A),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    onPressed: isSending ? null : sendReminder,
                    child: Text(
                      isSending ? "MENGIRIM..." : "KIRIM REMINDER",
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Text(
              "Reminder Tersimpan",
              style: GoogleFonts.sora(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF2D241A),
              ),
            ),
            const SizedBox(height: 10),
            if (isLoadingReminders)
              const Center(child: CircularProgressIndicator())
            else if (reminders.isEmpty)
              Center(child: Text("Belum ada reminder", style: GoogleFonts.plusJakartaSans()))
            else
              ...reminders.map(
                (r) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFCF7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFEADBC9)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF5A3A17).withOpacity(0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE7C8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.notifications_active, color: Color(0xFF9C5A1A)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Stack(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 86),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _reminderTitle(r),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF2D241A),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      _reminderText(r),
                                      style: GoogleFonts.plusJakartaSans(color: const Color(0xFF5A5043)),
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                right: 0,
                                top: 0,
                                child: PopupMenuButton<String>(
                                  tooltip: "Opsi reminder",
                                  position: PopupMenuPosition.under,
                                  offset: const Offset(0, 6),
                                  elevation: 8,
                                  padding: EdgeInsets.zero,
                                  color: const Color(0xFFFFFBF7),
                                  surfaceTintColor: Colors.transparent,
                                  constraints: const BoxConstraints(minWidth: 170),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  child: SizedBox(
                                    width: 72,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          _formatReminderTime(r),
                                          maxLines: 1,
                                          softWrap: false,
                                          overflow: TextOverflow.visible,
                                          textAlign: TextAlign.right,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF7A6A58),
                                          ),
                                        ),
                                        const SizedBox(height: 1),
                                        const Icon(
                                          Icons.keyboard_arrow_down,
                                          size: 16,
                                          color: Color(0xFF7A6A58),
                                        ),
                                      ],
                                    ),
                                  ),
                                  onSelected: (value) {
                                    if (value == 'delete') {
                                      _confirmDeleteReminder(r);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    PopupMenuItem<String>(
                                      value: 'delete',
                                      height: 42,
                                      child: Row(
                                        children: [
                                          const Icon(Icons.delete_outline, color: Color(0xFFE24D56), size: 20),
                                          const SizedBox(width: 10),
                                          Text(
                                            "Hapus reminder",
                                            style: GoogleFonts.plusJakartaSans(
                                              color: const Color(0xFF2D241A),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ); 
  }
}
