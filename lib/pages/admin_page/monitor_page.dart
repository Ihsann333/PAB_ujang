import 'package:flutter/material.dart';
import 'package:kostly_pa/pages/admin_page/detail_kos.dart';
import 'package:kostly_pa/pages/login_page.dart'; 
import 'package:kostly_pa/services/supabase_service.dart';

class MonitorPage extends StatefulWidget {
  const MonitorPage({super.key});

  @override
  State<MonitorPage> createState() => _MonitorPageState();
}

class _MonitorPageState extends State<MonitorPage> {
  final supabase = SupabaseService.client;
  int totalKos = 0;
  int totalOwner = 0;
  List top3Terbaru = [];
  bool isLoading = true;
  String? adminEmail;

  @override
  void initState() {
    super.initState();
    adminEmail = supabase.auth.currentUser?.email;
    fetchStats();
  }

  // --- FUNGSI FORMAT RUPIAH (Menambahkan titik) ---
  String formatRupiah(dynamic price) {
    if (price == null) return "0";
    String priceStr = price.toString();
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return priceStr.replaceAllMapped(reg, (Match m) => '${m[1]}.');
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Konfirmasi Logout"),
        content: const Text("Apakah Anda yakin ingin keluar dari akun administrator?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Keluar", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await supabase.auth.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    }
  }

  Future<void> fetchStats() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final kosRes = await supabase.from('kosts').select().eq('is_approved', true);
      final ownerRes = await supabase.from('profiles').select().eq('role', 'owner').eq('is_approved', true);
      final pendingRes = await supabase.from('profiles').select().eq('role', 'owner').eq('is_approved', false);
      final top3 = await supabase.from('kosts').select().eq('is_approved', true).order('created_at', ascending: false).limit(3);

      if (mounted) {
        setState(() {
          totalKos = (kosRes as List).length;
          totalOwner = (ownerRes as List).length;
          top3Terbaru = top3 as List;
          isLoading = false;
        });

        if ((pendingRes as List).isNotEmpty) {
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted) _showTopNotification("Peringatan Admin", "Ada ${pendingRes.length} owner baru perlu divalidasi!");
          });
        }
      }
    } catch (e) {
      debugPrint("Error Monitor: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFF9C5A1A)));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F2),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: fetchStats,
          color: const Color(0xFF9C5A1A),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            children: [
              // --- HEADER PROFIL ---
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: const Color(0xFF9C5A1A),
                      child: Text(adminEmail != null ? adminEmail![0].toUpperCase() : "A",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Administrator", style: TextStyle(color: Colors.grey, fontSize: 12)),
                          Text(adminEmail ?? "User Admin",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                    ),
                    // TOMBOL LOGOUT
                    IconButton(
                      onPressed: _handleLogout,
                      icon: const Icon(Icons.power_settings_new_rounded, color: Colors.redAccent),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),
              const Text("Monitor Sistem", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              
              // --- STAT CARDS ---
              Row(
                children: [
                  Expanded(child: _buildStatCard("Total Kos", totalKos.toString(), Icons.business_rounded, const Color(0xFF9C5A1A), () => _showListDialog("Daftar Kos Aktif", "kosts"))),
                  const SizedBox(width: 15),
                  Expanded(child: _buildStatCard("Total Owner", totalOwner.toString(), Icons.people_alt_rounded, const Color(0xFF6B3A10), () => _showListDialog("Daftar Owner Aktif", "profiles"))),
                ],
              ),
              
              const SizedBox(height: 30),
              const Text("Top 3 Kost Terbaru", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              
              top3Terbaru.isEmpty 
                ? const Center(child: Padding(padding: EdgeInsets.all(30), child: Text("Belum ada data kos")))
                : Column(children: top3Terbaru.map((kos) => _buildRecentKosCard(kos)).toList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: Colors.white, size: 24),
                const SizedBox(height: 15),
                Text(value, style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold)),
                Text(title, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentKosCard(Map kos) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5)],
      ),
      child: ListTile(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailKosPage(kos: kos))),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFFF2E8DA), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.home_work_outlined, color: Color(0xFF9C5A1A)),
        ),
        title: Text(kos['name'] ?? 'Nama Kos', style: const TextStyle(fontWeight: FontWeight.bold)),
        // DISINI FORMAT HARGA DIGUNAKAN
        subtitle: Text("Rp ${formatRupiah(kos['price'])} / Bln", style: const TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.bold)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
      ),
    );
  }

  // --- SISANYA FUNGSI BANTUAN (TETAP DISERTAKAN) ---
  void _showListDialog(String title, String table) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(color: Color(0xFFF8F5F2), borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        child: Column(
          children: [
            const SizedBox(height: 15),
            Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            Padding(padding: const EdgeInsets.all(25), child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
            Expanded(
              child: FutureBuilder(
                future: table == 'kosts' ? supabase.from('kosts').select().eq('is_approved', true) : supabase.from('profiles').select().eq('role', 'owner').eq('is_approved', true),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  final List data = snapshot.data as List? ?? [];
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: data.length,
                    itemBuilder: (context, i) {
                      final item = data[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          title: Text(item['name'] ?? item['email'] ?? 'User'),
                          // TAMBAHKAN FORMAT HARGA JUGA DISINI JIKA ITU TABEL KOST
                          subtitle: table == 'kosts' ? Text("Rp ${formatRupiah(item['price'])}") : null,
                          onTap: () => table == 'kosts' ? Navigator.push(context, MaterialPageRoute(builder: (_) => DetailKosPage(kos: item))) : _showOwnerDetail(item),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOwnerDetail(Map owner) async {
    final kosOwner = await supabase.from('kosts').select().eq('owner_id', owner['id']);
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Detail Owner"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Email: ${owner['email']}"),
            const Divider(),
            const Text("Daftar Kos:", style: TextStyle(fontWeight: FontWeight.bold)),
            ...kosOwner.map((k) => Text("- ${k['name']} (Rp ${formatRupiah(k['price'])})")).toList(),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Tutup"))],
      ),
    );
  }

  void _showTopNotification(String title, String message) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: 60, left: 20, right: 20,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFF4A2C0A), borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(message, style: const TextStyle(color: Colors.white, fontSize: 13))),
                IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 18), onPressed: () => entry.remove()),
              ],
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 4), () { if (entry.mounted) entry.remove(); });
  }
}