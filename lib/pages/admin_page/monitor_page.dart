import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kostly_pa/pages/admin_page/admin_ui.dart';
import 'package:kostly_pa/pages/admin_page/detail_kos.dart';
import 'package:kostly_pa/pages/login_page.dart';
import 'package:kostly_pa/services/media_service.dart';
import 'package:kostly_pa/services/notification_service.dart';
import 'package:kostly_pa/services/supabase_service.dart';

TextStyle _soraAdmin({double? fontSize, FontWeight? fontWeight, Color? color}) {
  return adminSora(fontSize: fontSize, fontWeight: fontWeight, color: color);
}

TextStyle _jakartaAdmin({
  double? fontSize,
  FontWeight? fontWeight,
  Color? color,
}) {
  return adminJakarta(fontSize: fontSize, fontWeight: fontWeight, color: color);
}

class MonitorPage extends StatefulWidget {
  const MonitorPage({super.key});

  @override
  State<MonitorPage> createState() => _MonitorPageState();
}

class _MonitorPageState extends State<MonitorPage> {
  final supabase = SupabaseService.client;
  StreamSubscription<NotificationSyncEvent>? _notificationSubscription;

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
    _notificationSubscription = AppNotificationService.events.listen((event) {
      if (!mounted) return;
      if (event.scope == 'admin_profiles' || event.scope == 'admin_kosts') {
        fetchStats();
      }
    });
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  String formatRupiah(dynamic price) {
    if (price == null) return "0";
    String priceStr = price.toString();
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return priceStr.replaceAllMapped(reg, (Match m) => '${m[1]}.');
  }

  Future<void> fetchStats() async {
    setState(() => isLoading = true);

    try {
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
      final top3WithImages = await MediaService.attachKostImages(
        (top3 as List)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList(),
      );

      setState(() {
        totalKos = (kosRes as List).length;
        totalOwner = (ownerRes as List).length;
        top3Terbaru = top3WithImages;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  // 🔥 LOGOUT DIALOG FINAL
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFFFFFBF7),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                Text(
                  "Konfirmasi Logout",
                  style: _soraAdmin(fontWeight: FontWeight.w700, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  "Apakah Anda yakin ingin keluar dari akun ini?",
                  textAlign: TextAlign.center,
                  style: _jakartaAdmin(color: Colors.grey),
                ),
                const SizedBox(height: 24),

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
                        ),
                        child: const Text("Batal"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await supabase.auth.signOut();

                          if (mounted) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LoginPage(),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text("Ya, Keluar"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AdminPalette.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: fetchStats,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // HEADER
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
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
                            style: _jakartaAdmin(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            adminEmail ?? "-",
                            style: _jakartaAdmin(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.power_settings_new,
                        color: Colors.redAccent,
                      ),
                      onPressed: () => _showLogoutDialog(context),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // STAT
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      "Total Kost",
                      totalKos.toString(),
                      Icons.business_rounded,
                      const Color(0xFF9C5A1A),
                      onTap: () => _openListDataPage(
                        title: "Daftar Kost",
                        table: "kosts",
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildStatCard(
                      "Total Owner",
                      totalOwner.toString(),
                      Icons.people_alt_rounded,
                      const Color(0xFF6B3A10),
                      onTap: () => _openListDataPage(
                        title: "Daftar Owner",
                        table: "profiles",
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              Text(
                "Unit Terbaru",
                style: _soraAdmin(fontSize: 18, fontWeight: FontWeight.w700),
              ),

              const SizedBox(height: 15),

              ...top3Terbaru.map((kos) => _buildRecentCard(kos)).toList(),
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
    Color c, {
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
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
              Row(
                children: [
                  Icon(i, color: Colors.white, size: 28),
                  const Spacer(),
                  if (onTap != null)
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white70,
                      size: 22,
                    ),
                ],
              ),
              const SizedBox(height: 15),
              Text(
                v,
                style: _soraAdmin(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(t, style: _jakartaAdmin(color: Colors.white70, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }

  void _openListDataPage({required String title, required String table}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ListDataPage(
          title: title,
          table: table,
          formatRupiah: formatRupiah,
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
          kos['name'] ?? "-",
          style: _jakartaAdmin(fontWeight: FontWeight.w700),
        ),
        subtitle: Text("Rp ${formatRupiah(kos['price'])}"),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

// ================= INFORMASI KOST =================
Widget buildInformasiKost(dynamic widget) {
  final bool hasWifi = widget.kos['include_wifi'] ?? false;
  final bool hasAir = widget.kos['include_water'] ?? false;
  final bool hasListrik = widget.kos['include_electricity'] ?? false;

  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: Column(
      children: [
        _buildInfoRow(
          Icons.wifi,
          "WiFi",
          hasWifi ? "Tersedia" : "Tidak Tersedia",
        ),
        const SizedBox(height: 12),
        const Divider(),
        const SizedBox(height: 12),
        _buildInfoRow(
          Icons.water_drop,
          "Air",
          hasAir ? "Sudah Include" : "Tidak Include",
        ),
        const SizedBox(height: 12),
        const Divider(),
        const SizedBox(height: 12),
        _buildInfoRow(
          Icons.bolt,
          "Listrik",
          hasListrik ? "Sudah Include" : "Tidak Include",
        ),
      ],
    ),
  );
}

Widget _buildInfoRow(IconData icon, String label, String value) {
  return Row(
    children: [
      Icon(icon, color: const Color(0xFF9C5A1A), size: 22),
      const SizedBox(width: 12),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _jakartaAdmin(color: Colors.grey, fontSize: 12)),
          Text(
            value,
            style: _jakartaAdmin(fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ],
      ),
    ],
  );
}

// ================= LIST DATA PAGE =================
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
      backgroundColor: AdminPalette.background,
      appBar: AppBar(
        title: Text(title, style: _soraAdmin(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: FutureBuilder(
        future: table == 'kosts'
            ? () async {
                final raw = await supabase
                    .from('kosts')
                    .select('*')
                    .eq('is_approved', true);
                return MediaService.attachKostImages(
                  (raw as List)
                      .map((item) => Map<String, dynamic>.from(item as Map))
                      .toList(),
                );
              }()
            : () async {
                final raw = await supabase
                    .from('profiles')
                    .select('*')
                    .eq('role', 'owner')
                    .eq('is_approved', true);
                final List<Map<String, dynamic>> owners = [];
                for (final item in (raw as List)) {
                  owners.add(
                    await MediaService.attachProfileImage(
                      Map<String, dynamic>.from(item as Map),
                    ),
                  );
                }
                return owners;
              }(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data as List? ?? [];

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: data.length,
            itemBuilder: (context, i) {
              final item = data[i];

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: AdminPalette.background,
                    backgroundImage: table == 'kosts'
                        ? null
                        : ((item['profile_photo_url']?.toString().isNotEmpty ??
                                  false)
                              ? NetworkImage(
                                  item['profile_photo_url'].toString(),
                                )
                              : null),
                    child: table == 'kosts'
                        ? const Icon(
                            Icons.home_work,
                            color: Color(0xFF9C5A1A),
                          )
                        : ((item['profile_photo_url']?.toString().isNotEmpty ??
                                  false)
                              ? null
                              : const Icon(
                                  Icons.person,
                                  color: Color(0xFF9C5A1A),
                                )),
                  ),
                  title: Text(
                    item['name'] ?? item['email'] ?? 'User',
                    style: _jakartaAdmin(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    table == 'kosts'
                        ? "Rp ${formatRupiah(item['price'])}"
                        : (item['email'] ?? ""),
                    style: _jakartaAdmin(color: Colors.grey[700]),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    if (table == 'kosts') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DetailKosPage(kos: item),
                        ),
                      );
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

// ================= OWNER DETAIL =================
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
    final String? ownerPhotoUrl = owner['profile_photo_url']?.toString();
    final bool hasOwnerPhoto =
        ownerPhotoUrl != null && ownerPhotoUrl.isNotEmpty;

    return Scaffold(
      backgroundColor: AdminPalette.background,
      appBar: AppBar(
        title: Text(
          "Profil Owner",
          style: _soraAdmin(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: FutureBuilder(
        future: () async {
          final raw = await supabase
              .from('kosts')
              .select('*')
              .eq('owner_id', owner['id']);
          return MediaService.attachKostImages(
            (raw as List)
                .map((item) => Map<String, dynamic>.from(item as Map))
                .toList(),
          );
        }(),
        builder: (context, snapshot) {
          final kos = snapshot.data as List? ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: const Color(0xFF9C5A1A),
                  backgroundImage: hasOwnerPhoto
                      ? NetworkImage(ownerPhotoUrl)
                      : null,
                  child: hasOwnerPhoto
                      ? null
                      : const Icon(Icons.person, size: 60, color: Colors.white),
                ),
                const SizedBox(height: 20),
                Text(
                  owner['full_name'] ?? owner['name'] ?? "Owner",
                  style: _soraAdmin(fontSize: 24, fontWeight: FontWeight.w700),
                ),
                Text(
                  owner['email'] ?? "-",
                  style: _jakartaAdmin(color: Colors.grey),
                ),

                const SizedBox(height: 30),

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

                if (snapshot.connectionState == ConnectionState.waiting)
                  const Center(child: CircularProgressIndicator())
                else if (kos.isEmpty)
                  Text("Belum ada kost.", style: _jakartaAdmin())
                else
                  ...kos.map(
                    (k) => Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: ListTile(
                        title: Text(
                          k['name'],
                          style: _jakartaAdmin(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          "Rp ${formatRupiah(k['price'])}",
                          style: _jakartaAdmin(),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DetailKosPage(kos: k),
                          ),
                        ),
                      ),
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
