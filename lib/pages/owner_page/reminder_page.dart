import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:kostly_pa/services/supabase_service.dart';

class ReminderPage extends StatefulWidget {
  const ReminderPage({super.key});

  @override
  State<ReminderPage> createState() => _ReminderPageState();
}

class _ReminderPageState extends State<ReminderPage> {
  static const String _titlePrefix = '[KOSTLY_TITLE]';
  static const String _bodyPrefix = '[KOSTLY_BODY]';
  static const String _kostPrefix = '[KOSTLY_KOST]';
  static const String _tenantPrefix = '[KOSTLY_TENANT]';

  final supabase = SupabaseService.client;
  final currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _msgCtrl = TextEditingController();

  List myKosts = [];
  String? selectedKostId;
  bool isSending = false;
  String? activeLateReminderTenantId;
  List reminders = [];
  List paymentNotifications = [];
  bool isLoadingReminders = true;
  bool isLoadingPayments = true;

  @override
  void initState() {
    super.initState();
    _refreshPage();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _refreshPage() async {
    await _fetchMyKosts();
    await fetchReminders();
    await fetchPaymentNotifications();
  }

  Future<void> _fetchMyKosts() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final data = await supabase
          .from('kosts')
          .select('id,name,is_approved')
          .eq('owner_id', userId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          myKosts = data as List;
          if (selectedKostId == null && myKosts.isNotEmpty) {
            selectedKostId = myKosts.first['id'].toString();
          }
        });
      }
    } catch (_) {}
  }

  Future<void> fetchReminders() async {
    if (!mounted) return;
    setState(() => isLoadingReminders = true);
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) setState(() => isLoadingReminders = false);
        return;
      }

      List data;
      try {
        data = await supabase
            .from('reminders')
            .select()
            .eq('owner_id', userId)
            .order('created_at', ascending: false);
      } catch (_) {
        data = await supabase
            .from('reminders')
            .select()
            .eq('user_id', userId)
            .order('created_at', ascending: false);
      }

      if (mounted) {
        setState(() {
          reminders = data;
          isLoadingReminders = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoadingReminders = false);
    }
  }

  Future<void> fetchPaymentNotifications() async {
    if (!mounted) return;
    setState(() => isLoadingPayments = true);

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) {
          setState(() {
            paymentNotifications = [];
            isLoadingPayments = false;
          });
        }
        return;
      }

      final now = DateTime.now();
      final kostData = await supabase
          .from('kosts')
          .select('id,name,price')
          .eq('owner_id', userId);
      final List kosts = kostData as List;
      final List kostIds = kosts.map((k) => k['id']).toList();

      if (kostIds.isEmpty) {
        if (mounted) {
          setState(() {
            paymentNotifications = [];
            isLoadingPayments = false;
          });
        }
        return;
      }

      final profiles = await supabase
          .from('profiles')
          .select('''
            *,
            kosts:kost_id (
              name,
              price
            )
          ''')
          .inFilter('kost_id', kostIds);

      final payments = await supabase
          .from('payments')
          .select('*')
          .eq('month', now.month)
          .eq('year', now.year)
          .inFilter('kost_id', kostIds)
          .order('created_at', ascending: false);

      final Map<String, Map<String, dynamic>> paymentByTenant = {};
      for (final rawPayment in payments as List) {
        final payment = Map<String, dynamic>.from(rawPayment as Map);
        final tenantId = (payment['tenant_id'] ?? payment['profile_id'])
            ?.toString();
        if (tenantId == null ||
            tenantId.isEmpty ||
            paymentByTenant.containsKey(tenantId)) {
          continue;
        }
        paymentByTenant[tenantId] = payment;
      }

      final List<Map<String, dynamic>> enriched = [];
      for (final rawProfile in profiles as List) {
        final profile = Map<String, dynamic>.from(rawProfile as Map);
        final tenantId = profile['id']?.toString();
        if (tenantId == null || tenantId.isEmpty) continue;

        final payment = paymentByTenant[tenantId];
        if (!_shouldShowLatePaymentReminder(profile, payment, now)) continue;

        final dueDate = _tenantDueDate(profile, now);
        if (dueDate == null) continue;

        final kost = profile['kosts'];
        final email = profile['email']?.toString().trim();

        enriched.add({
          if (payment != null) ...payment,
          'tenant_id': tenantId,
          'tenant_name': _tenantDisplayName(profile),
          'tenant_email': email ?? '-',
          'tenant_phone': profile['phone_number'] ?? '-',
          'kost_id': profile['kost_id'],
          'kost_name': kost is Map && kost['name'] != null
              ? kost['name'].toString()
              : 'Unit Kost',
          'amount':
              payment?['amount'] ??
              (kost is Map ? (kost['price'] as num?)?.toInt() : 0) ??
              0,
          'month': now.month,
          'year': now.year,
          'due_date': dueDate.toIso8601String(),
          'late_days': _dateOnly(now).difference(dueDate).inDays,
          'payment_status': payment?['status'],
        });
      }

      enriched.sort((a, b) {
        final lateCompare = ((b['late_days'] as num?)?.toInt() ?? 0).compareTo(
          (a['late_days'] as num?)?.toInt() ?? 0,
        );
        if (lateCompare != 0) return lateCompare;
        return (a['tenant_name']?.toString() ?? '').compareTo(
          b['tenant_name']?.toString() ?? '',
        );
      });

      if (mounted) {
        setState(() {
          paymentNotifications = enriched;
          isLoadingPayments = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          paymentNotifications = [];
          isLoadingPayments = false;
        });
      }
    }
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  bool _isPaidOrPending(String? status) {
    if (status == null || status.isEmpty) return false;
    return status == 'pending' ||
        status == 'approved' ||
        status == 'success' ||
        status == 'paid';
  }

  DateTime? _tenantDueDate(Map<String, dynamic> tenant, DateTime reference) {
    final raw = _resolveTenantJoinDateRaw(tenant);
    if (raw == null) return null;

    final parsed = DateTime.tryParse(raw.toString());
    if (parsed == null) return null;

    final day = parsed.toLocal().day;
    final lastDay = DateUtils.getDaysInMonth(reference.year, reference.month);
    final dueDay = day > lastDay ? lastDay : day;
    return DateTime(reference.year, reference.month, dueDay);
  }

  dynamic _resolveTenantJoinDateRaw(Map<String, dynamic> tenant) {
    for (final key in const [
      'kost_joined_at',
      'entry_date',
      'join_date',
      'move_in_date',
      'created_at',
    ]) {
      final value = tenant[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  String _tenantDisplayName(Map<String, dynamic> tenant) {
    final fullName = tenant['full_name']?.toString().trim();
    if (fullName != null && fullName.isNotEmpty) return fullName;

    final email = tenant['email']?.toString().trim();
    if (email != null && email.isNotEmpty) {
      return email.split('@').first;
    }

    return 'Penghuni';
  }

  bool _shouldShowLatePaymentReminder(
    Map<String, dynamic> tenant,
    Map<String, dynamic>? payment,
    DateTime now,
  ) {
    final dueDate = _tenantDueDate(tenant, now);
    if (dueDate == null) return false;
    if (!_dateOnly(now).isAfter(dueDate)) return false;

    final status = payment?['status']?.toString().toLowerCase();
    return !_isPaidOrPending(status);
  }

  String _latePaymentDueLabel(Map<String, dynamic> payment) {
    final raw = payment['due_date'];
    if (raw == null) return '-';

    final parsed = DateTime.tryParse(raw.toString());
    if (parsed == null) return '-';

    return DateFormat('dd MMM yyyy', 'id_ID').format(parsed.toLocal());
  }

  String _latePaymentAgeLabel(Map<String, dynamic> payment) {
    final lateDays = (payment['late_days'] as num?)?.toInt() ?? 0;
    if (lateDays <= 0) return 'Jatuh tempo hari ini';
    if (lateDays == 1) return 'Terlambat 1 hari';
    return 'Terlambat $lateDays hari';
  }

  String _latePaymentDescription(Map<String, dynamic> payment) {
    final status = payment['payment_status']?.toString().toLowerCase();
    if (status == 'rejected') {
      return 'Pembayaran sebelumnya ditolak dan belum ada pengajuan ulang.';
    }

    return 'Belum ada pembayaran yang masuk setelah melewati jatuh tempo.';
  }

  Future<void> sendReminder() async {
    // 1. Validasi Form Kosong
    if (_titleCtrl.text.trim().isEmpty || _msgCtrl.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Text(
                  "Judul dan isi pesan tidak boleh kosong!",
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orange.shade800,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
      return; // Berhenti di sini jika kosong
    }

    // 2. Validasi Kost Belum Dipilih
    if (selectedKostId == null || selectedKostId!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Silakan pilih kost tujuan terlebih dahulu"),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // --- LOGIKA PENGECEKAN ACC ---
    final selectedKost = myKosts.firstWhere(
      (k) => k['id'].toString() == selectedKostId,
      orElse: () => null,
    );

    if (selectedKost == null || selectedKost['is_approved'] != true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Kost belum disetujui (ACC). Reminder tidak dapat dikirim.",
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // Jalankan pengiriman jika semua validasi lolos
    setState(() => isSending = true);

    try {
      final ownerId = supabase.auth.currentUser?.id;
      if (ownerId == null) throw Exception("User belum login");

      final title = _titleCtrl.text.trim();
      final text = _msgCtrl.text.trim();
      final packedText = _packTitleAndMessage(title, text, selectedKostId!);
      final nowIso = DateTime.now().toIso8601String();

      // Gunakan payload utama saja untuk efisiensi
      await supabase.from('reminders').insert({
        'owner_id': ownerId,
        'kost_id': selectedKostId,
        'message': packedText,
        'created_at': nowIso,
      });

      _titleCtrl.clear();
      _msgCtrl.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Reminder berhasil dikirim ke penghuni"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      fetchReminders();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal kirim: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isSending = false);
    }
  }

  Future<void> _sendLatePaymentReminder(Map<String, dynamic> payment) async {
    final ownerId = supabase.auth.currentUser?.id;
    final kostId = payment['kost_id']?.toString();
    final tenantId = payment['tenant_id']?.toString();

    if (ownerId == null || kostId == null || tenantId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data reminder tidak lengkap.')),
        );
      }
      return;
    }

    if (mounted) {
      setState(() => activeLateReminderTenantId = tenantId);
    }

    try {
      final title = 'Pengingat Pembayaran Kost';
      final text =
          'Halo ${payment['tenant_name']}, pembayaran kost untuk '
          '${_paymentPeriodLabel(payment)} sudah melewati jatuh tempo '
          '${_latePaymentDueLabel(payment)}. Mohon segera melakukan pembayaran '
          'sebesar ${currency.format(payment['amount'] ?? 0)}.';
      final packedText = _packTitleAndMessage(
        title,
        text,
        kostId,
        tenantId: tenantId,
      );

      await supabase.from('reminders').insert({
        'owner_id': ownerId,
        'kost_id': kostId,
        'message': packedText,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Reminder berhasil dikirim ke ${payment['tenant_name']}.',
            ),
          ),
        );
      }

      await fetchReminders();
      await fetchPaymentNotifications();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal kirim reminder: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => activeLateReminderTenantId = null);
      }
    }
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
      if (parsed != null && parsed['title']!.trim().isNotEmpty)
        return parsed['title']!;
    }
    final dynamic pesan = r['pesan'];
    if (pesan is String && pesan.trim().isNotEmpty) {
      final parsed = _parsePackedMessage(pesan);
      if (parsed != null && parsed['title']!.trim().isNotEmpty)
        return parsed['title']!;
    }
    return 'Reminder';
  }

  String _formatReminderTime(Map r) {
    final dynamic raw = r['reminder_at'] ?? r['waktu'] ?? r['created_at'];
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

  String _paymentPeriodLabel(Map payment) {
    final month = payment['month'];
    final year = payment['year'];
    if (month is int && year is int) {
      return DateFormat('MMMM yyyy', 'id_ID').format(DateTime(year, month));
    }
    return 'bulan ini';
  }

  String _paymentTimeLabel(Map payment) {
    final raw = payment['created_at'] ?? payment['updated_at'];
    if (raw == null) return '--';

    final parsed = DateTime.tryParse(raw.toString());
    if (parsed == null) return '--';

    final local = parsed.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDay = DateTime(local.year, local.month, local.day);
    final dayDiff = today.difference(targetDay).inDays;

    if (dayDiff <= 0) return DateFormat('HH:mm').format(local);
    if (dayDiff == 1) return 'Kemarin';
    return DateFormat('dd/MM/yy').format(local);
  }

  Future<void> _deleteReminder(Map r) async {
    try {
      bool deleted = false;

      if (r['id'] != null) {
        await supabase.from('reminders').delete().eq('id', r['id']);
        deleted = true;
      }

      if (!deleted) {
        final ownerId = supabase.auth.currentUser?.id;
        final createdAt = r['created_at'];
        if (ownerId != null && createdAt != null) {
          try {
            await supabase
                .from('reminders')
                .delete()
                .eq('owner_id', ownerId)
                .eq('created_at', createdAt);
            deleted = true;
          } catch (_) {
            await supabase
                .from('reminders')
                .delete()
                .eq('user_id', ownerId)
                .eq('created_at', createdAt);
            deleted = true;
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Reminder berhasil dihapus")),
        );
      }
      fetchReminders();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Gagal hapus reminder: $e")));
      }
    }
  }

  Future<void> _confirmDeleteReminder(Map r) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        contentPadding: EdgeInsets.zero,
        content: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBF7),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE9D7C2)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF5A3A17).withOpacity(0.14),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFFE7E8), Color(0xFFFFD4D7)],
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Color(0xFFE24D56),
                      child: Icon(
                        Icons.delete_outline,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      "Hapus Reminder",
                      style: GoogleFonts.sora(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF2D241A),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(18, 18, 18, 6),
                child: Text(
                  "Yakin ingin menghapus reminder ini?",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    color: const Color(0xFF4B4339),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF7B6A56),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(
                        "Batal",
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF7B6A56),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE24D56),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 11,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(
                        "Hapus",
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
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

    if (ok == true) {
      await _deleteReminder(r);
    }
  }

  String _packTitleAndMessage(
    String title,
    String message,
    String kostId, {
    String? tenantId,
  }) {
    final tenantChunk = tenantId != null && tenantId.isNotEmpty
        ? '$_tenantPrefix$tenantId'
        : '';
    return '$_kostPrefix$kostId$tenantChunk$_titlePrefix$title$_bodyPrefix$message';
  }

  Map<String, String>? _parsePackedMessage(String raw) {
    if (!raw.contains(_titlePrefix) || !raw.contains(_bodyPrefix)) return null;

    String? kostId;
    String? tenantId;
    final titleIndex = raw.indexOf(_titlePrefix);
    final bodyIndex = raw.indexOf(_bodyPrefix);
    if (titleIndex < 0 || bodyIndex < 0 || bodyIndex <= titleIndex) return null;

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

  Widget _buildPaymentNotificationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                "Pembayaran Terlambat",
                style: GoogleFonts.sora(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF2D241A),
                ),
              ),
            ),
            if (paymentNotifications.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE7C8),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  "${paymentNotifications.length} tenant",
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF9C5A1A),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (isLoadingPayments)
          const Center(
            child: CircularProgressIndicator(color: Color(0xFF9C5A1A)),
          )
        else if (paymentNotifications.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFCF7),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFEADBC9)),
            ),
            child: Text(
              "Belum ada tenant yang telat bayar lewat jatuh tempo bulan ini.",
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF6B6257),
                height: 1.45,
              ),
            ),
          )
        else
          ...paymentNotifications.map(
            (rawPayment) => _buildPaymentNotificationCard(
              Map<String, dynamic>.from(rawPayment as Map),
            ),
          ),
      ],
    );
  }

  Widget _buildPaymentNotificationCard(Map<String, dynamic> payment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEADBC9)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5A3A17).withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE7C8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.notifications_active_rounded,
                  color: Color(0xFF9C5A1A),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payment['tenant_name']?.toString() ?? 'Penghuni',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF2D241A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${payment['kost_name']} • ${_paymentPeriodLabel(payment)}",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: const Color(0xFF6B6257),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _latePaymentDescription(payment),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: const Color(0xFF5A5043),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _latePaymentAgeLabel(payment),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF7A6A58),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F0E4),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.event_busy_rounded,
                  color: Color(0xFF9C5A1A),
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Jatuh tempo",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: const Color(0xFF6B6257),
                    ),
                  ),
                ),
                Text(
                  _latePaymentDueLabel(payment),
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF2D241A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: activeLateReminderTenantId != null
                  ? null
                  : () => _sendLatePaymentReminder(payment),
              icon: const Icon(Icons.notifications_active_rounded, size: 18),
              label: Text(
                activeLateReminderTenantId == payment['tenant_id']?.toString()
                    ? "Mengirim..."
                    : "Kirim Notifikasi",
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9C5A1A),
                foregroundColor: Colors.white,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2E8DA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshPage,
          color: const Color(0xFF9C5A1A),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                "Kirim Reminder",
                style: GoogleFonts.sora(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF2D241A),
                ),
              ),
              const SizedBox(height: 18),
              _buildPaymentNotificationSection(),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFCF7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFEADBC9)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF5A3A17).withOpacity(0.07),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _titleCtrl,
                      decoration: InputDecoration(
                        labelText: "Judul Reminder",
                        labelStyle: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF6F6256),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8F0E4),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _msgCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: "Isi Pesan",
                        labelStyle: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF6F6256),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8F0E4),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F0E4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedKostId,
                          isExpanded: true,
                          hint: Text(
                            "Pilih Kost Tujuan",
                            style: GoogleFonts.plusJakartaSans(),
                          ),
                          items: myKosts.map((k) {
                            bool isApproved = k['is_approved'] == true;
                            return DropdownMenuItem<String>(
                              value: k['id'].toString(),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      k['name']?.toString() ?? 'Kost',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: isApproved
                                            ? const Color(0xFF2D241A)
                                            : Colors.grey,
                                      ),
                                    ),
                                  ),
                                  if (!isApproved)
                                    const Icon(
                                      Icons.lock_clock,
                                      size: 16,
                                      color: Colors.orange,
                                    ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (value) =>
                              setState(() => selectedKostId = value),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9C5A1A),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      onPressed: isSending ? null : sendReminder,
                      child: Text(
                        isSending ? "MENGIRIM..." : "KIRIM REMINDER",
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              Text(
                "Reminder Tersimpan",
                style: GoogleFonts.sora(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF2D241A),
                ),
              ),
              const SizedBox(height: 10),
              if (isLoadingReminders)
                const Center(
                  child: CircularProgressIndicator(color: Color(0xFF9C5A1A)),
                )
              else if (reminders.isEmpty)
                Center(
                  child: Text(
                    "Belum ada reminder",
                    style: GoogleFonts.plusJakartaSans(),
                  ),
                )
              else
                ...reminders.map(
                  (r) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFCF7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFEADBC9)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF5A3A17).withOpacity(0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFE7C8),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.notifications_active,
                              color: Color(0xFF9C5A1A),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Stack(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(right: 86),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _reminderTitle(r),
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF2D241A),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        _reminderText(r),
                                        style: GoogleFonts.plusJakartaSans(
                                          color: const Color(0xFF5A5043),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: PopupMenuButton<String>(
                                    tooltip: "Opsi reminder",
                                    position: PopupMenuPosition.under,
                                    offset: const Offset(0, 6),
                                    elevation: 8,
                                    padding: EdgeInsets.zero,
                                    color: const Color(0xFFFFFBF7),
                                    surfaceTintColor: Colors.transparent,
                                    constraints: const BoxConstraints(
                                      minWidth: 170,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: SizedBox(
                                      width: 72,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            _formatReminderTime(r),
                                            maxLines: 1,
                                            softWrap: false,
                                            overflow: TextOverflow.visible,
                                            textAlign: TextAlign.right,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF7A6A58),
                                            ),
                                          ),
                                          const SizedBox(height: 1),
                                          const Icon(
                                            Icons.keyboard_arrow_down,
                                            size: 16,
                                            color: Color(0xFF7A6A58),
                                          ),
                                        ],
                                      ),
                                    ),
                                    onSelected: (value) {
                                      if (value == 'delete') {
                                        _confirmDeleteReminder(r);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      PopupMenuItem<String>(
                                        value: 'delete',
                                        height: 42,
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.delete_outline,
                                              color: Color(0xFFE24D56),
                                              size: 20,
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              "Hapus reminder",
                                              style:
                                                  GoogleFonts.plusJakartaSans(
                                                    color: const Color(
                                                      0xFF2D241A,
                                                    ),
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
