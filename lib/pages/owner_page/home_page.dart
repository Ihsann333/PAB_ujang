import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:kostly_pa/services/supabase_service.dart';

class OwnerHomePage extends StatefulWidget {
  const OwnerHomePage({super.key});

  @override
  State<OwnerHomePage> createState() => _OwnerHomePageState();
}

class _OwnerHomePageState extends State<OwnerHomePage> {
  final supabase = SupabaseService.client;
  final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  bool isLoading = true;
  bool isLoadingPayments = true;
  int totalKos = 0;
  int totalPenghuni = 0;
  int totalProfit = 0;
  List kosList = [];
  List paymentRequests = [];
  List allTenants = [];
  bool showTenantList = false;

  late TextEditingController _nameCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _rulesCtrl;
  late TextEditingController _addressCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _priceCtrl = TextEditingController();
    _rulesCtrl = TextEditingController();
    _addressCtrl = TextEditingController();
    refreshAllData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _rulesCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> refreshAllData() async {
    setState(() => isLoading = true);
    await fetchDashboard();
    await fetchPaymentRequests();
    setState(() => isLoading = false);
  }

  // --- LOGIKA DATA ---
  Future<void> fetchDashboard() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final kosResponse = await supabase
          .from('kosts')
          .select()
          .eq('owner_id', userId)
          .order('created_at', ascending: false);

      final List kos = kosResponse as List;
      final List<Future<dynamic>> penghuniFutures = kos.map((k) {
        return supabase.from('profiles').select().eq('kost_id', k['id']);
      }).toList();

      final results = await Future.wait(penghuniFutures);

      int penghuniCount = 0;
      int profit = 0;
      final List<Map<String, dynamic>> kosWithStats = [];

      for (int i = 0; i < results.length; i++) {
        final List tenantsInKos = results[i] as List;
        final int harga = (kos[i]['price'] as num?)?.toInt() ?? 0;
        final int activeTenants = tenantsInKos.length;
        bool isApproved = kos[i]['is_approved'] == true;
        
        final int monthlyProfit = isApproved ? (harga * activeTenants) : 0;

        final Map<String, dynamic> currentKos = Map<String, dynamic>.from(kos[i] as Map);
        currentKos['active_tenants'] = activeTenants;
        currentKos['monthly_profit'] = monthlyProfit;
        
        kosWithStats.add(currentKos); 

        if (isApproved) {
          penghuniCount += activeTenants;
          profit += monthlyProfit;
        }
      }

      if (mounted) {
        setState(() {
          kosList = kosWithStats;
          totalKos = kos.length; 
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

      final List myKosts = await supabase.from('kosts').select('id').eq('owner_id', userId);
      final kostIds = myKosts.map((item) => item['id']).toList();
      
      if (kostIds.isEmpty) {
        setState(() => isLoadingPayments = false);
        return;
      }

      final results = await Future.wait([
        supabase.from('profiles')
            .select('id, full_name, kost_id, kosts(name)')
            .inFilter('kost_id', kostIds),
        supabase.from('payments')
            .select('*')
            .eq('month', now.month)
            .eq('year', now.year)
            .inFilter('kost_id', kostIds)
      ]);

      if (mounted) {
        setState(() {
          allTenants = results[0] as List;
          paymentRequests = results[1] as List;
          isLoadingPayments = false;
        });
      }
    } catch (e) {
      setState(() => isLoadingPayments = false);
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
          const SnackBar(content: Text("Pembayaran Berhasil di-ACC!"), backgroundColor: Colors.green)
        );
        refreshAllData(); 
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal: $e"), backgroundColor: Colors.red));
    }
  }

  // --- UI COMPONENTS ---
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
              Text(
                "Management Kostly",
                style: GoogleFonts.sora(fontSize: 24, fontWeight: FontWeight.w800, color: const Color(0xFF2D241A)),
              ),
              const SizedBox(height: 20),
              
              // Kartu Statistik Klik (PENGGANTI TAB ACC)
              _buildStatCards(),
              
              const SizedBox(height: 12),
              _profitCard(currency.format(totalProfit)),

              // LIST DETAIL PENGHUNI (Muncul jika Stat diklik)
              _buildCombinedTenantList(),

              const SizedBox(height: 32),
              Text(
                "Daftar Unit Kost",
                style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF2D241A)),
              ),
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
        Expanded(
          child: _buildClickableStatCard(
            icon: Icons.domain_rounded,
            count: totalKos.toString(),
            label: "Total Kost",
            onTap: () => setState(() => showTenantList = !showTenantList),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildClickableStatCard(
            icon: Icons.people_alt_rounded,
            count: totalPenghuni.toString(),
            label: "Penghuni",
            onTap: () => setState(() => showTenantList = !showTenantList),
          ),
        ),
      ],
    );
  }

  Widget _buildClickableStatCard({required IconData icon, required String count, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
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
            Text(count, style: GoogleFonts.sora(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
            Text(label, style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildCombinedTenantList() {
    if (!showTenantList) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 25),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Detail Status Penghuni", style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.bold)),
            IconButton(onPressed: () => setState(() => showTenantList = false), icon: const Icon(Icons.close, size: 20))
          ],
        ),
        if (allTenants.isEmpty)
          const Padding(padding: EdgeInsets.all(20), child: Center(child: Text("Belum ada penghuni aktif.")))
        else
          ...allTenants.map((tenant) {
            final payment = paymentRequests.firstWhere(
              (p) => p['tenant_id']?.toString() == tenant['id']?.toString() || p['profile_id']?.toString() == tenant['id']?.toString(),
              orElse: () => {},
            );

            final String status = (payment['status'] ?? 'belum').toString().toLowerCase();
            final bool isPending = status == 'pending';
            final bool isPaid = status == 'success' || status == 'approved';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isPending ? Colors.orange.shade200 : Colors.grey.shade200),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: isPaid ? Colors.green.shade50 : (isPending ? Colors.orange.shade50 : Colors.red.shade50),
                        child: Icon(
                          isPaid ? Icons.check_circle : (isPending ? Icons.hourglass_top : Icons.warning_amber),
                          color: isPaid ? Colors.green : (isPending ? Colors.orange : Colors.red),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tenant['full_name'] ?? 'Penghuni', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
                            Text("Kost: ${tenant['kosts']?['name'] ?? '-'}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                      _statusBadge(
                        isPaid ? "LUNAS" : (isPending ? "WAITING ACC" : "BELUM BAYAR"),
                        isPaid ? Colors.green : (isPending ? Colors.orange : Colors.red)
                      ),
                    ],
                  ),
                  if (isPending) ...[
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Nominal: ${currency.format(payment['amount'] ?? 0)}", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        ElevatedButton(
                          onPressed: () => _approvePayment(payment['id']),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green, 
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            minimumSize: const Size(0, 36),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                          ),
                          child: const Text("ACC Bayar", style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
      ],
    );
  }

  Widget _profitCard(String profit) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF2D241A), borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet_rounded, color: Colors.amber, size: 32),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Estimasi Profit Bulan Ini", style: GoogleFonts.plusJakartaSans(color: Colors.white60, fontSize: 12)),
              Text(profit, style: GoogleFonts.sora(fontSize: 24, color: Colors.white, fontWeight: FontWeight.w800)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kosCard(Map kos) {
    final int activeTenants = (kos['active_tenants'] as num?)?.toInt() ?? 0;
    final int totalKamar = (kos['slots'] as num?)?.toInt() ?? 0;
    final bool isApproved = kos['is_approved'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEADBC9).withOpacity(0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        onTap: () => _showDetailDialog(kos),
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: isApproved ? const Color(0xFF9C5A1A) : Colors.grey.shade300, 
          child: Icon(Icons.home_rounded, color: isApproved ? Colors.white : Colors.grey.shade600)
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                kos['name'] ?? '-',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 16, color: const Color(0xFF2D241A)),
              ),
            ),
            if (!isApproved) _statusBadge("PENDING", Colors.orange),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(currency.format(kos['price'] ?? 0), style: GoogleFonts.plusJakartaSans(color: const Color(0xFF9C5A1A), fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                _miniInfo(Icons.meeting_room_rounded, "$totalKamar Kamar"),
                const SizedBox(width: 12),
                _miniInfo(Icons.person_pin_circle_rounded, "$activeTenants Penghuni"),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
      ),
    );
  }

  Widget _statusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.5))),
      child: Text(text, style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
    );
  }

  Widget _miniInfo(IconData icon, String label) {
    return Row(children: [Icon(icon, size: 14, color: Colors.grey), const SizedBox(width: 4), Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey.shade600))]);
  }

  void _showDetailDialog(Map kos) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFFFBF7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(kos['name'] ?? 'Detail Kost', style: GoogleFonts.sora(fontWeight: FontWeight.w800, color: const Color(0xFF9C5A1A))),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (kos['is_approved'] != true) _buildPendingAlert(),
                _buildJoinCodeSection(kos),
                const SizedBox(height: 20),
                _buildPopupDetail(Icons.location_on_rounded, "Alamat", kos['address']),
                _buildPopupDetail(Icons.payments_rounded, "Harga Sewa", currency.format(kos['price'] ?? 0)),
                const Divider(height: 32),
                Row(children: [const Icon(Icons.people_alt_rounded, size: 18, color: Color(0xFF9C5A1A)), const SizedBox(width: 8), Text("Penghuni Unit Ini", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800))]),
                const SizedBox(height: 12),
                _buildLiveTenantList(kos['id']),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Tutup")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9C5A1A), foregroundColor: Colors.white),
            onPressed: () { Navigator.pop(context); _showEditDialog(kos); },
            child: const Text("Edit Data"),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(Map kos) {
    _nameCtrl.text = kos['name'] ?? '';
    _priceCtrl.text = (kos['price'] ?? 0).toString();
    _rulesCtrl.text = kos['rules'] ?? '';
    _addressCtrl.text = kos['address'] ?? '';
    bool editListrik = kos['include_electricity'] == true;
    bool editAir = kos['include_water'] == true;
    bool editWifi = kos['include_wifi'] == true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("Edit Unit", style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildEditField(_nameCtrl, "Nama Kost", Icons.home),
                _buildEditField(_priceCtrl, "Harga", Icons.payments, isNumber: true),
                _buildEditToggle("Include Listrik", editListrik, (v) => setModalState(() => editListrik = v)),
                _buildEditToggle("Include Air", editAir, (v) => setModalState(() => editAir = v)),
                _buildEditToggle("Include WiFi", editWifi, (v) => setModalState(() => editWifi = v)),
                _buildEditField(_rulesCtrl, "Peraturan", Icons.gavel, maxLines: 2),
                _buildEditField(_addressCtrl, "Alamat", Icons.location_on, maxLines: 2),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
            ElevatedButton(onPressed: () => _updateKost(kos, editListrik, editAir, editWifi), child: const Text("Simpan")),
          ],
        ),
      ),
    );
  }

  Future<void> _updateKost(Map oldData, bool newListrik, bool newAir, bool newWifi) async {
    try {
      await supabase.from('kosts').update({
        'name': _nameCtrl.text.trim(),
        'price': int.tryParse(_priceCtrl.text) ?? 0,
        'rules': _rulesCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'include_electricity': newListrik,
        'include_water': newAir,
        'include_wifi': newWifi,
      }).eq('id', oldData['id']);
      Navigator.pop(context);
      refreshAllData();
    } catch (e) {
      debugPrint("Update Error: $e");
    }
  }

  // --- WIDGET HELPERS ---
  Widget _buildEditField(TextEditingController ctrl, String label, IconData icon, {bool isNumber = false, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF9C5A1A), size: 20),
          filled: true, fillColor: const Color(0xFFF5F0EA),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildEditToggle(String label, bool value, Function(bool) onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14)),
        Switch(value: value, onChanged: onChanged, activeColor: const Color(0xFF9C5A1A)),
      ],
    );
  }

  Widget _buildLiveTenantList(dynamic kostId) {
    return FutureBuilder(
      future: supabase.from('profiles').select('full_name').eq('kost_id', kostId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const LinearProgressIndicator();
        final List data = snapshot.data as List? ?? [];
        if (data.isEmpty) return const Text("Kosong.");
        return Column(
          children: data.map((t) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [const Icon(Icons.check_circle, size: 14, color: Colors.green), const SizedBox(width: 10), Text(t['full_name'] ?? '-')]),
          )).toList(),
        );
      },
    );
  }

  Widget _buildJoinCodeSection(Map kos) {
    bool isApproved = kos['is_approved'] == true;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(color: isApproved ? const Color(0xFF9C5A1A) : Colors.amber.shade100, borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        const Text("KODE MASUK", style: TextStyle(fontSize: 10, color: Colors.white70)),
        Text(isApproved ? (kos['join_code'] ?? "-") : "WAITING", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
      ]),
    );
  }

  Widget _buildPendingAlert() => Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)), child: const Text("Menunggu verifikasi admin.", style: TextStyle(color: Colors.orange, fontSize: 12)));
  Widget _buildPopupDetail(IconData icon, String label, String? value) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)), Text(value ?? '-', style: const TextStyle(fontWeight: FontWeight.bold))]));
}