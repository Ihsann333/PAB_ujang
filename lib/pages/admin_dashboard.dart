import 'package:flutter/material.dart';
import 'package:kostly_pa/core/supabase_service.dart';

// ─────────────────────────────────────────────
// ADMIN DASHBOARD MAIN
// ─────────────────────────────────────────────
class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int selectedIndex = 0;

  final List<Widget> pages = [
    const MonitorPage(),
    const ApprovalPage(),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2E8DA),
      body: pages[selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        selectedItemColor: const Color(0xFF9C5A1A),
        unselectedItemColor: Colors.grey,
        onTap: (i) => setState(() => selectedIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.analytics_outlined), label: "Monitor"),
          BottomNavigationBarItem(icon: Icon(Icons.how_to_reg_outlined), label: "Approval"),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: "Profile"),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// PAGE: DETAIL KOS (BARU)
// ─────────────────────────────────────────────
class DetailKosPage extends StatelessWidget {
  final Map kos;
  const DetailKosPage({super.key, required this.kos});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2E8DA),
      appBar: AppBar(
        title: Text(kos['name'] ?? 'Detail Kos'),
        backgroundColor: const Color(0xFF9C5A1A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 250,
              width: double.infinity,
              color: const Color(0xFFDCC8B0),
              child: const Icon(Icons.apartment, size: 100, color: Color(0xFF9C5A1A)),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kos['name'] ?? 'Nama Tidak Tersedia',
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF4A2C0A)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Rp ${kos['price'] ?? '0'} / Bulan",
                    style: const TextStyle(fontSize: 20, color: Color(0xFF9C5A1A), fontWeight: FontWeight.w600),
                  ),
                  const Divider(height: 40, thickness: 1),
                  const Text("Informasi Kost", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  _infoRow(Icons.location_on, kos['address'] ?? 'Alamat tidak tersedia'),
                  _infoRow(Icons.description, kos['description'] ?? 'Tidak ada deskripsi tambahan'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.brown),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// PAGE 1: MONITOR
// ─────────────────────────────────────────────
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

  void showTopNotification(String title, String message) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: 50,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF9C5A1A),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))],
            ),
            child: Row(
              children: [
                const Icon(Icons.notifications_active, color: Colors.white, size: 28),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      Text(message, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  onPressed: () => entry.remove(),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 4), () {
      if (entry.mounted) entry.remove();
    });
  }

  Future<void> fetchStats() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final kosRes = await supabase.from('kosts').select('id');
      final ownerRes = await supabase.from('profiles').select('id').eq('role', 'owner').eq('is_approved', false);
      final top3 = await supabase.from('kosts').select().order('created_at', ascending: false).limit(3);

      if (mounted) {
        setState(() {
          totalKos = (kosRes as List).length;
          totalOwner = (ownerRes as List).length;
          top3Terbaru = top3;
          isLoading = false;
        });

        if (totalOwner > 0) {
          Future.delayed(const Duration(milliseconds: 800), () {
            showTopNotification("Reminder Approval", "Ada $totalOwner owner baru menunggu persetujuan!");
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
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
                Expanded(child: _buildStatCard("Total Kos", totalKos.toString(), Icons.home_work, const Color(0xFF9C5A1A))),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard("Total Owner", totalOwner.toString(), Icons.supervisor_account, const Color(0xFF6B3A10))),
              ],
            ),
            const SizedBox(height: 32),
            const Text("Top 3 Kost Terbaru", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...top3Terbaru.map((kos) => _buildRecentKosCard(kos)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white70, size: 28),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold)),
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildRecentKosCard(Map kos) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        // 🔥 NAVIGASI KE DETAIL KOS
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => DetailKosPage(kos: kos)),
          );
        },
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
                    Text(kos['name'] ?? 'ujang', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text("Rp ${kos['price'] ?? '0'} / Bulan", style: const TextStyle(color: Colors.grey, fontSize: 13)),
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
}

// ─────────────────────────────────────────────
// PAGE 2: APPROVAL PAGE (TETAP SAMA)
// ─────────────────────────────────────────────
class ApprovalPage extends StatefulWidget {
  final VoidCallback? onBack;
  const ApprovalPage({super.key, this.onBack});

  @override
  State<ApprovalPage> createState() => _ApprovalPageState();
}

class _ApprovalPageState extends State<ApprovalPage> {
  final supabase = SupabaseService.client;
  List owners = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchOwners();
  }

  Future<void> fetchOwners() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      // Menarik owner yang belum di-approve
      // Serta memfilter list kosts agar hanya yang 'is_approved' = false yang ditarik
      final data = await supabase
          .from('profiles')
          .select('*, kosts(*)')
          .eq('role', 'owner')
          .eq('is_approved', false)
          .eq('kosts.is_approved', false); // Pastikan kost-nya juga status pending

      if (mounted) {
        setState(() {
          owners = data as List;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error Fetching: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> handleApprove(String userId) async {
    try {
      // Approve akun owner
      await supabase.from('profiles').update({'is_approved': true}).eq('id', userId);
      // Approve semua kost milik owner tersebut
      await supabase.from('kosts').update({'is_approved': true}).eq('owner_id', userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Owner & Kost Berhasil Disetujui!"), backgroundColor: Colors.green),
        );
        fetchOwners();
      }
    } catch (e) {
      debugPrint("Gagal Approve: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFF9C5A1A)));

    return Scaffold(
      backgroundColor: const Color(0xFFF2E8DA),
      appBar: AppBar(
        title: const Text("Approval Owner", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
      ),
      body: owners.isEmpty
          ? const Center(child: Text("Tidak ada antrean approval"))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: owners.length,
              itemBuilder: (context, i) {
                final item = owners[i];
                final List listKos = item['kosts'] ?? [];

                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  margin: const EdgeInsets.only(bottom: 15),
                  child: ExpansionTile(
                    initiallyExpanded: true,
                    title: Text(item['email'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold)),
                    // Menghilangkan tulisan "0 Kost menunggu" jika kosong
                    subtitle: listKos.isNotEmpty 
                      ? Text("${listKos.length} Kost menunggu persetujuan") 
                      : const Text("Menunggu verifikasi akun", style: TextStyle(color: Colors.orange)),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (listKos.isNotEmpty) ...[
                              const Text("Detail Kost:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const Divider(),
                              ...listKos.map((k) => Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Row(
                                  children: [
                                    const Icon(Icons.home_work, size: 18, color: Color(0xFF9C5A1A)),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(k['name'] ?? 'Nama Kost', style: const TextStyle(fontWeight: FontWeight.w600)),
                                          Text("Rp ${k['price']} / Bulan", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                            ] else 
                              const Text("Data kost belum lengkap.", style: TextStyle(color: Colors.red, fontSize: 12)),
                            
                            const SizedBox(height: 15),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF9C5A1A),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                icon: const Icon(Icons.check_circle, size: 18),
                                label: const Text("APPROVE OWNER & KOS"),
                                onPressed: () => handleApprove(item['id']),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

// ─────────────────────────────────────────────
// PAGE 3: PROFILE PAGE (TETAP SAMA)
// ─────────────────────────────────────────────
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircleAvatar(radius: 50, backgroundColor: Color(0xFF9C5A1A), child: Icon(Icons.person, size: 50, color: Colors.white)),
          const SizedBox(height: 16),
          const Text("Admin Kostly", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 30),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9C5A1A), foregroundColor: Colors.white),
            onPressed: () => Navigator.pushReplacementNamed(context, '/'),
            child: const Text("Logout"),
          ),
        ],
      ),
    );
  }
}