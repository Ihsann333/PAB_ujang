import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kostly_pa/pages/login_page.dart';
import 'package:kostly_pa/services/supabase_service.dart';

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
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2E8DA),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: const Color(0xFF9C5A1A),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Reminder'),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 1. HOME PAGE (HEADER PROFIL, DETAIL KOS & REQUEST KELUAR)
// ─────────────────────────────────────────────
class UserHomePage extends StatefulWidget {
  const UserHomePage({super.key});

  @override
  State<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {
  final supabase = SupabaseService.client;
  final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  
  Map? profileData;
  Map? kost;
  List reminders = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // 1. Ambil Profil User
      final profile = await supabase.from('profiles').select().eq('id', user.id).single();

      // 2. Ambil Data Kost jika terdaftar
      if (profile['kost_id'] != null) {
        final kosData = await supabase.from('kosts').select().eq('id', profile['kost_id']).single();
        
        // 3. Ambil Reminder terbaru
        final reminderData = await supabase.from('reminders')
            .select()
            .eq('owner_id', kosData['owner_id'])
            .order('created_at', ascending: false)
            .limit(3);

        if (mounted) {
          setState(() {
            profileData = profile;
            kost = kosData;
            reminders = reminderData;
            isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            profileData = profile;
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // FUNGSI REQUEST KELUAR KOS
  Future<void> _requestExit() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Pastikan kolom 'exit_request' sudah ada di tabel profiles Supabase kamu
      await supabase.from('profiles').update({
        'exit_request': true, 
      }).eq('id', user.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Berhasil! Menunggu persetujuan owner.")),
        );
        fetchData(); // Refresh UI
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal mengirim permintaan: $e")),
        );
      }
    }
  }

  // POP-UP PROFIL
  void _showProfilePopup() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 35,
              backgroundColor: Color(0xFF9C5A1A),
              child: Icon(Icons.person, size: 35, color: Colors.white),
            ),
            const SizedBox(height: 15),
            const Text("Detail Akun", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(),
            _buildPopupItem("Email", supabase.auth.currentUser?.email ?? "-"),
            _buildPopupItem("Status", profileData?['kost_id'] == null ? "Belum ada Kos" : "Aktif Ngekos"),
            const SizedBox(height: 15),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Tutup", style: TextStyle(color: Color(0xFF9C5A1A))),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFF9C5A1A)));

    final String userDisplay = supabase.auth.currentUser?.email?.split('@')[0] ?? "User";
    final bool isPendingExit = profileData?['exit_request'] ?? false;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: fetchData,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: _showProfilePopup,
                  child: Row(
                    children: [
                      const CircleAvatar(backgroundColor: Color(0xFF9C5A1A), child: Icon(Icons.person, color: Colors.white, size: 20)),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(userDisplay, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const Text("Lihat Profil", style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    await supabase.auth.signOut();
                    if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginPage()), (route) => false);
                  },
                  icon: const Icon(Icons.logout, color: Colors.redAccent),
                )
              ],
            ),
            
            const SizedBox(height: 25),
            const Text("Informasi Unit Kos", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            
            // CARD INFORMASI KOS
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white, 
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(kost?['name'] ?? 'Belum Terdaftar di Unit', 
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF9C5A1A))),
                  const SizedBox(height: 4),
                  Text(kost?['address'] ?? 'Silakan hubungi admin untuk daftar', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  const Divider(height: 30),
                  
                  _buildDetailRow(Icons.payments, "Biaya Sewa", currency.format(kost?['price'] ?? 0)),
                  _buildDetailRow(Icons.flash_on, "Listrik", kost?['include_listrik'] == true ? "Gratis" : "Bayar Sendiri"),
                  _buildDetailRow(Icons.water_drop, "Air", kost?['include_air'] == true ? "Gratis" : "Bayar Sendiri"),
                  
                  const SizedBox(height: 15),

                  // TOMBOL REQUEST KELUAR
                  if (kost != null)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isPendingExit ? Colors.grey : Colors.redAccent,
                          side: BorderSide(color: isPendingExit ? Colors.grey : Colors.redAccent),
                        ),
                        onPressed: isPendingExit ? null : () => _showExitConfirmation(),
                        child: Text(isPendingExit ? "Menunggu Persetujuan Keluar" : "Ajukan Keluar dari Kos"),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 30),
            const Text("Pengumuman Terbaru", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            if (reminders.isEmpty)
              const Center(child: Text("Belum ada pengumuman", style: TextStyle(color: Colors.grey, fontSize: 13)))
            else
              ...reminders.map((r) => _buildNotifCard(r)),
          ],
        ),
      ),
    );
  }

  // DIALOG KONFIRMASI KELUAR
  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Konfirmasi Keluar"),
        content: const Text("Apakah kamu yakin ingin mengajukan keluar? Permintaan ini harus disetujui oleh Owner."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(context);
              _requestExit();
            }, 
            child: const Text("Ya, Ajukan", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // WIDGET HELPER
  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF9C5A1A)),
          const SizedBox(width: 10),
          Text("$label: ", style: const TextStyle(fontSize: 13, color: Colors.black54)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildPopupItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildNotifCard(Map r) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE8DCCB))),
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const Icon(Icons.notifications_active, color: Color(0xFF9C5A1A), size: 20),
        title: Text(r['title'] ?? 'Info', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        subtitle: Text(r['message'] ?? '-', style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 2. REMINDER PAGE (HALAMAN LIST NOTIF LENGKAP)
// ─────────────────────────────────────────────
class ReminderPageUser extends StatefulWidget {
  const ReminderPageUser({super.key});

  @override
  State<ReminderPageUser> createState() => _ReminderPageUserState();
}

class _ReminderPageUserState extends State<ReminderPageUser> {
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
      final data = await supabase.from('reminders').select().order('created_at', ascending: false);
      if (mounted) setState(() { reminders = data; isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2E8DA),
      appBar: AppBar(title: const Text("Notifikasi"), backgroundColor: Colors.transparent, elevation: 0, centerTitle: true),
      body: isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: reminders.length,
            itemBuilder: (context, index) {
              final r = reminders[index];
              return Card(
                child: ListTile(
                  title: Text(r['title'] ?? 'Info'),
                  subtitle: Text(r['message'] ?? '-'),
                ),
              );
            },
          ),
    );
  }
}