import 'package:flutter/material.dart';
import 'package:kostly_pa/pages/admin_page/detail_kos.dart';
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

  @override
  void initState() {
    super.initState();
    fetchStats();
  }

Future<void> fetchStats() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      // Menggunakan .select() tanpa id agar mendapatkan List Map yang bersih
      final kosRes = await supabase.from('kosts').select().eq('is_approved', true);
      final ownerRes = await supabase.from('profiles').select().eq('role', 'owner').eq('is_approved', true);
      final pendingRes = await supabase.from('profiles').select().eq('role', 'owner').eq('is_approved', false);
      final top3 = await supabase.from('kosts').select().eq('is_approved', true).order('created_at', ascending: false).limit(3);

      if (mounted) {
        setState(() {
          // Gunakan as List? ?? [] untuk keamanan agar tidak crash jika data null
          totalKos = (kosRes as List).length;
          totalOwner = (ownerRes as List).length;
          top3Terbaru = top3 as List;
          isLoading = false;
        });

        if ((pendingRes as List).isNotEmpty) {
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted) _showTopNotification("Reminder Approval", "Ada ${pendingRes.length} owner baru menunggu!");
          });
        }
      }
    } catch (e) {
      debugPrint("Error Monitor: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

void _showListDialog(String title, String table) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Color(0xFFF2E8DA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 15),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(10))),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: FutureBuilder(
              // PAKAI QUERY STANDAR DULU BIAR PASTI MUNCUL
              future: table == 'kosts' 
                ? supabase.from('kosts').select().eq('is_approved', true)
                : supabase.from('profiles').select().eq('role', 'owner').eq('is_approved', true),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                
                final List data = snapshot.data as List? ?? [];
                if (data.isEmpty) return const Center(child: Text("Data tidak ditemukan di database."));

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  itemCount: data.length,
                  itemBuilder: (context, i) {
                    final item = data[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF9C5A1A),
                          child: Icon(table == 'kosts' ? Icons.home : Icons.person, color: Colors.white, size: 20),
                        ),
                        title: Text(item['name'] ?? item['email'] ?? 'User Aktif', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(table == 'kosts' 
                          ? "Harga: Rp ${item['price']}" 
                          : "Klik untuk lihat profil detail"),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                        onTap: () {
                          if (table == 'kosts') {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => DetailKosPage(kos: item)));
                          } else {
                            // OPER DATA KE DETAIL OWNER
                            _showOwnerDetail(item);
                          }
                        },
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
    // Kita ambil data kos milik owner ini secara manual
    final kosOwner = await supabase
        .from('kosts')
        .select()
        .eq('owner_id', owner['id']); // Pastikan nama kolom 'owner_id' benar

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Profil Owner", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(child: Icon(Icons.account_circle, size: 80, color: Color(0xFF9C5A1A))),
            const SizedBox(height: 15),
            _buildDetailRow("Nama", owner['name'] ?? '-'),
            _buildDetailRow("Email", owner['email'] ?? '-'),
            const Divider(),
            const Text("Kos yang Dikelola:", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              width: double.maxFinite,
              child: kosOwner.isEmpty
                  ? const Text("Belum ada kos terdaftar", style: TextStyle(color: Colors.grey, fontSize: 13))
                  : ListView.builder(
                      itemCount: kosOwner.length,
                      itemBuilder: (context, index) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.check_circle, color: Colors.green, size: 18),
                        title: Text(kosOwner[index]['name'], style: const TextStyle(fontSize: 13)),
                      ),
                    ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Tutup")),
        ],
      ),
    );
  }

  // Widget pembantu (taruh di bawah _showOwnerDetail)
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text("$label: $value", style: const TextStyle(fontSize: 14)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFF9C5A1A)));

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: fetchStats,
        color: const Color(0xFF9C5A1A),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text("Monitor Sistem", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF4A2C0A))),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard("Total Kos", totalKos.toString(), Icons.home_work, const Color(0xFF9C5A1A), () {
                    _showListDialog("Daftar Kos Aktif", "kosts");
                  }),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard("Total Owner", totalOwner.toString(), Icons.supervisor_account, const Color(0xFF6B3A10), () {
                    _showListDialog("Daftar Owner Aktif", "profiles");
                  }),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Text("Top 3 Kost Terbaru", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            top3Terbaru.isEmpty 
              ? const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("Belum ada kos disetujui", style: TextStyle(color: Colors.grey))))
              : Column(children: top3Terbaru.map((kos) => _buildRecentKosCard(kos)).toList()),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, VoidCallback onTap) {
    return Material( // Efek tekan
      color: color,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.white70, size: 28),
              const SizedBox(height: 12),
              Text(value, style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold)),
              Text(title, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentKosCard(Map kos) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailKosPage(kos: kos))),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFF2E8DA), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.apartment, color: Color(0xFF9C5A1A)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(kos['name'] ?? 'Nama Kos', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text("Rp ${kos['price']} / Bulan", style: const TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  void _showTopNotification(String title, String message) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: 50, left: 20, right: 20,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFF9C5A1A), borderRadius: BorderRadius.circular(15)),
            child: Row(
              children: [
                const Icon(Icons.notifications_active, color: Colors.white),
                const SizedBox(width: 15),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text(message, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ])),
                IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => entry.remove()),
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