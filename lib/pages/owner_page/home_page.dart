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
  int totalKos = 0;
  int totalPenghuni = 0;
  int totalProfit = 0;
  List kosList = [];

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
    fetchDashboard();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _rulesCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

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
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // --- UI COMPONENTS ---

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFF9C5A1A)));

    return Scaffold(
      backgroundColor: const Color(0xFFFDFBFA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: fetchDashboard,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                "Dashboard Owner",
                style: GoogleFonts.sora(fontSize: 24, fontWeight: FontWeight.w800, color: const Color(0xFF2D241A)),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _summaryCard("Total Kost", "$totalKos", Icons.home_work_rounded)),
                  const SizedBox(width: 12),
                  Expanded(child: _summaryCard("Penghuni", "$totalPenghuni", Icons.people_alt_rounded)),
                ],
              ),
              const SizedBox(height: 12),
              _profitCard(currency.format(totalProfit)),
              const SizedBox(height: 32),
              Text(
                "Kost Saya",
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

void _showDetailDialog(Map kos) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFFFBF7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(kos['name'] ?? 'Detail Kost', 
          style: GoogleFonts.sora(fontWeight: FontWeight.w800, color: const Color(0xFF9C5A1A))),
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
                
                // --- INFORMASI UTAMA ---
                _buildPopupDetail(Icons.location_on_rounded, "Alamat", kos['address']),
                _buildPopupDetail(Icons.payments_rounded, "Harga Sewa", currency.format(kos['price'] ?? 0)),
                
                // --- BAGIAN FASILITAS (INI YANG TADI HILANG) ---
                const SizedBox(height: 12),
                Text("Fasilitas Include:", 
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: [
                    _buildIncludeChip("Listrik", kos['include_electricity'] == true, Icons.flash_on_rounded),
                    _buildIncludeChip("Air", kos['include_water'] == true, Icons.water_drop_rounded),
                    _buildIncludeChip("WiFi", kos['include_wifi'] == true, Icons.wifi_rounded),
                  ],
                ),

                const Divider(height: 32),
                
                // --- DAFTAR PENGHUNI ---
                Row(children: [
                  const Icon(Icons.people_alt_rounded, size: 18, color: Color(0xFF9C5A1A)), 
                  const SizedBox(width: 8), 
                  Text("Daftar Penghuni Aktif", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800))
                ]),
                const SizedBox(height: 12),
                _buildLiveTenantList(kos['id']),
                
                const Divider(height: 32),
                _buildPopupDetail(Icons.gavel_rounded, "Peraturan", kos['rules']),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Tutup")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9C5A1A), foregroundColor: Colors.white),
            onPressed: () { 
              Navigator.pop(context); 
              _showEditDialog(kos); 
            },
            child: const Text("Edit Data"),
          ),
        ],
      ),
    );
  }

  // --- HELPER WIDGETS ---

  Widget _buildIncludeChip(String label, bool isIncluded, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isIncluded ? const Color(0xFFE8F5E9) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isIncluded ? Colors.green.shade200 : Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isIncluded ? icon : Icons.block_flipped, size: 14, color: isIncluded ? Colors.green.shade700 : Colors.grey),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: isIncluded ? Colors.green.shade800 : Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildLiveTenantList(dynamic kostId) {
    return FutureBuilder(
      future: supabase.from('profiles').select('full_name').eq('kost_id', kostId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const LinearProgressIndicator();
        final List data = snapshot.data as List? ?? [];
        if (data.isEmpty) return Text("Belum ada penghuni.", style: GoogleFonts.plusJakartaSans(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey));
        return Column(
          children: data.map((t) => Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFF0E6D8))),
            child: Row(children: [const Icon(Icons.check_circle, size: 14, color: Colors.green), const SizedBox(width: 10), Text(t['full_name'] ?? 'Penghuni', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600))]),
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
      decoration: BoxDecoration(
        color: isApproved ? const Color(0xFF9C5A1A) : Colors.amber.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text("KODE MASUK", style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: isApproved ? Colors.white70 : Colors.orange.shade800)),
          Text(isApproved ? (kos['join_code'] ?? "-") : "WAITING", style: GoogleFonts.sora(fontSize: 28, fontWeight: FontWeight.w800, color: isApproved ? Colors.white : Colors.orange.shade900)),
        ],
      ),
    );
  }

  Widget _buildPendingAlert() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.shade200)),
      child: Row(children: [const Icon(Icons.warning_amber_rounded, color: Colors.orange), const SizedBox(width: 8), const Expanded(child: Text("Menunggu verifikasi admin.", style: TextStyle(fontSize: 12, color: Colors.orange)))]),
    );
  }

  Widget _buildPopupDetail(IconData icon, String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, size: 14, color: Colors.grey), const SizedBox(width: 4), Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w700))]),
          const SizedBox(height: 4),
          Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFF2E8DA), borderRadius: BorderRadius.circular(10)), child: Text(value ?? '-', style: GoogleFonts.plusJakartaSans(fontSize: 13))),
        ],
      ),
    );
  }

  // --- REUSABLE DASHBOARD CARDS ---

  Widget _summaryCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF9C5A1A), borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white60, size: 24),
          const SizedBox(height: 8),
          Text(value, style: GoogleFonts.sora(fontSize: 32, color: Colors.white, fontWeight: FontWeight.w800)),
          Text(title, style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 12)),
        ],
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
          const Icon(Icons.account_balance_wallet_rounded, color: Colors.amber, size: 32),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Total Profit Bulan Ini", style: GoogleFonts.plusJakartaSans(color: Colors.white60, fontSize: 12)),
              Text(profit, style: GoogleFonts.sora(fontSize: 24, color: Colors.white, fontWeight: FontWeight.w800)),
            ],
          ),
        ],
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

  // --- UPDATE & EDIT LOGIC ---

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
          backgroundColor: const Color(0xFFFFFBF7),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("Edit Informasi Unit", style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: const Color(0xFF9C5A1A))),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildEditField(_nameCtrl, "Nama Kost", Icons.home),
                _buildEditField(_priceCtrl, "Harga/Bulan", Icons.payments, isNumber: true),
                const Divider(),
                _buildEditToggle("Include Listrik", editListrik, (v) => setModalState(() => editListrik = v)),
                _buildEditToggle("Include Air", editAir, (v) => setModalState(() => editAir = v)),
                _buildEditToggle("Include WiFi", editWifi, (v) => setModalState(() => editWifi = v)),
                const Divider(),
                _buildEditField(_rulesCtrl, "Peraturan", Icons.gavel, maxLines: 2),
                _buildEditField(_addressCtrl, "Alamat", Icons.location_on, maxLines: 2),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9C5A1A), foregroundColor: Colors.white),
              onPressed: () => _updateKost(kos, editListrik, editAir, editWifi),
              child: const Text("Simpan"),
            ),
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

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Berhasil Update"), backgroundColor: Colors.green));
        fetchDashboard();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal: $e"), backgroundColor: Colors.red));
    }
  }

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
        Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w500)),
        Switch(value: value, onChanged: onChanged, activeTrackColor: const Color(0xFF9C5A1A)),
      ],
    );
  }
}