import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:kostly_pa/pages/login_page.dart';
import 'package:kostly_pa/services/supabase_service.dart';

class UserHomePage extends StatefulWidget {
  const UserHomePage({super.key});

  @override
  State<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {
  static const String _kostPrefix = '[KOSTLY_KOST]';
  static const String _tenantPrefix = '[KOSTLY_TENANT]';
  static const String _titlePrefix = '[KOSTLY_TITLE]';
  static const String _bodyPrefix = '[KOSTLY_BODY]';

  final supabase = SupabaseService.client;
  final currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  Map? profileData;
  Map? kost;
  Map<String, dynamic>? currentPayment;
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
      if (user == null) {
        if (mounted) setState(() => isLoading = false);
        return;
      }

      // 🔹 ambil profile
      final profile = await supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();

      if (profile['kost_id'] != null) {
        final kosId = profile['kost_id'].toString();

        // 🔹 ambil data kost
        final kosData = await supabase
            .from('kosts')
            .select()
            .eq('id', kosId)
            .single();

        // 🔹 ambil pembayaran
        final paymentData = await _fetchCurrentPayment(user.id, kosId);

        // 🔥 AMBIL SEMUA REMINDER DARI SERVICE
        final allReminders = await SupabaseService.getUserReminders();

        final filteredReminders = allReminders.where((r) {
          return _isReminderForThisUserAndKost(r, kosId, user.id);
        }).toList();

        final reminderData = List<Map<String, dynamic>>.from(
          filteredReminders,
        ).take(3).toList();

        if (mounted) {
          setState(() {
            profileData = profile;
            kost = kosData;
            currentPayment = paymentData;
            reminders = reminderData; // ✅ sudah aman
            isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            profileData = profile;
            currentPayment = null;
            reminders = []; // 🔥 biar jelas kosong
            isLoading = false;
          });
        }
      }
    } catch (e) {
      print("ERROR HOME: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

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

  String _resolveKostNote(Map? data) {
    if (data == null) return '-';
    for (final key in const [
      'rules',
      'notes',
      'note',
      'description',
      'catatan',
      'keterangan',
    ]) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return '-';
  }

  bool _isReminderForThisUserAndKost(
    Map reminder,
    String currentKostId,
    String currentUserId,
  ) {
    final directKost = reminder['kost_id']?.toString();
    if (directKost != null && directKost.isNotEmpty) {
      if (directKost != currentKostId) return false;
    }

    for (final field in ['message', 'pesan']) {
      final raw = reminder[field];
      if (raw is String) {
        final parsed = _parsePackedMessage(raw);
        final packedKostId = parsed?['kost_id'];
        if (packedKostId != null && packedKostId.isNotEmpty) {
          if (packedKostId != currentKostId) return false;
        }

        final packedTenantId = parsed?['tenant_id'];
        if (packedTenantId != null && packedTenantId.isNotEmpty) {
          return packedTenantId == currentUserId;
        }
      }
    }

    return true;
  }

  Map<String, String>? _parsePackedMessage(String raw) {
    if (!raw.contains(_titlePrefix) || !raw.contains(_bodyPrefix)) {
      return null;
    }

    String? kostId;
    String? tenantId;
    final titleIndex = raw.indexOf(_titlePrefix);
    final bodyIndex = raw.indexOf(_bodyPrefix);
    if (titleIndex < 0 || bodyIndex < 0 || bodyIndex <= titleIndex) {
      return null;
    }

    if (raw.startsWith(_kostPrefix)) {
      final tenantIndex = raw.indexOf(_tenantPrefix, _kostPrefix.length);
      if (tenantIndex >= 0 && tenantIndex < titleIndex) {
        kostId = raw.substring(_kostPrefix.length, tenantIndex);
        tenantId = raw.substring(
          tenantIndex + _tenantPrefix.length,
          titleIndex,
        );
      } else if (titleIndex > _kostPrefix.length) {
        kostId = raw.substring(_kostPrefix.length, titleIndex);
      }
    }

    if (tenantId == null) {
      final tenantIndex = raw.indexOf(_tenantPrefix);
      if (tenantIndex >= 0 && tenantIndex < titleIndex) {
        tenantId = raw.substring(
          tenantIndex + _tenantPrefix.length,
          titleIndex,
        );
      }
    }

    final title = raw.substring(titleIndex + _titlePrefix.length, bodyIndex);
    final body = raw.substring(bodyIndex + _bodyPrefix.length);
    final result = {'title': title, 'body': body};
    if (kostId != null && kostId.isNotEmpty) result['kost_id'] = kostId;
    if (tenantId != null && tenantId.isNotEmpty) result['tenant_id'] = tenantId;
    return result;
  }

  String _reminderTitle(Map r) {
    final dynamic title = r['title'];
    if (title is String && title.trim().isNotEmpty) return title;

    final dynamic message = r['message'];
    if (message is String && message.trim().isNotEmpty) {
      final parsed = _parsePackedMessage(message);
      if (parsed != null && parsed['title']!.trim().isNotEmpty) {
        return parsed['title']!;
      }
      return message;
    }

    final dynamic pesan = r['pesan'];
    if (pesan is String && pesan.trim().isNotEmpty) {
      final parsed = _parsePackedMessage(pesan);
      if (parsed != null && parsed['title']!.trim().isNotEmpty) {
        return parsed['title']!;
      }
      return pesan;
    }

    return 'Pengumuman';
  }

  String _reminderText(Map r) {
    for (final field in ['message', 'pesan', 'description']) {
      final raw = r[field];
      if (raw is String && raw.trim().isNotEmpty) {
        final parsed = _parsePackedMessage(raw);
        return parsed != null ? parsed['body']! : raw;
      }
    }
    return '';
  }

  String _formatReminderTime(Map r) {
    final dynamic raw = r['reminder_at'] ?? r['created_at'] ?? r['waktu'];
    if (raw == null) return '--:--';

    final parsed = DateTime.tryParse(raw.toString());
    if (parsed == null) return '--:--';

    final local = parsed.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDay = DateTime(local.year, local.month, local.day);
    final dayDiff = today.difference(targetDay).inDays;

    if (dayDiff <= 0) return DateFormat('HH:mm').format(local);
    if (dayDiff == 1) return 'Kemarin';
    return DateFormat('dd/MM/yy').format(local);
  }

  Future<Map<String, dynamic>?> _fetchCurrentPayment(
    String userId,
    String kostId,
  ) async {
    final now = DateTime.now();

    try {
      // Langsung gunakan 'tenant_id' sesuai tabel kamu
      final List result = await supabase
          .from('payments')
          .select()
          .eq('month', now.month)
          .eq('year', now.year)
          .eq('tenant_id', userId)
          .order('created_at', ascending: false)
          .limit(1);

      if (result.isNotEmpty) {
        return Map<String, dynamic>.from(result.first as Map);
      }
    } catch (_) {}

    return null;
  }

  bool _isPaidStatus(String status) {
    return status == 'approved' || status == 'success' || status == 'paid';
  }

  String _paymentStatusLabel() {
    final raw = currentPayment?['status']?.toString().toLowerCase();
    if (raw == null || raw.isEmpty) return 'Belum Bayar';
    if (_isPaidStatus(raw)) return 'Sudah Bayar';
    if (raw == 'pending') return 'Menunggu ACC';
    if (raw == 'rejected') return 'Ditolak';
    return raw.toUpperCase();
  }

  Color _paymentStatusColor() {
    final raw = currentPayment?['status']?.toString().toLowerCase();
    if (raw == null || raw.isEmpty) return const Color(0xFFE24D56);
    if (_isPaidStatus(raw)) return const Color(0xFF2E7D32);
    if (raw == 'pending') return const Color(0xFFDD8A18);
    if (raw == 'rejected') return const Color(0xFFC62828);
    return const Color(0xFF7A6A58);
  }

  IconData _paymentStatusIcon() {
    final raw = currentPayment?['status']?.toString().toLowerCase();
    if (raw == null || raw.isEmpty) return Icons.money_off_rounded;
    if (_isPaidStatus(raw)) return Icons.check_circle_rounded;
    if (raw == 'pending') return Icons.hourglass_top_rounded;
    if (raw == 'rejected') return Icons.cancel_rounded;
    return Icons.receipt_long_rounded;
  }

  String _paymentStatusDescription() {
    final raw = currentPayment?['status']?.toString().toLowerCase();
    final now = DateTime.now();
    final period = DateFormat('MMMM yyyy', 'id_ID').format(now);

    if (raw == null || raw.isEmpty) {
      return 'Belum ada pembayaran tercatat untuk $period.';
    }
    if (_isPaidStatus(raw)) {
      return 'Pembayaran kamu untuk $period sudah diterima owner.';
    }
    if (raw == 'pending') {
      return 'Pembayaran kamu untuk $period sedang menunggu ACC owner.';
    }
    if (raw == 'rejected') {
      return 'Pembayaran untuk $period ditolak. Silakan hubungi owner.';
    }
    return 'Status pembayaran bulan ini: ${raw.toUpperCase()}.';
  }

  bool _canSubmitPaymentRequest() {
    final raw = currentPayment?['status']?.toString().toLowerCase();
    if (raw == null || raw.isEmpty) return true;
    if (raw == 'rejected') return true;
    return false;
  }

  Future<void> _submitPaymentRequest() async {
    final user = supabase.auth.currentUser;
    if (user == null || kost == null) return;

    final now = DateTime.now();

    try {
      if (currentPayment != null && currentPayment!['id'] != null) {
        final status = currentPayment?['status']?.toString().toLowerCase();
        if (status == 'pending') {
          throw Exception('Pembayaran bulan ini masih menunggu ACC owner');
        }
        if (status != null && _isPaidStatus(status)) {
          throw Exception('Pembayaran bulan ini sudah disetujui');
        }

        // Update data jika sudah ada (misal sebelumnya ditolak, lalu diajukan ulang)
        await supabase
            .from('payments')
            .update({
              'status': 'pending',
              'month': now.month,
              'year': now.year,
              'kost_id': kost!['id'],
              'amount': kost!['price'], // Kirim ulang amount untuk berjaga-jaga
            })
            .eq('id', currentPayment!['id']);
      } else {
        // Insert data baru
        await supabase.from('payments').insert({
          'kost_id': kost!['id'],
          'tenant_id': user.id, // Langsung pakai tenant_id
          'amount': kost!['price'], // WAJIB DIKIRIM karena 'not null' di tabel
          'month': now.month,
          'year': now.year,
          'status': 'pending',
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Ajuan pembayaran berhasil dikirim ke owner."),
          ),
        );
      }

      await fetchData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _joinKost(String code) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final trimmedCode = code.trim().toUpperCase();
      if (trimmedCode.isEmpty) throw Exception('Kode kosong');

      final List kostResult = await supabase
          .from('kosts')
          .select('id, is_approved')
          .eq('join_code', trimmedCode)
          .limit(1);

      if (kostResult.isEmpty) throw Exception('Kode tidak valid');

      final Map selectedKost = kostResult.first;
      if (selectedKost['is_approved'] != true) {
        throw Exception('Kost belum disetujui admin');
      }

      final nowIso = DateTime.now().toIso8601String();
      final List<Map<String, dynamic>> joinPayloadCandidates = [
        {
          'kost_id': selectedKost['id'],
          'exit_request': false,
          'kost_joined_at': nowIso,
        },
        {
          'kost_id': selectedKost['id'],
          'exit_request': false,
          'entry_date': nowIso,
        },
        {
          'kost_id': selectedKost['id'],
          'exit_request': false,
          'join_date': nowIso,
        },
        {'kost_id': selectedKost['id'], 'exit_request': false},
      ];

      Object? lastError;
      bool updated = false;
      for (final payload in joinPayloadCandidates) {
        try {
          await supabase.from('profiles').update(payload).eq('id', user.id);
          updated = true;
          break;
        } catch (e) {
          lastError = e;
        }
      }
      if (!updated) {
        throw Exception(lastError?.toString() ?? 'Gagal memperbarui data kost');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Berhasil masuk ke kost.")),
        );
      }

      await fetchData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _requestExit() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      await supabase
          .from('profiles')
          .update({'exit_request': true})
          .eq('id', user.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Permintaan keluar berhasil dikirim.")),
        );
      }

      await fetchData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Gagal mengajukan keluar: $e")));
      }
    }
  }

  void _showJoinKostDialog() {
    final TextEditingController codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFFFFFBF7),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24), // 🔥 FIX
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400), // 🔥 FIX
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9C5A1A).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.home_work,
                    color: Color(0xFF9C5A1A),
                    size: 26,
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  "Daftar Kost",
                  style: GoogleFonts.sora(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: const Color(0xFF4A2C0A),
                  ),
                ),

                const SizedBox(height: 12),

                TextField(
                  controller: codeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: "Masukkan Kode Kost",
                    filled: true,
                    fillColor: const Color(0xFFFDF8F2),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
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
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text("Batal"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _joinKost(codeController.text);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9C5A1A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                        ),
                        child: const Text("Daftar"),
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

  void _showProfilePopup() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(
          horizontal: 24,
        ), // 🔥 JARAK SAMPING
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400), // 🔥 BATAS LEBAR
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              color: Colors.white,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // HEADER
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  color: const Color(0xFF9C5A1A),
                  child: Column(
                    children: [
                      const CircleAvatar(
                        radius: 35,
                        backgroundColor: Color(0xFFF3E3CF),
                        child: Icon(
                          Icons.person,
                          size: 40,
                          color: Color(0xFF9C5A1A),
                        ),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        "Detail Akun",
                        style: GoogleFonts.sora(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                // CONTENT
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _buildPopupField(
                        "Nama Pengguna",
                        profileData?['full_name'] ?? "-",
                      ),
                      _buildPopupField(
                        "Nomor Pengguna",
                        profileData?['phone_number'] ?? "-",
                      ),
                      _buildPopupField(
                        "Email",
                        supabase.auth.currentUser?.email ?? "-",
                      ),

                      const SizedBox(height: 20),

                      _buildActionButton(
                        "Tutup",
                        const Color(0xFFF3E3CF),
                        const Color(0xFF9C5A1A),
                        () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPopupField(String label, String value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF7F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEADBC9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmation() {
    final pageContext = context;

    showDialog(
      context: pageContext,
      builder: (dialogContext) => Dialog(
        backgroundColor: const Color(0xFFFFFBF7),
        insetPadding: const EdgeInsets.symmetric(
          horizontal: 24,
        ), // 🔥 biar nggak full lebar
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 400,
          ), // 🔥 konsisten semua dialog
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 🔥 ICON
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE24D56).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: Color(0xFFE24D56),
                    size: 26,
                  ),
                ),

                const SizedBox(height: 16),

                // TITLE
                Text(
                  "Keluar Akun",
                  style: GoogleFonts.sora(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: const Color(0xFF2D241A),
                  ),
                ),

                const SizedBox(height: 8),

                // MESSAGE
                Text(
                  "Yakin ingin keluar dari akun sekarang?",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: const Color(0xFF6B6257),
                    height: 1.35,
                  ),
                ),

                const SizedBox(height: 24),

                // BUTTONS
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(
                          dialogContext,
                          rootNavigator: true,
                        ).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF9C5A1A),
                          side: const BorderSide(color: Color(0xFF9C5A1A)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          "Batal",
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.of(
                            dialogContext,
                            rootNavigator: true,
                          ).pop();

                          await supabase.auth.signOut();

                          if (mounted) {
                            Navigator.of(
                              pageContext,
                              rootNavigator: true,
                            ).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (_) => const LoginPage(),
                              ),
                              (route) => false,
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE24D56),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          "Logout",
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
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
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF9C5A1A)),
        ),
      );
    }

    final bool isPendingExit = profileData?['exit_request'] ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFFF2E8DA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: fetchData,
          color: const Color(0xFF9C5A1A),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildTopHeader(),
              const SizedBox(height: 25),
              Text(
                "Informasi Unit Kost",
                style: GoogleFonts.sora(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2D241A),
                ),
              ),
              const SizedBox(height: 20),
              _buildUnitCard(isPendingExit),
              const SizedBox(height: 28),
              Text(
                "Status Pembayaran",
                style: GoogleFonts.sora(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2D241A),
                ),
              ),
              const SizedBox(height: 15),
              _buildPaymentStatusCard(),
              const SizedBox(height: 35),
              Text(
                "Pengumuman Terbaru",
                style: GoogleFonts.sora(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2D241A),
                ),
              ),
              const SizedBox(height: 15),
              _buildReminderPreview(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeader() {
    return Row(
      children: [
        GestureDetector(
          onTap: _showProfilePopup,
          child: const CircleAvatar(
            radius: 22,
            backgroundColor: Color(0xFF9C5A1A),
            child: Icon(Icons.person, color: Colors.white),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profileData?['full_name'] ?? "User",
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                "Lihat Profil",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: _showJoinKostDialog,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF3E3CF),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF9C5A1A)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.person_add_alt_1_rounded,
                  size: 16,
                  color: Color(0xFF9C5A1A),
                ),
                const SizedBox(width: 4),
                Text(
                  "Daftar Kost",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF9C5A1A),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _showLogoutConfirmation,
          icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
        ),
      ],
    );
  }

  Widget _buildUnitCard(bool isPendingExit) {
    if (kost == null) return _buildNoKostPlaceholder();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF3E3CF),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Text(
              kost!['name'] ?? '-',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF9C5A1A),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoBox(
            Icons.payments_rounded,
            "Biaya Sewa:",
            currency.format(kost!['price'] ?? 0),
          ),
          _buildInfoBox(
            Icons.bolt_rounded,
            "Listrik:",
            _resolveIncludeFlag(
                  kost,
                  primaryKey: 'include_electricity',
                  fallbackKeys: const ['include_listrik', 'listrik'],
                )
                ? "Include"
                : "Tidak termasuk",
          ),
          _buildInfoBox(
            Icons.water_drop_rounded,
            "Air:",
            _resolveIncludeFlag(
                  kost,
                  primaryKey: 'include_water',
                  fallbackKeys: const ['include_air', 'air'],
                )
                ? "Include"
                : "Tidak termasuk",
          ),
          _buildInfoBox(
            Icons.wifi_rounded,
            "WiFi:",
            _resolveIncludeFlag(
                  kost,
                  primaryKey: 'include_wifi',
                  fallbackKeys: const ['wifi'],
                )
                ? "Tersedia"
                : "Tidak Tersedia",
          ),
          _buildMultilineInfoBox(
            Icons.sticky_note_2_rounded,
            "Catatan Kost:",
            _resolveKostNote(kost),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isPendingExit ? null : _requestExit,
              style: ElevatedButton.styleFrom(
                backgroundColor: isPendingExit
                    ? Colors.grey[200]
                    : const Color(0xFFFFEFF1),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                  side: BorderSide(
                    color: isPendingExit
                        ? Colors.grey
                        : Colors.redAccent.withOpacity(0.5),
                  ),
                ),
              ),
              child: Text(
                isPendingExit
                    ? "Menunggu Persetujuan Keluar"
                    : "Ajukan Keluar dari Kost",
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  color: isPendingExit ? Colors.grey : Colors.redAccent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBox(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF7F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEADBC9)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF9C5A1A)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF3E3328),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultilineInfoBox(IconData icon, String label, String value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF7F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEADBC9)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 20, color: const Color(0xFF9C5A1A)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF3E3328),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoKostPlaceholder() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.house_siding_rounded,
            size: 60,
            color: Color(0xFF9C5A1A),
          ),
          const SizedBox(height: 15),
          Text(
            "Belum terdaftar di kost manapun.",
            style: GoogleFonts.plusJakartaSans(color: Colors.grey[600]),
          ),
          const SizedBox(height: 20),
          _buildActionButton(
            "Daftar Kost Sekarang",
            const Color(0xFF9C5A1A),
            Colors.white,
            _showJoinKostDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    Color bg,
    Color text,
    VoidCallback onTap,
  ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            color: text,
          ),
        ),
      ),
    );
  }

  Widget _buildReminderPreview() {
    if (reminders.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            "Belum ada pengumuman",
            style: GoogleFonts.plusJakartaSans(color: Colors.grey),
          ),
        ),
      );
    }

    return Column(
      children: reminders
          .map(
            (r) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: const Color(0xFFEADBC9)),
              ),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFF3E3CF),
                  child: Icon(
                    Icons.notifications_active,
                    color: Color(0xFF9C5A1A),
                    size: 20,
                  ),
                ),
                title: Text(
                  _reminderTitle(r),
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  _reminderText(r),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  _formatReminderTime(r),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF7A6A58),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildPaymentStatusCard() {
    if (kost == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFEADBC9)),
        ),
        child: Text(
          "Status pembayaran akan muncul setelah kamu terdaftar di kost.",
          style: GoogleFonts.plusJakartaSans(color: Colors.grey[700]),
        ),
      );
    }

    final statusColor = _paymentStatusColor();
    final now = DateTime.now();
    final period = DateFormat('MMMM yyyy', 'id_ID').format(now);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEADBC9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_paymentStatusIcon(), color: statusColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Tagihan $period",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _paymentStatusLabel(),
                      style: GoogleFonts.sora(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF9F2E7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.payments_rounded,
                  color: Color(0xFF9C5A1A),
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Nominal sewa bulan ini",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: const Color(0xFF6B6257),
                    ),
                  ),
                ),
                Text(
                  currency.format(kost?['price'] ?? 0),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF2D241A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _paymentStatusDescription(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              height: 1.45,
              color: const Color(0xFF5F5549),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _canSubmitPaymentRequest()
                  ? _submitPaymentRequest
                  : null,
              icon: Icon(
                _canSubmitPaymentRequest()
                    ? Icons.send_rounded
                    : _paymentStatusIcon(),
                size: 18,
              ),
              label: Text(
                _canSubmitPaymentRequest()
                    ? "Ajukan Pembayaran"
                    : _paymentStatusLabel(),
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _canSubmitPaymentRequest()
                    ? const Color(0xFF9C5A1A)
                    : statusColor.withOpacity(0.12),
                foregroundColor: _canSubmitPaymentRequest()
                    ? Colors.white
                    : statusColor,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
