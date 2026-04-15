import 'package:flutter/material.dart';
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

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) setState(() => _selectedTime = picked);
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
    setState(() => isSending = true);
    try {
      DateTime? reminderAt;
      if (_selectedDate != null && _selectedTime != null) {
        reminderAt = DateTime(_selectedDate!.year, _selectedDate!.month,
            _selectedDate!.day, _selectedTime!.hour, _selectedTime!.minute);
      }

      final ownerId = supabase.auth.currentUser?.id;
      if (ownerId == null) throw Exception("User belum login");

      bool inserted = false;
      Object? lastError;

      final nowIso = DateTime.now().toIso8601String();
      final title = _titleCtrl.text.trim();
      final text = _msgCtrl.text.trim();
      final packedText = _packTitleAndMessage(title, text, selectedKostId!);
      final reminderAtIso = reminderAt?.toIso8601String();

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
        // Minimal payload terakhir
        {'owner_id': ownerId, 'kost_id': selectedKostId, 'message': packedText},
        {'user_id': ownerId, 'kost_id': selectedKostId, 'message': packedText},
        {'message': packedText},
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
      setState(() {
        _selectedDate = null;
        _selectedTime = null;
      });
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

  String _formatCreatedAt(Map r) {
    final dynamic raw = r['created_at'];
    if (raw == null) return '-';
    final parsed = DateTime.tryParse(raw.toString());
    if (parsed == null) return raw.toString();
    return DateFormat('dd MMM yyyy, HH:mm').format(parsed.toLocal());
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
                  children: const [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Color(0xFFE24D56),
                      child: Icon(Icons.delete_outline, color: Colors.white, size: 18),
                    ),
                    SizedBox(width: 10),
                    Text(
                      "Hapus Reminder",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2D241A),
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 18, 18, 6),
                child: Text(
                  "Yakin ingin menghapus reminder ini?",
                  style: TextStyle(fontSize: 16, color: Color(0xFF4B4339)),
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
                      child: const Text("Batal"),
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
                      child: const Text("Hapus", style: TextStyle(fontWeight: FontWeight.w700)),
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
            const Text(
              "Kirim Reminder",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF2D241A)),
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
                        hint: const Text("Pilih Kost Tujuan"),
                        items: myKosts
                            .map(
                              (k) => DropdownMenuItem<String>(
                                value: k['id'].toString(),
                                child: Text(k['name']?.toString() ?? 'Kost'),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() => selectedKostId = value),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            backgroundColor: const Color(0xFFF3E5D3),
                            foregroundColor: const Color(0xFF9C5A1A),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: _pickDate,
                          icon: const Icon(Icons.calendar_today),
                          label: Text(_selectedDate == null ? "Pilih Tanggal" : "Selesai"),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            backgroundColor: const Color(0xFFF3E5D3),
                            foregroundColor: const Color(0xFF9C5A1A),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: _pickTime,
                          icon: const Icon(Icons.access_time),
                          label: Text(_selectedTime == null ? "Pilih Jam" : "Selesai"),
                        ),
                      ),
                    ],
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
                      style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              "Reminder Tersimpan",
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF2D241A)),
            ),
            const SizedBox(height: 10),
            if (isLoadingReminders)
              const Center(child: CircularProgressIndicator())
            else if (reminders.isEmpty)
              const Center(child: Text("Belum ada reminder"))
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
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    leading: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE7C8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.notifications_active, color: Color(0xFF9C5A1A)),
                    ),
                    title: Text(
                      _reminderTitle(r),
                      style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF2D241A)),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 3),
                        Text(_reminderText(r), style: const TextStyle(color: Color(0xFF5A5043))),
                        const SizedBox(height: 6),
                        Text(
                          "Diinput: ${_formatCreatedAt(r)}",
                          style: const TextStyle(fontSize: 11, color: Color(0xFF9B948C)),
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      tooltip: "Hapus",
                      icon: const Icon(Icons.delete_outline, color: Color(0xFFE24D56)),
                      onPressed: () => _confirmDeleteReminder(r),
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
