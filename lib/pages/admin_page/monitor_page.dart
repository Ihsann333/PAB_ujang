import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kostly_pa/pages/admin_page/detail_kos.dart';
import 'package:kostly_pa/pages/login_page.dart'; 
import 'package:kostly_pa/services/supabase_service.dart';

// --- STYLES ---
TextStyle _soraAdmin({double? fontSize, FontWeight? fontWeight, Color? color}) {
  return GoogleFonts.sora(fontSize: fontSize, fontWeight: fontWeight, color: color);
}

TextStyle _jakartaAdmin({double? fontSize, FontWeight? fontWeight, Color? color}) {
  return GoogleFonts.plusJakartaSans(fontSize: fontSize, fontWeight: fontWeight, color: color);
}

class MonitorPage extends StatefulWidget {
  const MonitorPage({super.key});

  @override
  State<MonitorPage> createState() => _MonitorPageState();
}

class _MonitorPageState extends State<MonitorPage> {
  final supabase = SupabaseService.client;
  int totalKos = 0;
  int totalOwner = 0;
  int sudahBayar = 0;
  int belumBayar = 0;
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
      final now = DateTime.now();

      // 1. Ambil Stats Dasar
      final kosRes = await supabase.from('kosts').select('*').eq('is_approved', true);
      final ownerRes = await supabase.from('profiles').select('*').eq('role', 'owner').eq('is_approved', true);
      final top3 = await supabase.from('kosts').select('*').eq('is_approved', true).order('created_at', ascending: false).limit(3);

      // 2. Ambil Stats Pembayaran (Bulan & Tahun Berjalan)
      final payRes = await supabase
          .from('payments')
          .select('status')
          .eq('month', now.month)
          .eq('year', now.year);

      final List payments = payRes as List;

      if (mounted) {
        setState(() {
          totalKos = (kosRes as List).length;
          totalOwner = (ownerRes as List).length;
          top3Terbaru = top3 as List;

          // Hitung Lunas vs Tunggakan
          sudahBayar = payments.where((p) => p['status'] == 'success').length;
          // Asumsi: Target pembayaran adalah sebanyak jumlah kost yang approve/aktif
          belumBayar = totalKos - sudahBayar;
          if (belumBayar < 0) belumBayar = 0;

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
              _buildHeader(context),
              const SizedBox(height: 25),

              // Statistik Utama
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard("Total Kost", totalKos.toString(), Icons.business_rounded, const Color(0xFF9C5A1A), () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ListDataPage(title: "Daftar Kost Aktif", table: "kosts", formatRupiah: formatRupiah)));
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
              const SizedBox(height: 15),

              // Statistik Pembayaran Bulan Ini
              _sectionTitle("Monitoring Pembayaran"),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard("Belum Bayar", belumBayar.toString(), Icons.money_off_rounded, const Color(0xFFE24D56), () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentStatusPage()));
                    }),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildStatCard("Sudah Bayar", sudahBayar.toString(), Icons.check_circle_rounded, const Color(0xFF2E7D32), () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentStatusPage()));
                    }),
                  ),
                ],
              ),

              const SizedBox(height: 35),
              _sectionTitle("Unit Terbaru"),
              const SizedBox(height: 15),
              ...top3Terbaru.map((kos) => _buildRecentCard(kos)).toList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title, style: _soraAdmin(fontSize: 18, fontWeight: FontWeight.w700));
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          const CircleAvatar(radius: 25, backgroundColor: Color(0xFF9C5A1A), child: Text("A", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700))),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Administrator", style: _jakartaAdmin(color: Colors.grey, fontSize: 13)),
                Text(adminEmail ?? "admin@gmail.com", style: _jakartaAdmin(fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.power_settings_new, color: Colors.redAccent),
            onPressed: () => _showLogoutDialog(context),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFFFBF7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text("Konfirmasi Logout", style: _soraAdmin(fontWeight: FontWeight.w700, fontSize: 18)),
        content: const Text("Apakah Anda yakin ingin keluar?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              await supabase.auth.signOut();
              if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (route) => false);
            },
            child: const Text("Ya, Keluar"),
          ),
        ],
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
            Text(v, style: _soraAdmin(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700)),
            Text(t, style: _jakartaAdmin(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
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
        title: Text(kos['name'] ?? "Nama Kost", style: _jakartaAdmin(fontWeight: FontWeight.w700)),
        subtitle: Text("Rp ${formatRupiah(kos['price'])}", style: _jakartaAdmin()),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

// --- HALAMAN DAFTAR DATA ---
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
      appBar: AppBar(title: Text(title, style: _soraAdmin(fontWeight: FontWeight.w700)), backgroundColor: const Color(0xFF9C5A1A), foregroundColor: Colors.white),
      body: FutureBuilder(
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: const Color(0xFFF2E8DA), child: Icon(table == 'kosts' ? Icons.home_work : Icons.person, color: const Color(0xFF9C5A1A))),
                  title: Text(item['name'] ?? item['email'] ?? 'User', style: _jakartaAdmin(fontWeight: FontWeight.w700)),
                  subtitle: Text(table == 'kosts' ? "Rp ${formatRupiah(item['price'])}" : (item['email'] ?? ""), style: _jakartaAdmin()),
                  onTap: () {
                    if (table == 'kosts') {
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

// --- HALAMAN DETAIL OWNER ---
class OwnerDetailPage extends StatelessWidget {
  final Map owner;
  final String Function(dynamic) formatRupiah;

  const OwnerDetailPage({super.key, required this.owner, required this.formatRupiah});

  @override
  Widget build(BuildContext context) {
    final supabase = SupabaseService.client;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F2),
      appBar: AppBar(title: Text("Profil Owner", style: _soraAdmin(fontWeight: FontWeight.w700)), backgroundColor: const Color(0xFF9C5A1A), foregroundColor: Colors.white),
      body: FutureBuilder(
        future: supabase.from('kosts').select('*').eq('owner_id', owner['id']),
        builder: (context, snapshot) {
          final kos = snapshot.data as List? ?? [];
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const CircleAvatar(radius: 50, backgroundColor: Color(0xFF9C5A1A), child: Icon(Icons.person, size: 60, color: Colors.white)),
                const SizedBox(height: 20),
                Text(owner['name'] ?? "Owner", style: _soraAdmin(fontSize: 24, fontWeight: FontWeight.w700)),
                const Divider(height: 50),
                Align(alignment: Alignment.centerLeft, child: Text("Kost yang dimiliki:", style: _soraAdmin(fontWeight: FontWeight.w700, fontSize: 18))),
                const SizedBox(height: 15),
                ...kos.map((k) => Card(child: ListTile(title: Text(k['name']), subtitle: Text("Rp ${formatRupiah(k['price'])}"), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailKosPage(kos: k)))))).toList()
              ],
            ),
          );
        },
      ),
    );
  }
}

// --- HALAMAN STATUS PEMBAYARAN (TAB VIEW) ---
class PaymentStatusPage extends StatelessWidget {
  const PaymentStatusPage({super.key});

  @override
  Widget build(BuildContext context) {
    final supabase = SupabaseService.client;
    final now = DateTime.now();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F5F2),
        appBar: AppBar(
          title: Text("Status Bayar ${now.month}/${now.year}", style: _soraAdmin(fontWeight: FontWeight.w700, fontSize: 18)),
          backgroundColor: const Color(0xFF9C5A1A),
          foregroundColor: Colors.white,
          bottom: const TabBar(indicatorColor: Colors.white, tabs: [Tab(text: "Tunggakan"), Tab(text: "Lunas")]),
        ),
        body: TabBarView(
          children: [
            _buildPaymentList(supabase, 'pending', now),
            _buildPaymentList(supabase, 'success', now),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentList(supabase, String status, DateTime now) {
    return FutureBuilder(
      future: supabase.from('payments').select('*, kosts(name), profiles(name)').eq('status', status).eq('month', now.month).eq('year', now.year),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data as List? ?? [];
        if (data.isEmpty) return const Center(child: Text("Tidak ada data"));

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: data.length,
          itemBuilder: (context, i) {
            final item = data[i];
            return Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                title: Text(item['profiles']['name'] ?? 'Tenant', style: _jakartaAdmin(fontWeight: FontWeight.bold)),
                subtitle: Text("Unit: ${item['kosts']['name']}"),
                trailing: Icon(status == 'success' ? Icons.check_circle : Icons.error, color: status == 'success' ? Colors.green : Colors.red),
              ),
            );
          },
        );
      },
    );
  }
}