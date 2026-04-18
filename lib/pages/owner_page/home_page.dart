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
        
        // Hitung profit: Hanya jika sudah approved
        final int monthlyProfit = isApproved ? (harga * activeTenants) : 0;

        final Map<String, dynamic> currentKos = Map<String, dynamic>.from(kos[i] as Map);
        currentKos['active_tenants'] = activeTenants;
        currentKos['monthly_profit'] = monthlyProfit;
        
        // BAGIAN PENTING: Masukkan ke list TANPA syarat isApproved
        // Supaya card-nya tetap muncul di bawah
        kosWithStats.add(currentKos); 

        // Statistik Dashboard: Hanya hitung yang sudah approved
        if (isApproved) {
          penghuniCount += activeTenants;
          profit += monthlyProfit;
        }
      }

      if (mounted) {
        setState(() {
          kosList = kosWithStats; // Sekarang isinya semua kost (approved & pending)
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

  Widget _kosCard(Map kos) {
    final int activeTenants = (kos['active_tenants'] as num?)?.toInt() ?? 0;
    final int monthlyProfit = (kos['monthly_profit'] as num?)?.toInt() ?? 0;
    final int totalKamar = (kos['slots'] as num?)?.toInt() ?? 0;
    
    // Cek Status Approval
    final bool isApproved = kos['is_approved'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      // Jika belum approved, kasih sedikit transparansi atau warna beda
      color: isApproved ? Colors.white : const Color(0xFFF9F9F9),
      child: ListTile(
        onTap: () => _showDetailDialog(kos),
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: isApproved ? const Color(0xFF9C5A1A) : Colors.grey, 
          child: const Icon(Icons.home, color: Colors.white)
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                kos['name'] ?? '-',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: isApproved ? const Color(0xFF2D241A) : Colors.grey,
                ),
              ),
            ),
            // PERUBAHAN 2: Tambahkan Badge Status
            if (!isApproved)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "PENDING",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade800,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              currency.format(kos['price'] ?? 0),
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w500,
                color: const Color(0xFF51463B),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _miniInfo(Icons.meeting_room, "$totalKamar Kamar"),
                const SizedBox(width: 12),
                _miniInfo(Icons.person, "$activeTenants Penghuni"),
              ],
            ),
            if (isApproved) ...[
               const SizedBox(height: 4),
               Text(
                 "Estimasi Profit: ${currency.format(monthlyProfit)}", 
                 style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.w600)
               ),
            ] else 
               Padding(
                 padding: const EdgeInsets.only(top: 4),
                 child: Text(
                   "* Menunggu verifikasi admin untuk menerima kos",
                   style: GoogleFonts.plusJakartaSans(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.orange.shade900),
                 ),
               ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      ),
    );
  }

  Widget _miniInfo(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey.shade700)),
      ],
    );
  }

  // Sisa kode lainnya (build, _showDetailDialog, dll) tetap sama seperti sebelumnya...
  // Tapi pastikan di dalam ListView utama memanggil _kosCard yang baru ini.

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFF9C5A1A)));

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: fetchDashboard,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              "Dashboard Owner",
              style: GoogleFonts.sora(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF202124),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _summaryCard("Total Kost", "$totalKos", Icons.home_work)),
                const SizedBox(width: 12),
                Expanded(child: _summaryCard("Penghuni Aktif", "$totalPenghuni", Icons.people)),
              ],
            ),
            const SizedBox(height: 12),
            _profitCard(currency.format(totalProfit)),
            const SizedBox(height: 24),
            Text(
              "Kost Saya",
              style: GoogleFonts.sora(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF202124),
              ),
            ),
            const SizedBox(height: 12),
            ...kosList.map((kos) => _kosCard(kos)),
          ],
        ),
      ),
    );
  }

  // Reusable widgets lainnya seperti _summaryCard, _profitCard, _showDetailDialog, dll 
  // silakan gunakan dari kode sebelumnya karena tidak ada perubahan logika di sana.
  
  // (Pastikan fungsi _showDetailDialog dan _updateKost tetap ada di bawah sini)
  // ...
void _showDetailDialog(Map kos) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFFFFFBF7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        kos['name'] ?? 'Detail Kost',
        style: GoogleFonts.sora(
          fontWeight: FontWeight.w700,
          color: const Color(0xFF9C5A1A),
        ),
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info Status Approval (Jika Belum Approved)
              if (kos['is_approved'] != true)
                Container(
                  margin: const EdgeInsets.only(bottom: 15),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200)
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Menunggu verifikasi admin agar bisa menerima penghuni.",
                          style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.orange.shade900)
                        )
                      ),
                    ],
                  ),
                ),

              // Kode Join
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade300)
                ),
                child: Column(
                  children: [
                    Text(
                      "KODE MASUK PENGHUNI",
                      style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.deepOrange),
                    ),
                    Text(
                      kos['is_approved'] == true ? (kos['join_code'] ?? "NO CODE") : "WAITING",
                      style: GoogleFonts.sora(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: 2),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 15),
              _buildPopupDetail(Icons.location_on, "Alamat", kos['address']),
              _buildPopupDetail(Icons.payments, "Harga", currency.format(kos['price'] ?? 0)),
              const Divider(),
              
              // Bagian Daftar Penghuni
              Row(
                children: [
                  const Icon(Icons.people, size: 18, color: Color(0xFF9C5A1A)),
                  const SizedBox(width: 8),
                  Text(
                    "Daftar Penghuni Aktif",
                    style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              
              // Query Real-time untuk mengambil siapa saja penghuninya
              FutureBuilder(
                future: supabase.from('profiles').select().eq('kost_id', kos['id']),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF9C5A1A))),
                    );
                  }
                  final List data = snapshot.data as List? ?? [];
                  return _buildTenantList(data);
                },
              ),

              const Divider(),
              _buildPopupDetail(Icons.gavel, "Peraturan", kos['rules'] ?? 'Tidak ada peraturan khusus'),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("Tutup", style: GoogleFonts.plusJakartaSans(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9C5A1A), foregroundColor: Colors.white),
          onPressed: () {
            Navigator.pop(context);
            _showEditDialog(kos);
          },
          child: Text("Edit Data", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );
}

Future<void> _updateKost(Map oldData, bool newListrik, bool newAir, bool newWifi) async {
    try {
      // HANYA UPDATE TABEL KOSTS
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
        Navigator.pop(context); // Tutup dialog edit
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Berhasil Update Data Kost"), 
            backgroundColor: Colors.green
          )
        );
        fetchDashboard(); // Refresh UI agar data terbaru muncul
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal Update: $e"), 
            backgroundColor: Colors.red
          )
        );
      }
    }
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
          backgroundColor: const Color(0xFFFFFBF7),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("Edit Informasi Unit", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: const Color(0xFF9C5A1A))),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildField(_nameCtrl, "Nama Kost", Icons.home),
                _buildField(_priceCtrl, "Harga/Bulan", Icons.payments, isNumber: true),
                const Divider(),
                _buildEditToggle("Include Listrik", editListrik, (v) => setModalState(() => editListrik = v)),
                _buildEditToggle("Include Air", editAir, (v) => setModalState(() => editAir = v)),
                _buildEditToggle("Include WiFi", editWifi, (v) => setModalState(() => editWifi = v)),
                const Divider(),
                _buildField(_rulesCtrl, "Peraturan", Icons.gavel, maxLines: 2),
                _buildField(_addressCtrl, "Alamat", Icons.location_on, maxLines: 2),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text("Batal")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9C5A1A), foregroundColor: Colors.white),
              onPressed: () => _updateKost(kos, editListrik, editAir, editWifi),
              child: Text("Simpan"),
            ),
          ],
        ),
      ),
    );
  }

  // Helper UI Builders
  Widget _buildField(TextEditingController ctrl, String label, IconData icon, {bool isNumber = false, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF9C5A1A), size: 20),
          filled: true,
          fillColor: const Color(0xFFF5F0EA),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildTenantList(List tenants) {
    if (tenants.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          "Belum ada penghuni aktif di unit ini.",
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12, 
            color: Colors.grey.shade600, 
            fontStyle: FontStyle.italic
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      children: tenants.map((t) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: const Color(0xFF9C5A1A).withOpacity(0.1),
              child: const Icon(Icons.person, size: 16, color: Color(0xFF9C5A1A)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                t['full_name'] ?? 'Tanpa Nama',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14, 
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2D241A)
                ),
              ),
            ),
            const Icon(Icons.check_circle, size: 14, color: Colors.green),
          ],
        ),
      )).toList(),
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

  Widget _buildReadOnlySwitch(String label, bool value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w500)),
        Switch(value: value, onChanged: null, activeTrackColor: const Color(0xFF9C5A1A)),
      ],
    );
  }

  Widget _buildPopupDetail(IconData icon, String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, size: 14, color: Colors.grey), const SizedBox(width: 4), Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w700))]),
          const SizedBox(height: 4),
          Container(width: double.infinity, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFF2E8DA), borderRadius: BorderRadius.circular(8)), child: Text(value ?? '-', style: GoogleFonts.plusJakartaSans(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _summaryCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF9C5A1A), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white70, size: 28),
          const SizedBox(height: 10),
          Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 40, color: Colors.white, fontWeight: FontWeight.w700)),
          Text(title, style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _profitCard(String profit) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF6B3A10), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          const Icon(Icons.attach_money, color: Colors.amber, size: 36),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Total Profit Bulan Ini", style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 13)),
              Text(profit, style: GoogleFonts.plusJakartaSans(fontSize: 36, color: Colors.white, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}