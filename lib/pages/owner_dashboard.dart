import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kostly_pa/core/supabase_service.dart';

// ─────────────────────────────────────────────
// OWNER DASHBOARD
// ─────────────────────────────────────────────
class OwnerDashboard extends StatefulWidget {
  const OwnerDashboard({super.key});

  @override
  State<OwnerDashboard> createState() => _OwnerDashboardState();
}

class _OwnerDashboardState extends State<OwnerDashboard> {
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const OwnerHomePage(),
      const ReminderPage(),
      const OwnerProfilePage(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFE8DCCB),
      body: pages[selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        selectedItemColor: const Color(0xFF9C5A1A),
        unselectedItemColor: Colors.grey,
        onTap: (i) => setState(() => selectedIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard, size: 28), label: "Dashboard"),
          BottomNavigationBarItem(icon: Icon(Icons.alarm, size: 28), label: "Reminder"),
          BottomNavigationBarItem(icon: Icon(Icons.person, size: 28), label: "Profil"),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// OWNER HOME PAGE — Dashboard summary
// ─────────────────────────────────────────────
class OwnerHomePage extends StatefulWidget {
  const OwnerHomePage({super.key});

  @override
  State<OwnerHomePage> createState() => _OwnerHomePageState();
}

class _OwnerHomePageState extends State<OwnerHomePage> {
  final supabase = SupabaseService.client;
  final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  bool isLoading = true;
  int totalKos = 0;
  int totalPenghuni = 0;
  int totalProfit = 0;
  List kosList = [];

  @override
  void initState() {
    super.initState();
    fetchDashboard();
  }

Future<void> fetchDashboard() async {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return;

  try {
    // 1. Ambil data kos (Hanya yang sudah di-approve oleh admin)
    final kosResponse = await supabase
        .from('kosts')
        .select()
        .eq('owner_id', userId)
        .eq('is_approved', true); // Filter agar hanya kos aktif yang muncul

    final List kos = kosResponse as List;

    // 2. Ambil penghuni secara paralel (lebih cepat daripada for-loop biasa)
    final List<Future<dynamic>> penghuniFutures = kos.map((k) {
      return supabase
          .from('tenants')
          .select()
          .eq('kost_id', k['id'])
          .eq('is_active', true);
    }).toList();

    final results = await Future.wait(penghuniFutures);

    int penghuniCount = 0;
    int profit = 0;

    for (int i = 0; i < results.length; i++) {
      final List tenantsInKos = results[i] as List;
      final int harga = (kos[i]['price'] as num?)?.toInt() ?? 0;
      
      penghuniCount += tenantsInKos.length;
      profit += harga * tenantsInKos.length;
    }

    if (mounted) {
      setState(() {
        kosList = kos;
        totalKos = kos.length;
        totalPenghuni = penghuniCount;
        totalProfit = profit;
        isLoading = false;
      });
    }
  } catch (e) {
    debugPrint("Error dashboard: $e");
    if (mounted) setState(() => isLoading = false);
  }
}

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: fetchDashboard,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 8),
            const Text(
              "Dashboard Owner",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              "Selamat datang kembali!",
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),

            // ── SUMMARY CARDS ──
            Row(
              children: [
                Expanded(child: _summaryCard("Total Kos", "$totalKos", Icons.home_work)),
                const SizedBox(width: 12),
                Expanded(child: _summaryCard("Penghuni Aktif", "$totalPenghuni", Icons.people)),
              ],
            ),
            const SizedBox(height: 12),
            _profitCard(currency.format(totalProfit)),
            const SizedBox(height: 24),

            // ── LIST KOS ──
            const Text(
              "Kos Saya",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...kosList.map((kos) => _kosCard(kos)),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF9C5A1A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white70, size: 28),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
                fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _profitCard(String profit) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF6B3A10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.attach_money, color: Colors.amber, size: 36),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Total Profit Bulan Ini",
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 4),
              Text(
                profit,
                style: const TextStyle(
                    fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kosCard(Map kos) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: const CircleAvatar(
          backgroundColor: Color(0xFF9C5A1A),
          child: Icon(Icons.home, color: Colors.white),
        ),
        title: Text(kos['name'] ?? '-',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("Harga: Rp ${kos['price'] ?? '-'} / bulan"),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// REMINDER PAGE — improved GUI
// ─────────────────────────────────────────────
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
            
            // Input Judul
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
            
            // Input Pesan
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

            // Picker Tanggal & Waktu (Ini yang bikin pesan orange hilang)
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

// ─────────────────────────────────────────────
// OWNER PROFILE PAGE
// ─────────────────────────────────────────────
class OwnerProfilePage extends StatefulWidget {
  const OwnerProfilePage({super.key});

  @override
  State<OwnerProfilePage> createState() => _OwnerProfilePageState();
}

class _OwnerProfilePageState extends State<OwnerProfilePage> {
  final supabase = SupabaseService.client;
  
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();
  final TextEditingController _priceCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  
  bool isSaving = false; 
  bool _includeListrik = false; 
  bool _includeAir = false;     

  // Fungsi untuk memunculkan dialog tambah kos
  void _showAddKostDialog() {
    showDialog(
      context: context,
      barrierDismissible: !isSaving,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Daftarkan Unit Kos Baru", 
            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF9C5A1A))),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildField(_nameCtrl, "Nama Kos", Icons.home, "Contoh: Kostly Residence"),
                const SizedBox(height: 12),
                _buildField(_addressCtrl, "Alamat Lengkap", Icons.location_on, "Jl. Merdeka No. 123"),
                const SizedBox(height: 12),
                _buildField(_priceCtrl, "Harga per Bulan", Icons.payments, "1500000", isNumber: true),
                const SizedBox(height: 12),
                
                SwitchListTile(
                  title: const Text("Termasuk Listrik", style: TextStyle(fontSize: 14)),
                  value: _includeListrik,
                  activeThumbColor: const Color(0xFF9C5A1A),
                  onChanged: (val) => setModalState(() => _includeListrik = val),
                ),
                SwitchListTile(
                  title: const Text("Termasuk Air", style: TextStyle(fontSize: 14)),
                  value: _includeAir,
                  activeThumbColor: const Color(0xFF9C5A1A),
                  onChanged: (val) => setModalState(() => _includeAir = val),
                ),

                const SizedBox(height: 12),
                _buildField(_descCtrl, "Deskripsi kos", Icons.description, "AC, WiFi, dll", maxLines: 3),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(context),
              child: const Text("Batal"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9C5A1A),
                foregroundColor: Colors.white,
              ),
              onPressed: isSaving ? null : () => _saveNewKost(setModalState),
              child: Text(isSaving ? "Memproses..." : "Daftarkan Kos"),
            ),
          ],
        ),
      ),
    );
  }

  // Helper untuk membuat TextField agar kode rapi
  Widget _buildField(TextEditingController ctrl, String label, IconData icon, String hint, {bool isNumber = false, int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF9C5A1A)),
        filled: true,
        fillColor: const Color(0xFFF5F0EA),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  Future<void> _saveNewKost(StateSetter setModalState) async {
    if (_nameCtrl.text.isEmpty || _addressCtrl.text.isEmpty || _priceCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mohon lengkapi data utama")));
      return;
    }

    setModalState(() => isSaving = true);

    try {
      await supabase.from('kosts').insert({
        'owner_id': supabase.auth.currentUser?.id,
        'name': _nameCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'price': int.tryParse(_priceCtrl.text.trim()) ?? 0,
        'description': _descCtrl.text.trim(),
        'include_listrik': _includeListrik,
        'include_air': _includeAir,
        'is_approved': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Unit berhasil diajukan ke admin!"), backgroundColor: Colors.green),
        );
      }
      
      _nameCtrl.clear(); _addressCtrl.clear(); _priceCtrl.clear(); _descCtrl.clear();
      setState(() {
        _includeListrik = false;
        _includeAir = false;
      });

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal: $e")));
    } finally {
      if (mounted) setModalState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2E8DA),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleAvatar(radius: 50, backgroundColor: Color(0xFF9C5A1A), child: Icon(Icons.person, size: 50, color: Colors.white)),
            const SizedBox(height: 10),
            Text(supabase.auth.currentUser?.email ?? "Owner", style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF9C5A1A),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                ),
                onPressed: _showAddKostDialog,
                icon: const Icon(Icons.add_business),
                label: const Text("Tambah Unit Kos Baru", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            
            const SizedBox(height: 12),
            TextButton(
              onPressed: () async {
                await supabase.auth.signOut();
                if (mounted) Navigator.pushReplacementNamed(context, '/');
              },
              child: const Text("Logout", style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }
}