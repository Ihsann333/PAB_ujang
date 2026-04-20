import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kostly_pa/pages/admin_page/detail_kos.dart';
import 'package:kostly_pa/pages/login_page.dart';
import 'package:kostly_pa/services/supabase_service.dart';

<<<<<<< HEAD
TextStyle _soraAdmin({
  double? fontSize,
  FontWeight? fontWeight,
  Color? color,
}) {
=======
// --- STYLES ---
TextStyle _soraAdmin({double? fontSize, FontWeight? fontWeight, Color? color}) {
>>>>>>> 68bdf6d7946220431b5be431e88d850f148ff12a
  return GoogleFonts.sora(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
  );
}

TextStyle _jakartaAdmin({
  double? fontSize,
  FontWeight? fontWeight,
  Color? color,
}) {
  return GoogleFonts.plusJakartaSans(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
  );
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
<<<<<<< HEAD
      // PERBAIKAN: Gunakan select('*') atau select() tanpa filter kolom agar semua data (termasuk fasilitas/deskripsi) terbawa
      final kosRes = await supabase.from('kosts').select('*').eq('is_approved', true);
      final ownerRes = await supabase.from('profiles').select('*').eq('role', 'owner').eq('is_approved', true);
      
      // Ambil top 3 dengan data lengkap
      final top3 = await supabase.from('kosts').select('*').eq('is_approved', true).order('created_at', ascending: false).limit(3);
=======
      final now = DateTime.now();

      // 1. Ambil Stats Dasar
      final kosRes = await supabase
          .from('kosts')
          .select('*')
          .eq('is_approved', true);
      final ownerRes = await supabase
          .from('profiles')
          .select('*')
          .eq('role', 'owner')
          .eq('is_approved', true);
      final top3 = await supabase
          .from('kosts')
          .select('*')
          .eq('is_approved', true)
          .order('created_at', ascending: false)
          .limit(3);
>>>>>>> 68bdf6d7946220431b5be431e88d850f148ff12a

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
    if (isLoading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

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
                      child: Text("A", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Administrator", style: _jakartaAdmin(color: Colors.grey, fontSize: 13)),
                          Text(
                            adminEmail ?? "admin@gmail.com", 
                            style: _jakartaAdmin(fontSize: 16, fontWeight: FontWeight.w700)
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
                              backgroundColor: const Color(0xFFFFFBF7),
                              surfaceTintColor: Colors.transparent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                              titlePadding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
                              contentPadding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
                              actionsPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                              title: Text(
                                "Konfirmasi Logout",
                                style: _soraAdmin(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                  color: const Color(0xFF2D241A),
                                ),
                              ),
                              content: Text(
                                "Apakah Anda yakin ingin keluar dari akun ini?",
                                style: _jakartaAdmin(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF5D5145),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context), // Tutup dialog saja
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF9A8D80),
                                    textStyle: _jakartaAdmin(fontWeight: FontWeight.w600, fontSize: 15),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  ),
                                  child: const Text("Batal"),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFE24D56),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    minimumSize: const Size(114, 42),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    textStyle: _jakartaAdmin(fontWeight: FontWeight.w700, fontSize: 15),
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
                                  child: const Text("Ya, Keluar"),
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
                    child: _buildStatCard(
                      "Total Kost",
                      totalKos.toString(),
                      Icons.business_rounded,
                      const Color(0xFF9C5A1A),
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ListDataPage(
                              title: "Daftar Kost Aktif",
                              table: "kosts",
                              formatRupiah: formatRupiah,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildStatCard(
                      "Total Owner",
                      totalOwner.toString(),
                      Icons.people_alt_rounded,
                      const Color(0xFF6B3A10),
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ListDataPage(
                              title: "Daftar Owner Aktif",
                              table: "profiles",
                              formatRupiah: formatRupiah,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
<<<<<<< HEAD
=======
              const SizedBox(height: 15),

              // Statistik Pembayaran Bulan Ini
              _sectionTitle("Monitoring Pembayaran"),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      "Belum Bayar",
                      belumBayar.toString(),
                      Icons.money_off_rounded,
                      const Color(0xFFE24D56),
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PaymentStatusPage(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildStatCard(
                      "Sudah Bayar",
                      sudahBayar.toString(),
                      Icons.check_circle_rounded,
                      const Color(0xFF2E7D32),
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PaymentStatusPage(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
>>>>>>> 68bdf6d7946220431b5be431e88d850f148ff12a

              const SizedBox(height: 35),
              Text("Unit Terbaru", style: _soraAdmin(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 15),
              ...top3Terbaru.map((kos) => _buildRecentCard(kos)).toList(),
            ],
          ),
        ),
      ),
    );
  }

<<<<<<< HEAD
  Widget _buildStatCard(String t, String v, IconData i, Color c, VoidCallback tap) {
=======
  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: _soraAdmin(fontSize: 18, fontWeight: FontWeight.w700),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 25,
            backgroundColor: Color(0xFF9C5A1A),
            child: Text(
              "A",
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Administrator",
                  style: _jakartaAdmin(color: Colors.grey, fontSize: 13),
                ),
                Text(
                  adminEmail ?? "admin@gmail.com",
                  style: _jakartaAdmin(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
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
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFFFFFBF7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 🔥 ICON (biar lebih hidup)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.logout,
                  color: Colors.redAccent,
                  size: 26,
                ),
              ),

              const SizedBox(height: 16),

              // TITLE
              Text(
                "Konfirmasi Logout",
                style: _soraAdmin(fontWeight: FontWeight.w700, fontSize: 18),
              ),

              const SizedBox(height: 8),

              // CONTENT
              Text(
                "Apakah Anda yakin ingin keluar?",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[700], fontSize: 14),
              ),

              const SizedBox(height: 24),

              // BUTTONS
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF9C5A1A),
                        side: const BorderSide(color: Color(0xFF9C5A1A)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text("Batal"),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        Navigator.pop(context); // tutup dialog dulu

                        await supabase.auth.signOut();

                        if (mounted) {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginPage(),
                            ),
                            (route) => false,
                          );
                        }
                      },
                      child: const Text("Ya, Keluar"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String t,
    String v,
    IconData i,
    Color c,
    VoidCallback tap,
  ) {
>>>>>>> 68bdf6d7946220431b5be431e88d850f148ff12a
    return GestureDetector(
      onTap: tap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: c.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(i, color: Colors.white, size: 28),
            const SizedBox(height: 15),
            Text(
              v,
              style: _soraAdmin(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              t,
              style: _jakartaAdmin(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
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
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DetailKosPage(kos: kos)),
        ),
        leading: const Icon(Icons.home_work, color: Color(0xFF9C5A1A)),
        title: Text(
          kos['name'] ?? "Nama Kost",
          style: _jakartaAdmin(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          "Rp ${formatRupiah(kos['price'])}",
          style: _jakartaAdmin(),
        ),
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
          Text(label, style: _jakartaAdmin(color: Colors.grey, fontSize: 12)),
          Text(value, style: _jakartaAdmin(fontWeight: FontWeight.w700, fontSize: 14)),
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

  const ListDataPage({
    super.key,
    required this.title,
    required this.table,
    required this.formatRupiah,
  });

  @override
  Widget build(BuildContext context) {
    final supabase = SupabaseService.client;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F2),
      appBar: AppBar(
        title: Text(title, style: _soraAdmin(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF9C5A1A),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder(
<<<<<<< HEAD
        // PERBAIKAN: Gunakan select('*') agar data deskripsi, fasilitas, dll ikut terambil
        future: table == 'kosts' 
            ? supabase.from('kosts').select('*').eq('is_approved', true) 
            : supabase.from('profiles').select('*').eq('role', 'owner').eq('is_approved', true),
=======
        future: table == 'kosts'
            ? supabase.from('kosts').select('*').eq('is_approved', true)
            : supabase
                  .from('profiles')
                  .select('*')
                  .eq('role', 'owner')
                  .eq('is_approved', true),
>>>>>>> 68bdf6d7946220431b5be431e88d850f148ff12a
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          final data = snapshot.data as List? ?? [];
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: data.length,
            itemBuilder: (context, i) {
              final item = data[i];
              return Card(
<<<<<<< HEAD
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFF2E8DA),
                    child: Icon(table == 'kosts' ? Icons.home_work : Icons.person, color: const Color(0xFF9C5A1A)),
                  ),
                  title: Text(item['name'] ?? item['email'] ?? 'User', style: _jakartaAdmin(fontWeight: FontWeight.w700)),
                  subtitle: Text(table == 'kosts' ? "Rp ${formatRupiah(item['price'])}" : (item['email'] ?? ""), style: _jakartaAdmin()),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    if (table == 'kosts') {
                      // Sekarang 'item' sudah membawa data lengkap
                      Navigator.push(context, MaterialPageRoute(builder: (_) => DetailKosPage(kos: item)));
=======
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFF2E8DA),
                    child: Icon(
                      table == 'kosts' ? Icons.home_work : Icons.person,
                      color: const Color(0xFF9C5A1A),
                    ),
                  ),
                  title: Text(
                    item['name'] ?? item['email'] ?? 'User',
                    style: _jakartaAdmin(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    table == 'kosts'
                        ? "Rp ${formatRupiah(item['price'])}"
                        : (item['email'] ?? ""),
                    style: _jakartaAdmin(),
                  ),
                  onTap: () {
                    if (table == 'kosts') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DetailKosPage(kos: item),
                        ),
                      );
>>>>>>> 68bdf6d7946220431b5be431e88d850f148ff12a
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OwnerDetailPage(
                            owner: item,
                            formatRupiah: formatRupiah,
                          ),
                        ),
                      );
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

  const OwnerDetailPage({
    super.key,
    required this.owner,
    required this.formatRupiah,
  });

  @override
  Widget build(BuildContext context) {
    final supabase = SupabaseService.client;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F2),
      appBar: AppBar(
<<<<<<< HEAD
        title: Text("Profil Owner", style: _soraAdmin(fontWeight: FontWeight.w700)),
=======
        title: Text(
          "Profil Owner",
          style: _soraAdmin(fontWeight: FontWeight.w700),
        ),
>>>>>>> 68bdf6d7946220431b5be431e88d850f148ff12a
        backgroundColor: const Color(0xFF9C5A1A),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder(
        // PERBAIKAN: Gunakan select('*') agar saat klik kos milik owner, datanya lengkap
        future: supabase.from('kosts').select('*').eq('owner_id', owner['id']),
        builder: (context, snapshot) {
          final kos = snapshot.data as List? ?? [];
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 50,
                  backgroundColor: Color(0xFF9C5A1A),
                  child: Icon(Icons.person, size: 60, color: Colors.white),
                ),
                const SizedBox(height: 20),
<<<<<<< HEAD
                Text(owner['name'] ?? "Owner", style: _soraAdmin(fontSize: 24, fontWeight: FontWeight.w700)),
                Text(owner['email'] ?? "-", style: _jakartaAdmin(color: Colors.grey)),
                const Divider(height: 50),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Kost yang dimiliki:", style: _soraAdmin(fontWeight: FontWeight.w700, fontSize: 18)),
                ),
                const SizedBox(height: 15),
                if (snapshot.connectionState == ConnectionState.waiting) 
                  const Center(child: CircularProgressIndicator())
                else if (kos.isEmpty)
                  Text("Belum ada kost.", style: _jakartaAdmin())
                else ...kos.map((k) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text(k['name'], style: _jakartaAdmin(fontWeight: FontWeight.w600)),
                    subtitle: Text("Rp ${formatRupiah(k['price'])}", style: _jakartaAdmin()),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailKosPage(kos: k))),
                  ),
                )).toList()
=======
                Text(
                  owner['name'] ?? "Owner",
                  style: _soraAdmin(fontSize: 24, fontWeight: FontWeight.w700),
                ),
                const Divider(height: 50),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Kost yang dimiliki:",
                    style: _soraAdmin(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                ...kos
                    .map(
                      (k) => Card(
                        child: ListTile(
                          title: Text(k['name']),
                          subtitle: Text("Rp ${formatRupiah(k['price'])}"),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DetailKosPage(kos: k),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
>>>>>>> 68bdf6d7946220431b5be431e88d850f148ff12a
              ],
            ),
          );
        },
      ),
    );
  }
}
<<<<<<< HEAD
=======

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
          title: Text(
            "Status Bayar ${now.month}/${now.year}",
            style: _soraAdmin(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          backgroundColor: const Color(0xFF9C5A1A),
          foregroundColor: Colors.white,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: "Tunggakan"),
              Tab(text: "Lunas"),
            ],
          ),
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
      future: supabase
          .from('payments')
          .select('*, kosts(name), profiles(name)')
          .eq('status', status)
          .eq('month', now.month)
          .eq('year', now.year),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        final data = snapshot.data as List? ?? [];
        if (data.isEmpty) return const Center(child: Text("Tidak ada data"));

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: data.length,
          itemBuilder: (context, i) {
            final item = data[i];
            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                title: Text(
                  item['profiles']['name'] ?? 'Tenant',
                  style: _jakartaAdmin(fontWeight: FontWeight.bold),
                ),
                subtitle: Text("Unit: ${item['kosts']['name']}"),
                trailing: Icon(
                  status == 'success' ? Icons.check_circle : Icons.error,
                  color: status == 'success' ? Colors.green : Colors.red,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
>>>>>>> 68bdf6d7946220431b5be431e88d850f148ff12a
