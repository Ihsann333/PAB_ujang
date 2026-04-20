import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:kostly_pa/services/supabase_service.dart';

// --- BAGIAN INTEGRASI: HALAMAN OWNER HOME ---

class OwnerHomePage extends StatefulWidget {
  const OwnerHomePage({super.key});

  @override
  State<OwnerHomePage> createState() => _OwnerHomePageState();
}

class _OwnerHomePageState extends State<OwnerHomePage> {
  static const String _kostPrefix = '[KOSTLY_KOST]';
  static const String _tenantPrefix = '[KOSTLY_TENANT]';
  static const String _titlePrefix = '[KOSTLY_TITLE]';
  static const String _bodyPrefix = '[KOSTLY_BODY]';

  final supabase = SupabaseService.client;
  final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  bool isLoading = true;
  int totalKos = 0;
  int totalPenghuni = 0;
  int totalProfit = 0;
  List kosList = [];
  List paymentRequests = [];
  List latePaymentNotifications = [];
  List allTenants = [];
  bool showTenantList = false;

  @override
  void initState() {
    super.initState();
    refreshAllData();
  }

  Future<void> refreshAllData() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    await fetchDashboard();
    await fetchPaymentRequests();
    if (mounted) setState(() => isLoading = false);
  }

  Future<void> fetchDashboard() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final kosRes = await supabase
          .from('kosts')
          .select()
          .eq('owner_id', userId)
          .order('created_at', ascending: false);

      final List fetchedKosts = kosRes as List;
      int penghuniCount = 0;
      int profit = 0;
      final List<Map<String, dynamic>> tempKosList = [];

      for (var k in fetchedKosts) {
        final profilesRes = await supabase.from('profiles').select().eq('kost_id', k['id']);
        final int activeTenants = (profilesRes as List).length;
        final bool isApproved = k['is_approved'] == true;
        
        final int harga = (k['price'] as num?)?.toInt() ?? 0;
        final int monthlyProfit = isApproved ? (harga * activeTenants) : 0;

        final Map<String, dynamic> currentKos = Map<String, dynamic>.from(k as Map);
        currentKos['active_tenants'] = activeTenants;
        
        tempKosList.add(currentKos); 

        if (isApproved) {
          penghuniCount += activeTenants;
          profit += monthlyProfit;
        }
      }

      if (mounted) {
        setState(() {
          kosList = tempKosList;
          totalKos = fetchedKosts.length; 
          totalPenghuni = penghuniCount;
          totalProfit = profit;
        });
      }
    } catch (e) {
      debugPrint("Error Dashboard: $e");
    }
  }

  Future<void> fetchPaymentRequests() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final now = DateTime.now();

      final List myKosts = await supabase
          .from('kosts')
          .select('id,name,price')
          .eq('owner_id', userId);
      final List kostIds = myKosts.map((item) => item['id']).toList();
      
      if (kostIds.isEmpty) {
        debugPrint("Owner tidak punya unit kost.");
        if (mounted) {
          setState(() {
            allTenants = [];
            paymentRequests = [];
            latePaymentNotifications = [];
          });
        }
        return;
      }

      final profiles = await supabase
          .from('profiles')
          .select('''
            id,
            full_name,
            email,
            phone_number,
            created_at,
            kost_id,
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
        final tenantId =
            (payment['tenant_id'] ?? payment['profile_id'])?.toString();
        if (tenantId == null ||
            tenantId.isEmpty ||
            paymentByTenant.containsKey(tenantId)) {
          continue;
        }
        paymentByTenant[tenantId] = payment;
      }

      final List<Map<String, dynamic>> lateNotifications = [];
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

        lateNotifications.add({
          if (payment != null) ...payment,
          'tenant_id': tenantId,
          'tenant_name': _tenantDisplayName(profile),
          'tenant_email': email ?? '-',
          'kost_id': profile['kost_id'],
          'kost_name': kost is Map && kost['name'] != null
              ? kost['name'].toString()
              : 'Unit Kost',
          'amount': payment?['amount'] ??
              (kost is Map ? (kost['price'] as num?)?.toInt() : 0) ??
              0,
          'month': now.month,
          'year': now.year,
          'due_date': dueDate.toIso8601String(),
          'late_days': _dateOnly(now).difference(dueDate).inDays,
          'payment_status': payment?['status'],
        });
      }

      lateNotifications.sort((a, b) {
        final lateCompare =
            ((b['late_days'] as num?)?.toInt() ?? 0).compareTo(
          (a['late_days'] as num?)?.toInt() ?? 0,
        );
        if (lateCompare != 0) return lateCompare;
        return (a['tenant_name']?.toString() ?? '').compareTo(
          b['tenant_name']?.toString() ?? '',
        );
      });

      debugPrint("Tenants Found: ${profiles.length}");

      if (mounted) {
        setState(() {
          allTenants = profiles as List;
          paymentRequests = payments as List;
          latePaymentNotifications = lateNotifications;
        });
      }
    } catch (e) {
      debugPrint("Error detail: $e");
    }
  }

  Future<void> _approvePayment(dynamic paymentId) async {
    try {
      await supabase.from('payments').update({
        'status': 'success',
        'paid_at': DateTime.now().toIso8601String(),
      }).eq('id', paymentId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pembayaran berhasil di-ACC.')),
        );
      }

      await refreshAllData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal ACC pembayaran: $e')),
        );
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
    final raw = tenant['created_at'];
    if (raw == null) return null;

    final parsed = DateTime.tryParse(raw.toString());
    if (parsed == null) return null;

    final day = parsed.toLocal().day;
    final lastDay = DateUtils.getDaysInMonth(reference.year, reference.month);
    final dueDay = day > lastDay ? lastDay : day;
    return DateTime(reference.year, reference.month, dueDay);
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

  String _paymentPeriodLabel(Map payment) {
    final month = payment['month'];
    final year = payment['year'];
    if (month is int && year is int) {
      return DateFormat('MMMM yyyy', 'id_ID').format(DateTime(year, month));
    }
    return 'bulan ini';
  }

  String _latePaymentDueLabel(Map payment) {
    final raw = payment['due_date'];
    if (raw == null) return '-';

    final parsed = DateTime.tryParse(raw.toString());
    if (parsed == null) return '-';

    return DateFormat('dd MMM yyyy', 'id_ID').format(parsed.toLocal());
  }

  String _latePaymentAgeLabel(Map payment) {
    final lateDays = (payment['late_days'] as num?)?.toInt() ?? 0;
    if (lateDays <= 0) return 'Jatuh tempo hari ini';
    if (lateDays == 1) return 'Terlambat 1 hari';
    return 'Terlambat $lateDays hari';
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

    try {
      final title = 'Pengingat Pembayaran Kost';
      final message =
          'Halo ${payment['tenant_name']}, pembayaran kost untuk '
          '${_paymentPeriodLabel(payment)} sudah melewati jatuh tempo '
          '${_latePaymentDueLabel(payment)}. Mohon segera melakukan pembayaran '
          'sebesar ${currency.format(payment['amount'] ?? 0)}.';
      final packedText =
          '$_kostPrefix$kostId$_tenantPrefix$tenantId$_titlePrefix$title$_bodyPrefix$message';

      await supabase.from('reminders').insert({
        'owner_id': ownerId,
        'kost_id': kostId,
        'title': title,
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal kirim reminder: $e')),
        );
      }
    }
  }

  Widget _buildPendingPaymentCard() {
    final int pendingCount = latePaymentNotifications.length;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF7),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFEADBC9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE7C8),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.mark_email_unread_rounded,
                  color: Color(0xFF9C5A1A),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Pembayaran Terlambat",
                      style: GoogleFonts.sora(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF2D241A),
                      ),
                    ),
                    Text(
                      pendingCount > 0
                          ? "$pendingCount tenant melewati jatuh tempo"
                          : "Belum ada tenant yang telat bayar",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: const Color(0xFF6B6257),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (pendingCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0D6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$pendingCount',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF9C5A1A),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (pendingCount == 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F0E4),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                "Kalau ada tenant yang belum membayar setelah tanggal jatuh tempo, notifikasinya akan muncul di sini.",
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF6B6257),
                  height: 1.45,
                ),
              ),
            )
          else
            ...latePaymentNotifications.take(3).map((rawPayment) {
              final payment = Map<String, dynamic>.from(rawPayment as Map);
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F0E4),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
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
                                "${payment['kost_name']} - ${_paymentPeriodLabel(payment)}",
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: const Color(0xFF6B6257),
                                ),
                              ),
                            ],
                          ),
                        ),
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
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Jatuh tempo ${_latePaymentDueLabel(payment)}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF6B6257),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                currency.format(payment['amount'] ?? 0),
                                style: GoogleFonts.sora(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF9C5A1A),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => _sendLatePaymentReminder(payment),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF9C5A1A),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Ingatkan',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          if (pendingCount > 3)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                "Masih ada ${pendingCount - 3} pengajuan lainnya. Cek tab Reminder untuk daftar lengkapnya.",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: const Color(0xFF7A6A58),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF9C5A1A))));

    return Scaffold(
      backgroundColor: const Color(0xFFFDFBFA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: refreshAllData,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text("Management", style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.grey)),
              Text("Kostly Owner", style: GoogleFonts.sora(fontSize: 24, fontWeight: FontWeight.w800, color: const Color(0xFF2D241A))),
              const SizedBox(height: 20),
              
              _buildStatCards(),
              const SizedBox(height: 12),
              _profitCard(currency.format(totalProfit)),
              _buildPendingPaymentCard(),

              _buildCombinedTenantList(),

              const SizedBox(height: 32),
              Text("Daftar Unit Kost", style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              ...kosList.map((kos) => _kosCard(kos)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCards() {
    return Row(
      children: [
        _statItem(Icons.domain_rounded, totalKos.toString(), "Total Kost"),
        const SizedBox(width: 12),
        _statItem(Icons.people_alt_rounded, totalPenghuni.toString(), "Penghuni"),
      ],
    );
  }

  Widget _statItem(IconData icon, String val, String label) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            showTenantList = !showTenantList;
          });
          if (showTenantList) {
            debugPrint("Menampilkan List Penghuni");
          }
        },
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF9C5A1A),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: const Color(0xFF9C5A1A).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.white60, size: 24),
              const SizedBox(height: 10),
              Text(val, style: GoogleFonts.sora(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
              Text(label, style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profitCard(String profit) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF2D241A), borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet_rounded, color: Colors.amber, size: 30),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Estimasi Pendapatan", style: GoogleFonts.plusJakartaSans(color: Colors.white60, fontSize: 12)),
              Text(profit, style: GoogleFonts.sora(fontSize: 20, color: Colors.white, fontWeight: FontWeight.w800)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCombinedTenantList() {
    if (!showTenantList || allTenants.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 25),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Detail Status Penghuni", 
              style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.bold)
            ),
            IconButton(
              onPressed: () => setState(() => showTenantList = false), 
              icon: const Icon(Icons.close_rounded)
            )
          ],
        ),
        const SizedBox(height: 10),
        ...allTenants.map((tenant) {
          // Logika pencarian status pembayaran
          final pay = paymentRequests.firstWhere(
            (p) => p['profile_id'] == tenant['id'] || p['tenant_id'] == tenant['id'],
            orElse: () => {},
          );
          
          String status = (pay['status'] ?? 'belum').toString().toLowerCase();
          bool isPending = status == 'pending';
          bool isSuccess = status == 'success' || status == 'approved';

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context, 
                MaterialPageRoute(
                  builder: (context) => DetailPenghuniPage(
                    penghuni: {
                      'name': tenant['full_name'] ?? "Anonim",
                      'email': tenant['email'] ?? "Email tidak tersedia",
                      'payment_status': status,
                      'rent_price': tenant['kosts']?['price'] ?? 0,
                      'entry_date': tenant['created_at'],
                      'phone': tenant['phone_number'] ?? "Belum ada No. HP",
                      'room_number': tenant['room_number'] ?? '-',
                      'nik': tenant['nik'] ?? "Belum terupload",
                    }
                  )
                )
              );
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white, 
                borderRadius: BorderRadius.circular(16), 
                border: Border.all(
                  color: isPending ? Colors.orange : Colors.grey.shade100,
                  width: isPending ? 1.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: const Color(0xFFEADBC9), 
                        child: Text(
                          (tenant['full_name'] ?? "U")[0].toUpperCase(),
                          style: const TextStyle(color: Color(0xFF9C5A1A), fontWeight: FontWeight.bold),
                        )
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start, 
                          children: [
                            Text(
                              tenant['full_name'] ?? "Tanpa Nama", 
                              style: const TextStyle(fontWeight: FontWeight.bold)
                            ),
                            Text(
                              tenant['kosts']?['name'] ?? 'Unit tidak diketahui', 
                              style: const TextStyle(fontSize: 11, color: Colors.grey)
                            ),
                          ]
                        )
                      ),
                      _badge(
                        isSuccess ? "LUNAS" : (isPending ? "PENDING" : "BELUM BAYAR"), 
                        isSuccess ? Colors.green : (isPending ? Colors.orange : Colors.red)
                      ),
                    ],
                  ),
                  // Tampilkan tombol ACC hanya jika status pending
                  if (isPending) ...[
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                      children: [
                        Text(
                          "Nominal: ${currency.format(pay['amount'] ?? 0)}", 
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)
                        ),
                        ElevatedButton(
                          onPressed: () => _approvePayment(pay['id']), 
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green, 
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                          ), 
                          child: const Text("ACC"),
                        ),
                      ]
                    )
                  ]
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _kosCard(Map kos) {
    bool isApproved = kos['is_approved'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFEADBC9).withOpacity(0.5))),
      child: ListTile(
        onTap: () {
          // PINDAH KE DETAIL KOS (MENGGANTI DIALOG)
          Navigator.push(context, MaterialPageRoute(builder: (context) => DetailKosPage(kos: kos)));
        },
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(backgroundColor: isApproved ? const Color(0xFF9C5A1A) : Colors.grey.shade300, child: const Icon(Icons.home_rounded, color: Colors.white)),
        title: Text(kos['name'] ?? '-', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
        subtitle: Text(currency.format(kos['price'] ?? 0), style: const TextStyle(color: Color(0xFF9C5A1A), fontWeight: FontWeight.bold)),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }

  Widget _badge(String t, Color c) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Text(t, style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.bold)));
}

// --- BAGIAN DETAIL PAGES (RE-PASTE DARI SEBELUMNYA) ---

class DetailKosPage extends StatelessWidget {
  final Map kos;
  const DetailKosPage({super.key, required this.kos});

  String formatRupiah(dynamic price) {
    if (price == null) return "0";
    String priceStr = price.toString();
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return priceStr.replaceAllMapped(reg, (Match m) => '${m[1]}.');
  }

  bool cekFasilitas(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    String v = value.toString().toLowerCase();
    return v == "ya" || v == "yes" || v == "true" || v == "1" || v == "tersedia";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250.0,
            pinned: true,
            backgroundColor: const Color(0xFF9C5A1A),
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: Colors.black26,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: const Color(0xFFEADBC8),
                child: const Icon(Icons.apartment_rounded, size: 120, color: Color(0xFF9C5A1A)),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nama & Harga
                  Text(
                    kos['name'] ?? 'Nama Kost',
                    style: GoogleFonts.sora(fontSize: 26, fontWeight: FontWeight.w700, color: const Color(0xFF2D1E12)),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Rp ${formatRupiah(kos['price'])}",
                    style: GoogleFonts.sora(fontSize: 22, color: const Color(0xFF9C5A1A), fontWeight: FontWeight.w700),
                  ),
                  Text("per bulan", style: GoogleFonts.plusJakartaSans(color: Colors.grey, fontSize: 14)),
                  
                  const SizedBox(height: 30),
                  
                  // Fasilitas
                  Text("Fasilitas Utama", style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 15),
                  Wrap(
                    spacing: 15,
                    runSpacing: 15,
                    children: [
                      _buildFasilitasItem(Icons.wifi, "WiFi", cekFasilitas(kos['include_wifi'])),
                      _buildFasilitasItem(Icons.water_drop, "Air", cekFasilitas(kos['include_water'])),
                      _buildFasilitasItem(Icons.bolt, "Listrik", cekFasilitas(kos['include_electricity'])),
                    ],
                  ),

                  const SizedBox(height: 35),

                  Text("Aturan Kos", style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F5F2),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: const Color(0xFFEADBC8)),
                    ),
                    child: Text(
                      kos['rules'] ?? "Hubungi pemilik untuk detail aturan.",
                      style: GoogleFonts.plusJakartaSans(fontSize: 15, color: Colors.brown.shade900, height: 1.6),
                    ),
                  ),

                  const SizedBox(height: 35),

                  // Alamat
                  Text("Lokasi", style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Color(0xFF9C5A1A), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          kos['address'] ?? "Alamat belum diatur",
                          style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.grey.shade700),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFasilitasItem(IconData icon, String label, bool isAvailable) {
    return Container(
      width: 90,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isAvailable ? Colors.white : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isAvailable ? const Color(0xFF9C5A1A).withOpacity(0.2) : Colors.grey.shade200
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: isAvailable ? const Color(0xFF9C5A1A) : Colors.grey, size: 24),
          const SizedBox(height: 6),
          Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w500)),
          Text(
            isAvailable ? "Include" : "N/A",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10, 
              fontWeight: FontWeight.w700, 
              color: isAvailable ? Colors.green : Colors.red
            ),
          ),
        ],
      ),
    );
  }
}

class DetailPenghuniPage extends StatelessWidget {
  final Map penghuni;

  const DetailPenghuniPage({super.key, required this.penghuni});

  // Fungsi pembantu untuk format Rupiah
  String formatRupiah(dynamic price) {
    if (price == null) return "0";
    String priceStr = price.toString();
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return priceStr.replaceAllMapped(reg, (Match m) => '${m[1]}.');
  }

  @override
  Widget build(BuildContext context) {
    String rawStatus = (penghuni['payment_status'] ?? 'belum').toString().toLowerCase();

    // Format tanggal masuk yang aman (agar tidak error jika null)
    String entryDate = "-";
    if (penghuni['entry_date'] != null) {
      entryDate = penghuni['entry_date'].toString().split('T')[0]; // Ambil YYYY-MM-DD
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      body: CustomScrollView(
        slivers: [
          // AppBar Estetik (Sesuai Konsep Detail Kos)
          SliverAppBar(
            expandedHeight: 200.0,
            pinned: true,
            backgroundColor: const Color(0xFF9C5A1A),
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: Colors.black26,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: const Color(0xFFEADBC8),
                child: const Icon(Icons.person_rounded, size: 100, color: Color(0xFF9C5A1A)),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nama & Badge Status Bayar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          penghuni['name'] ?? 'Nama Penghuni',
                          style: GoogleFonts.sora(fontSize: 24, fontWeight: FontWeight.w700, color: const Color(0xFF2D1E12)),
                        ),
                      ),
                      _buildStatusBadge(rawStatus),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // Info Box Utama (Sesuai Konsep Kotak di Detail Kos)
                  Text("Informasi Sewa", style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 15),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildInfoBox(Icons.meeting_room, "Kamar", penghuni['room_number'] ?? "-"),
                      _buildInfoBox(Icons.payments, "Harga", "Rp ${formatRupiah(penghuni['rent_price'])}"),
                      _buildInfoBox(Icons.event_available, "Masuk", entryDate),
                    ],
                  ),

                  const SizedBox(height: 35),

                  // Detail Kontak
                  Text("Data Diri & Kontak", style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 15),
                  _infoRow(Icons.email_outlined, "Email", penghuni['email'] ?? "-"),
                  _infoRow(Icons.phone_android, "WhatsApp / HP", penghuni['phone'] ?? "-"),
                  _infoRow(Icons.badge_outlined, "NIK / KTP", penghuni['nik'] ?? "Belum terupload"),

                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget Badge Status
  Widget _buildStatusBadge(String rawStatus) {
    final bool isLunas = rawStatus == 'success' || rawStatus == 'approved' || rawStatus == 'lunas';
    final bool isPending = rawStatus == 'pending';
    final bool isRejected = rawStatus == 'rejected';
    final Color badgeColor = isLunas
        ? Colors.green
        : isPending
            ? Colors.orange
            : isRejected
                ? Colors.redAccent
                : Colors.red;
    final String label = isLunas
        ? "LUNAS"
        : isPending
            ? "PENDING"
            : isRejected
                ? "DITOLAK"
                : "BELUM BAYAR";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: badgeColor),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: badgeColor,
        ),
      ),
    );
  }

  // Widget Kotak Info (Agar seragam dengan kotak fasilitas di Detail Kos)
  Widget _buildInfoBox(IconData icon, String label, String value) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFEADBC8)),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF9C5A1A), size: 22),
          const SizedBox(height: 6),
          Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 10, color: Colors.grey)),
          Text(
            value,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  // Widget Baris Informasi List
  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF2E8DA),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF9C5A1A), size: 20),
          ),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey)),
              Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          )
        ],
      ),
    );
  }
}
