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

  String formatRupiah(dynamic price) {
    if (price == null) return "0";
    String priceStr = price.toString();
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return priceStr.replaceAllMapped(reg, (Match m) => '${m[1]}.');
  }

  Future<void> fetchStats() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      // PERBAIKAN: Gunakan select('*') atau select() tanpa filter kolom agar semua data (termasuk fasilitas/deskripsi) terbawa
      final kosRes = await supabase.from('kosts').select('*').eq('is_approved', true);
      final ownerRes = await supabase.from('profiles').select('*').eq('role', 'owner').eq('is_approved', true);
      
      // Ambil top 3 dengan data lengkap
      final top3 = await supabase.from('kosts').select('*').eq('is_approved', true).order('created_at', ascending: false).limit(3);

      if (mounted) {
        setState(() {
          totalKos = (kosRes as List).length;
          totalOwner = (ownerRes as List).length;
          top3Terbaru = top3 as List;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F2),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: fetchStats,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Header Profil
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                  ],
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 25,
                      backgroundColor: Color(0xFF9C5A1A),
                      child: Text("A", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Administrator", style: TextStyle(color: Colors.grey, fontSize: 13)),
                          Text(
                            adminEmail ?? "admin@gmail.com", 
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.power_settings_new, color: Colors.redAccent),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              title: const Text("Konfirmasi Logout"),
                              content: const Text("Apakah Anda yakin ingin keluar dari akun ini?"),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context), // Tutup dialog saja
                                  child: const Text("Batal", style: TextStyle(color: Colors.grey)),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.redAccent,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () async {
                                    await supabase.auth.signOut();
                                    if (mounted) {
                                      // Tutup dialog lalu pindah ke LoginPage
                                      Navigator.pop(context);
                                      Navigator.pushReplacement(
                                        context, 
                                        MaterialPageRoute(builder: (_) => const LoginPage())
                                      );
                                    }
                                  },
                                  child: const Text("Ya, Keluar", style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Stat Cards
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard("Total Kos", totalKos.toString(), Icons.business_rounded, const Color(0xFF9C5A1A), () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ListDataPage(title: "Daftar Kos Aktif", table: "kosts", formatRupiah: formatRupiah)));
                    }),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildStatCard("Total Owner", totalOwner.toString(), Icons.people_alt_rounded, const Color(0xFF6B3A10), () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ListDataPage(title: "Daftar Owner Aktif", table: "profiles", formatRupiah: formatRupiah)));
                    }),
                  ),
                ],
              ),

              const SizedBox(height: 35),
              const Text("Unit Terbaru", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              ...top3Terbaru.map((kos) => _buildRecentCard(kos)).toList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String t, String v, IconData i, Color c, VoidCallback tap) {
    return GestureDetector(
      onTap: tap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: c, 
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: c.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))]
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(i, color: Colors.white, size: 28),
            const SizedBox(height: 15),
            Text(v, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
            Text(t, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentCard(Map kos) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailKosPage(kos: kos))),
        leading: const Icon(Icons.home_work, color: Color(0xFF9C5A1A)),
        title: Text(kos['name'] ?? "Nama Kos", style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("Rp ${formatRupiah(kos['price'])}"),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

// Contoh cara memanggil data di dalam DetailKosPage
Widget buildInformasiKost(dynamic widget) {
  // Ambil data dari Map 'kos' yang dikirim
  final bool hasWifi = widget.kos['include_wifi'] ?? false;
  final bool hasAir = widget.kos['include_water'] ?? false;
  final bool hasListrik = widget.kos['include_electricity'] ?? false;

  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        _buildInfoRow(
          Icons.wifi, 
          "WiFi", 
          hasWifi ? "Tersedia" : "Tidak Tersedia"
        ),
        const Divider(),
        _buildInfoRow(
          Icons.water_drop, 
          "Air", 
          hasAir ? "Sudah Include" : "Tidak Include"
        ),
        const Divider(),
        _buildInfoRow(
          Icons.bolt, 
          "Listrik", 
          hasListrik ? "Sudah Include" : "Tidak Include"
        ),
      ],
    ),
  );
}

Widget _buildInfoRow(IconData icon, String label, String value) {
  return Row(
    children: [
      Icon(icon, color: const Color(0xFF9C5A1A), size: 20),
      const SizedBox(width: 12),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    ],
  );
}

// --- PAGE DAFTAR BARU ---
class ListDataPage extends StatelessWidget {
  final String title;
  final String table;
  final String Function(dynamic) formatRupiah;

  const ListDataPage({super.key, required this.title, required this.table, required this.formatRupiah});

  @override
  Widget build(BuildContext context) {
    final supabase = SupabaseService.client;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F2),
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF9C5A1A),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder(
        // PERBAIKAN: Gunakan select('*') agar data deskripsi, fasilitas, dll ikut terambil
        future: table == 'kosts' 
            ? supabase.from('kosts').select('*').eq('is_approved', true) 
            : supabase.from('profiles').select('*').eq('role', 'owner').eq('is_approved', true),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final data = snapshot.data as List? ?? [];
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: data.length,
            itemBuilder: (context, i) {
              final item = data[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFF2E8DA),
                    child: Icon(table == 'kosts' ? Icons.home_work : Icons.person, color: const Color(0xFF9C5A1A)),
                  ),
                  title: Text(item['name'] ?? item['email'] ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(table == 'kosts' ? "Rp ${formatRupiah(item['price'])}" : (item['email'] ?? "")),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    if (table == 'kosts') {
                      // Sekarang 'item' sudah membawa data lengkap
                      Navigator.push(context, MaterialPageRoute(builder: (_) => DetailKosPage(kos: item)));
                    } else {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => OwnerDetailPage(owner: item, formatRupiah: formatRupiah)));
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// --- PAGE DETAIL OWNER ---
class OwnerDetailPage extends StatelessWidget {
  final Map owner;
  final String Function(dynamic) formatRupiah;

  const OwnerDetailPage({super.key, required this.owner, required this.formatRupiah});

  @override
  Widget build(BuildContext context) {
    final supabase = SupabaseService.client;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F2),
      appBar: AppBar(title: const Text("Profil Owner"), backgroundColor: const Color(0xFF9C5A1A), foregroundColor: Colors.white),
      body: FutureBuilder(
        // PERBAIKAN: Gunakan select('*') agar saat klik kos milik owner, datanya lengkap
        future: supabase.from('kosts').select('*').eq('owner_id', owner['id']),
        builder: (context, snapshot) {
          final kos = snapshot.data as List? ?? [];
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const CircleAvatar(radius: 50, backgroundColor: Color(0xFF9C5A1A), child: Icon(Icons.person, size: 60, color: Colors.white)),
                const SizedBox(height: 20),
                Text(owner['name'] ?? "Owner", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                Text(owner['email'] ?? "-", style: const TextStyle(color: Colors.grey)),
                const Divider(height: 50),
                const Align(alignment: Alignment.centerLeft, child: Text("Kost yang dimiliki:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
                const SizedBox(height: 15),
                if (snapshot.connectionState == ConnectionState.waiting) 
                  const Center(child: CircularProgressIndicator())
                else if (kos.isEmpty)
                  const Text("Belum ada kos.")
                else ...kos.map((k) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text(k['name']),
                    subtitle: Text("Rp ${formatRupiah(k['price'])}"),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailKosPage(kos: k))),
                  ),
                )).toList()
              ],
            ),
          );
        },
      ),
    );
  }
}