import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kostly_pa/core/supabase_service.dart';
import 'package:kostly_pa/pages/login_page.dart';

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
// 1. HOME PAGE (DENGAN HEADER PROFIL & DETAIL LENGKAP)
// ─────────────────────────────────────────────
class UserHomePage extends StatefulWidget {
  const UserHomePage({super.key});

  @override
  State<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {
  final supabase = SupabaseService.client;
  final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  Map? kost;
  List reminders = [];
  bool isPaid = false;
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
      final profile = await supabase.from('profiles').select().eq('id', user.id).single();

      if (profile['kost_id'] != null) {
        final kosData = await supabase.from('kosts').select().eq('id', profile['kost_id']).single();
        final reminderData = await supabase.from('reminders').select()
            .eq('owner_id', kosData['owner_id'])
            .order('created_at', ascending: false).limit(3);

        setState(() {
          kost = kosData;
          reminders = reminderData;
          isPaid = profile['is_paid'] ?? false;
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userEmail = supabase.auth.currentUser?.email ?? "User";

    if (isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFF9C5A1A)));

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: fetchData,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // HEADER: PROFIL RINGKAS & LOGOUT
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0xFF9C5A1A),
                      child: Icon(Icons.person, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(userEmail.split('@')[0], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const Text("Penghuni Kos", style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ],
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
            const Text("Informasi Unit Kos", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF4A2C0A))),
            const SizedBox(height: 12),
            
            // CARD INFORMASI LENGKAP
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(kost?['name'] ?? 'Belum Terdaftar di Unit', 
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF9C5A1A))),
                      ),
                      _buildStatusBadge(isPaid),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(child: Text(kost?['address'] ?? 'Alamat belum tersedia', style: const TextStyle(color: Colors.grey, fontSize: 13))),
                    ],
                  ),
                  const Divider(height: 30),
                  
                  // Detail Harga & Fasilitas Listrik/Air
                  _buildDetailRow(Icons.payments, "Biaya Sewa", currency.format(kost?['price'] ?? 0)),
                  _buildDetailRow(Icons.flash_on, "Listrik", kost?['include_listrik'] == true ? "Termasuk (Gratis)" : "Token Sendiri"),
                  _buildDetailRow(Icons.water_drop, "Air", kost?['include_air'] == true ? "Termasuk (Gratis)" : "Bayar Sendiri"),
                  _buildDetailRow(Icons.info_outline, "Fasilitas", kost?['description'] ?? "-"),
                ],
              ),
            ),

            const SizedBox(height: 30),
            const Text("Notifikasi Terbaru", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF4A2C0A))),
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

  Widget _buildStatusBadge(bool paid) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: paid ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(paid ? "LUNAS" : "TAGIHAN AKTIF", 
        style: TextStyle(color: paid ? Colors.green[700] : Colors.red[700], fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF9C5A1A)),
          const SizedBox(width: 10),
          Text("$label: ", style: const TextStyle(fontSize: 13, color: Colors.black54)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _buildNotifCard(Map r) {
    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE8DCCB))),
      child: ListTile(
        leading: const CircleAvatar(backgroundColor: Color(0xFFF2E8DA), child: Icon(Icons.notifications_active, color: Color(0xFF9C5A1A), size: 18)),
        title: Text(r['title'] ?? 'Pengumuman', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        subtitle: Text(r['message'] ?? '-', style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}

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
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Ambil data reminder dari Supabase
      final data = await supabase
          .from('reminders')
          .select()
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          reminders = data;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2E8DA),
      appBar: AppBar(
        title: const Text("Notifikasi & Reminder", style: TextStyle(color: Color(0xFF4A2C0A), fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF9C5A1A)))
        : reminders.isEmpty
          ? const Center(child: Text("Tidak ada notifikasi"))
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: reminders.length,
              itemBuilder: (context, index) {
                final r = reminders[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFF2E8DA),
                      child: Icon(Icons.notifications_active, color: Color(0xFF9C5A1A)),
                    ),
                    title: Text(r['title'] ?? 'Info', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(r['message'] ?? '-'),
                  ),
                );
              },
            ),
    );
  }
}