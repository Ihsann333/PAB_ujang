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
  static const String _kostPrefix = '[KOSTLY_KOST]';
  static const String _titlePrefix = '[KOSTLY_TITLE]';
  static const String _bodyPrefix = '[KOSTLY_BODY]';

  final supabase = SupabaseService.client;
  final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  Map? profileData;
  Map? kost;
  List reminders = [];
  bool isLoading = true;

  bool _resolveIncludeFlag(
    Map? data, {
    required String primaryKey,
    List<String> fallbackKeys = const [],
  }) {
    if (data == null) return false;

    final dynamic primary = data[primaryKey];
    if (primary is bool) return primary;

    for (final key in fallbackKeys) {
      final dynamic value = data[key];
      if (value is bool) return value;
    }
    return false;
  }

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
        final kosId = profile['kost_id'].toString();
        final kosData = await supabase.from('kosts').select().eq('id', kosId).single();
        
        // 3. Ambil Reminder terbaru
        final ownerId = kosData['owner_id'].toString();
        List reminderData;
        try {
          reminderData = await supabase
              .from('reminders')
              .select()
              .eq('owner_id', ownerId)
              .order('created_at', ascending: false)
              .limit(3);
        } catch (_) {
          reminderData = await supabase
              .from('reminders')
              .select()
              .eq('user_id', ownerId)
              .order('created_at', ascending: false)
              .limit(3);
        }
        reminderData = reminderData
            .where((r) => _isReminderForThisKost(r, kosId))
            .toList();
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

  Future<void> _joinKostByCode(String code) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      if (profileData?['kost_id'] != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Kamu sudah terdaftar di kost. Ajukan keluar dulu jika ingin pindah.")),
          );
        }
        return;
      }

      final trimmedCode = code.trim().toUpperCase();
      if (trimmedCode.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Kode kost tidak boleh kosong.")),
          );
        }
        return;
      }

      final List kostResult = await supabase
          .from('kosts')
          .select('id, is_approved')
          .eq('join_code', trimmedCode)
          .limit(1);

      if (kostResult.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Kode kost tidak ditemukan.")),
          );
        }
        return;
      }

      final Map selectedKost = kostResult.first;
      final bool isApproved = selectedKost['is_approved'] == true;

      if (!isApproved) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Kost belum disetujui admin.")),
          );
        }
        return;
      }

      await supabase.from('profiles').update({
        'kost_id': selectedKost['id'],
        'exit_request': false,
      }).eq('id', user.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Berhasil masuk ke kost.")),
        );
        fetchData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal daftar kost: $e")),
        );
      }
    }
  }

  void _showJoinKostDialog() {
    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        contentPadding: EdgeInsets.zero,
        content: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBF5),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF5A3A17).withOpacity(0.16),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Daftar Kost",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2E241A),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8EFE3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE9D7C2)),
                ),
                child: TextField(
                  controller: codeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: "Masukkan kode kost",
                    hintText: "Contoh: AB12CD",
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF7B6A56),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      "Batal",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9C5A1A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _joinKostByCode(codeController.text);
                    },
                    child: const Text(
                      "Masuk",
                      style: TextStyle(fontWeight: FontWeight.w700),
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

  // POP-UP PROFIL
  void _showProfilePopup() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        contentPadding: EdgeInsets.zero,
        content: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            color: const Color(0xFFFFFBF5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF5A3A17).withOpacity(0.18),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(26),
                    topRight: Radius.circular(26),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFB06A22), Color(0xFF8A4F17)],
                  ),
                ),
                child: Column(
                  children: const [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.person, size: 34, color: Colors.white),
                    ),
                    SizedBox(height: 12),
                    Text(
                      "Detail Akun",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: Column(
                  children: [
                    _buildPopupItem("Nama Pengguna", profileData?['full_name'] ?? "-"),
                    const SizedBox(height: 12),
                    _buildPopupItem("Nomor Pengguna", profileData?['phone_number'] ?? "-"),
                    const SizedBox(height: 12),
                    _buildPopupItem("Email", supabase.auth.currentUser?.email ?? "-"),
                    const SizedBox(height: 12),
                    _buildPopupItem("Status", profileData?['kost_id'] == null ? "Belum ada Kos" : "Aktif"),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFFF3E3CF),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          "Tutup",
                          style: TextStyle(
                            color: Color(0xFF9C5A1A),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFF9C5A1A)));

    final String userDisplay = profileData?['full_name'] ?? supabase.auth.currentUser?.email?.split('@')[0] ?? "User";
    final bool isPendingExit = profileData?['exit_request'] ?? false;
    final bool isNarrow = MediaQuery.of(context).size.width < 430;

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
                Expanded(
                  child: GestureDetector(
                    onTap: _showProfilePopup,
                    child: Row(
                      children: [
                        const CircleAvatar(backgroundColor: Color(0xFF9C5A1A), child: Icon(Icons.person, color: Colors.white, size: 20)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userDisplay,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Text("Lihat Profil", style: TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF9C5A1A),
                        side: const BorderSide(color: Color(0xFF9C5A1A)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: EdgeInsets.symmetric(horizontal: isNarrow ? 10 : 12, vertical: 10),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: _showJoinKostDialog,
                      icon: const Icon(Icons.how_to_reg, size: 18),
                      label: Text(isNarrow ? "Daftar" : "Daftar Kost"),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: () async {
                        await supabase.auth.signOut();
                        if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginPage()), (route) => false);
                      },
                      icon: const Icon(Icons.logout, color: Colors.redAccent),
                    ),
                  ],
                )
              ],
            ),
            
            const SizedBox(height: 25),
            const Text(
              "Informasi Unit Kos",
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: Color(0xFF2A221B)),
            ),
            const SizedBox(height: 12),
            
            // CARD INFORMASI KOS
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFCF7),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFEADBC9)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF5A3A17).withOpacity(0.07),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFF7E8D3), Color(0xFFF3DFC4)],
                      ),
                    ),
                    child: Text(
                      kost?['name'] ?? 'Belum Terdaftar di Unit',
                      style: const TextStyle(
                        fontSize: 29 / 2,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF9C5A1A),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(kost?['address'] ?? 'Silakan hubungi admin untuk daftar', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 16),

                  _buildDetailRow(Icons.payments, "Biaya Sewa", currency.format(kost?['price'] ?? 0)),
                  _buildDetailRow(
                    Icons.flash_on,
                    "Listrik",
                    _resolveIncludeFlag(
                      kost,
                      primaryKey: 'include_electricity',
                      fallbackKeys: const ['include_listrik', 'listrik'],
                    )
                        ? "Include"
                        : "Tidak termasuk",
                  ),
                  _buildDetailRow(
                    Icons.water_drop,
                    "Air",
                    _resolveIncludeFlag(
                      kost,
                      primaryKey: 'include_water',
                      fallbackKeys: const ['include_air', 'air'],
                    )
                        ? "Include"
                        : "Tidak termasuk",
                  ),
                  _buildDetailRow(
                    Icons.wifi,
                    "WiFi",
                    _resolveIncludeFlag(
                      kost,
                      primaryKey: 'include_wifi',
                      fallbackKeys: const ['wifi'],
                    )
                        ? "Tersedia"
                        : "Tidak Tersedia",
                  ),

                  const SizedBox(height: 18),

                  // TOMBOL REQUEST KELUAR
                  if (kost != null)
                    SizedBox(
                      width: double.infinity,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isPendingExit ? const Color(0xFF8E8E8E) : const Color(0xFFE24D56),
                            backgroundColor: isPendingExit ? const Color(0xFFF0EFEC) : const Color(0xFFFFEFF1),
                            side: BorderSide(color: isPendingExit ? const Color(0xFFD3D3D3) : const Color(0xFFFF9FA6)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: isPendingExit ? null : () => _showExitConfirmation(),
                          child: Text(isPendingExit ? "Menunggu Persetujuan Keluar" : "Ajukan Keluar dari Kos"),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 30),
            const Text(
              "Pengumuman Terbaru",
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: Color(0xFF2A221B)),
            ),
            const SizedBox(height: 12),

            if (reminders.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFCF7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFEADBC9)),
                ),
                child: const Center(
                  child: Text(
                    "Belum ada pengumuman",
                    style: TextStyle(color: Color(0xFF9A958E), fontSize: 13),
                  ),
                ),
              )
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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F2E7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE9D7C2)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFFFFE9CC),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: const Color(0xFF9C5A1A)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text("$label: ", style: const TextStyle(fontSize: 13, color: Color(0xFF6B6257))),
          ),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF2A221B))),
        ],
      ),
    );
  }

  String _reminderText(Map r) {
    final dynamic message = r['message'];
    if (message is String && message.trim().isNotEmpty) {
      final parsed = _parsePackedMessage(message);
      return parsed != null ? parsed['body']! : message;
    }
    final dynamic pesan = r['pesan'];
    if (pesan is String && pesan.trim().isNotEmpty) {
      final parsed = _parsePackedMessage(pesan);
      return parsed != null ? parsed['body']! : pesan;
    }
    final dynamic description = r['description'];
    if (description is String && description.trim().isNotEmpty) {
      final parsed = _parsePackedMessage(description);
      return parsed != null ? parsed['body']! : description;
    }
    return '-';
  }

  String _reminderTitle(Map r) {
    final dynamic title = r['title'];
    if (title is String && title.trim().isNotEmpty) return title;
    final dynamic judul = r['judul'];
    if (judul is String && judul.trim().isNotEmpty) return judul;
    final dynamic message = r['message'];
    if (message is String && message.trim().isNotEmpty) {
      final parsed = _parsePackedMessage(message);
      if (parsed != null && parsed['title']!.trim().isNotEmpty) return parsed['title']!;
    }
    final dynamic pesan = r['pesan'];
    if (pesan is String && pesan.trim().isNotEmpty) {
      final parsed = _parsePackedMessage(pesan);
      if (parsed != null && parsed['title']!.trim().isNotEmpty) return parsed['title']!;
    }
    return 'Info';
  }

  String _formatReminderDateTime(Map r) {
    final dynamic raw = r['reminder_at'] ?? r['created_at'] ?? r['waktu'];
    if (raw == null) return '-';
    final parsed = DateTime.tryParse(raw.toString());
    if (parsed == null) return raw.toString();
    return DateFormat('dd MMM yyyy, HH:mm').format(parsed.toLocal());
  }

  Map<String, String>? _parsePackedMessage(String raw) {
    if (!raw.contains(_titlePrefix) || !raw.contains(_bodyPrefix)) return null;

    String work = raw;
    String? kostId;
    if (work.startsWith(_kostPrefix)) {
      final titleStart = work.indexOf(_titlePrefix);
      if (titleStart > _kostPrefix.length) {
        kostId = work.substring(_kostPrefix.length, titleStart);
      }
    }

    final titleIndex = work.indexOf(_titlePrefix);
    final bodyIndex = work.indexOf(_bodyPrefix);
    if (titleIndex < 0 || bodyIndex < 0 || bodyIndex <= titleIndex) return null;

    final title = work.substring(titleIndex + _titlePrefix.length, bodyIndex);
    final body = work.substring(bodyIndex + _bodyPrefix.length);
    final result = {'title': title, 'body': body};
    if (kostId != null && kostId.isNotEmpty) result['kost_id'] = kostId;
    return result;
  }

  bool _isReminderForThisKost(Map reminder, String userKostId) {
    final dynamic directKost = reminder['kost_id'];
    if (directKost != null && directKost.toString().isNotEmpty) {
      return directKost.toString() == userKostId;
    }

    final dynamic message = reminder['message'];
    if (message is String) {
      final parsed = _parsePackedMessage(message);
      final packedKostId = parsed?['kost_id'];
      if (packedKostId != null && packedKostId.isNotEmpty) {
        return packedKostId == userKostId;
      }
    }

    final dynamic pesan = reminder['pesan'];
    if (pesan is String) {
      final parsed = _parsePackedMessage(pesan);
      final packedKostId = parsed?['kost_id'];
      if (packedKostId != null && packedKostId.isNotEmpty) {
        return packedKostId == userKostId;
      }
    }
    return true;
  }

  Widget _buildPopupItem(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8EFE3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE9D7C2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF8E8E8E),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Color(0xFF2A221B),
            ),
          ),
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
        title: Text(_reminderTitle(r), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_reminderText(r), style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            Text(
              _formatReminderDateTime(r),
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
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
  static const String _kostPrefix = '[KOSTLY_KOST]';
  static const String _titlePrefix = '[KOSTLY_TITLE]';
  static const String _bodyPrefix = '[KOSTLY_BODY]';

  final supabase = SupabaseService.client;
  List reminders = [];
  bool isLoading = true;

  String _reminderText(Map r) {
    final dynamic message = r['message'];
    if (message is String && message.trim().isNotEmpty) {
      final parsed = _parsePackedMessage(message);
      return parsed != null ? parsed['body']! : message;
    }
    final dynamic pesan = r['pesan'];
    if (pesan is String && pesan.trim().isNotEmpty) {
      final parsed = _parsePackedMessage(pesan);
      return parsed != null ? parsed['body']! : pesan;
    }
    final dynamic description = r['description'];
    if (description is String && description.trim().isNotEmpty) {
      final parsed = _parsePackedMessage(description);
      return parsed != null ? parsed['body']! : description;
    }
    return '-';
  }

  String _reminderTitle(Map r) {
    final dynamic title = r['title'];
    if (title is String && title.trim().isNotEmpty) return title;
    final dynamic judul = r['judul'];
    if (judul is String && judul.trim().isNotEmpty) return judul;
    final dynamic message = r['message'];
    if (message is String && message.trim().isNotEmpty) {
      final parsed = _parsePackedMessage(message);
      if (parsed != null && parsed['title']!.trim().isNotEmpty) return parsed['title']!;
    }
    final dynamic pesan = r['pesan'];
    if (pesan is String && pesan.trim().isNotEmpty) {
      final parsed = _parsePackedMessage(pesan);
      if (parsed != null && parsed['title']!.trim().isNotEmpty) return parsed['title']!;
    }
    return 'Info';
  }

  String _formatReminderDateTime(Map r) {
    final dynamic raw = r['reminder_at'] ?? r['created_at'] ?? r['waktu'];
    if (raw == null) return '-';
    final parsed = DateTime.tryParse(raw.toString());
    if (parsed == null) return raw.toString();
    return DateFormat('dd MMM yyyy, HH:mm').format(parsed.toLocal());
  }

  Map<String, String>? _parsePackedMessage(String raw) {
    if (!raw.contains(_titlePrefix) || !raw.contains(_bodyPrefix)) return null;

    String work = raw;
    String? kostId;
    if (work.startsWith(_kostPrefix)) {
      final titleStart = work.indexOf(_titlePrefix);
      if (titleStart > _kostPrefix.length) {
        kostId = work.substring(_kostPrefix.length, titleStart);
      }
    }

    final titleIndex = work.indexOf(_titlePrefix);
    final bodyIndex = work.indexOf(_bodyPrefix);
    if (titleIndex < 0 || bodyIndex < 0 || bodyIndex <= titleIndex) return null;

    final title = work.substring(titleIndex + _titlePrefix.length, bodyIndex);
    final body = work.substring(bodyIndex + _bodyPrefix.length);
    final result = {'title': title, 'body': body};
    if (kostId != null && kostId.isNotEmpty) result['kost_id'] = kostId;
    return result;
  }

  bool _isReminderForThisKost(Map reminder, String userKostId) {
    final dynamic directKost = reminder['kost_id'];
    if (directKost != null && directKost.toString().isNotEmpty) {
      return directKost.toString() == userKostId;
    }

    final dynamic message = reminder['message'];
    if (message is String) {
      final parsed = _parsePackedMessage(message);
      final packedKostId = parsed?['kost_id'];
      if (packedKostId != null && packedKostId.isNotEmpty) {
        return packedKostId == userKostId;
      }
    }

    final dynamic pesan = reminder['pesan'];
    if (pesan is String) {
      final parsed = _parsePackedMessage(pesan);
      final packedKostId = parsed?['kost_id'];
      if (packedKostId != null && packedKostId.isNotEmpty) {
        return packedKostId == userKostId;
      }
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    fetchReminders();
  }

  Future<void> fetchReminders() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final profile = await supabase.from('profiles').select('kost_id').eq('id', user.id).single();
      final kostId = profile['kost_id'];
      if (kostId == null) {
        if (mounted) {
          setState(() {
            reminders = [];
            isLoading = false;
          });
        }
        return;
      }

      final userKostId = kostId.toString();
      final kost = await supabase.from('kosts').select('owner_id').eq('id', userKostId).single();
      final ownerId = kost['owner_id'].toString();
      List data;
      try {
        data = await supabase
            .from('reminders')
            .select()
            .eq('owner_id', ownerId)
            .order('created_at', ascending: false);
      } catch (_) {
        data = await supabase
            .from('reminders')
            .select()
            .eq('user_id', ownerId)
            .order('created_at', ascending: false);
      }
      data = data
          .where((r) => _isReminderForThisKost(r, userKostId))
          .toList();
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
                  title: Text(_reminderTitle(r)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_reminderText(r)),
                      const SizedBox(height: 4),
                      Text(
                        _formatReminderDateTime(r),
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
    );
  }
}
