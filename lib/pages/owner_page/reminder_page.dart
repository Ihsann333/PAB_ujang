import 'package:flutter/material.dart';
import 'package:kostly_pa/services/supabase_service.dart';

class ReminderPage extends StatefulWidget {
  const ReminderPage({super.key});

  @override
  State<ReminderPage> createState() => _ReminderPageState();
}

class _ReminderPageState extends State<ReminderPage> {
  final supabase = SupabaseService.client;
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _msgCtrl = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool isSending = false;
  List reminders = [];
  bool isLoadingReminders = true;

  @override
  void initState() {
    super.initState();
    fetchReminders();
  }

  Future<void> fetchReminders() async {
    if (!mounted) return;
    setState(() => isLoadingReminders = true);
    try {
      final userId = supabase.auth.currentUser?.id;
      final data = await supabase
          .from('reminders')
          .select()
          .eq('owner_id', userId ?? '')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          reminders = data as List;
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
    setState(() => isSending = true);
    try {
      DateTime? reminderAt;
      if (_selectedDate != null && _selectedTime != null) {
        reminderAt = DateTime(_selectedDate!.year, _selectedDate!.month,
            _selectedDate!.day, _selectedTime!.hour, _selectedTime!.minute);
      }

      await supabase.from('reminders').insert({
        'owner_id': supabase.auth.currentUser?.id,
        'title': _titleCtrl.text,
        'message': _msgCtrl.text,
        'reminder_at': reminderAt?.toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      });

      _titleCtrl.clear();
      _msgCtrl.clear();
      setState(() {
        _selectedDate = null;
        _selectedTime = null;
      });
      fetchReminders();
    } finally {
      if (mounted) setState(() => isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2E8DA),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text("Kirim Reminder", 
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: "Judul Reminder",
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _msgCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: "Isi Pesan",
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today),
                    label: Text(_selectedDate == null ? "Pilih Tanggal" : "Selesai"),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.access_time),
                    label: Text(_selectedTime == null ? "Pilih Jam" : "Selesai"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9C5A1A),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: isSending ? null : sendReminder,
              child: Text(isSending ? "MENGIRIM..." : "KIRIM REMINDER"),
            ),
            const SizedBox(height: 30),
            const Text("Reminder Tersimpan", 
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (isLoadingReminders)
              const Center(child: CircularProgressIndicator())
            else if (reminders.isEmpty)
              const Center(child: Text("Belum ada reminder"))
            else
              ...reminders.map((r) => Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: const Icon(Icons.notifications_active, color: Color(0xFF9C5A1A)),
                      title: Text(r['title'] ?? '-'),
                      subtitle: Text(r['message'] ?? '-'),
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}