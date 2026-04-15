import 'package:flutter/material.dart';
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

  // Controllers dideklarasikan di sini
  late TextEditingController _nameCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _rulesCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _descCtrl;

  @override
  void initState() {
    super.initState();
    // Inisialisasi controller di initState agar lebih aman
    _nameCtrl = TextEditingController();
    _priceCtrl = TextEditingController();
    _rulesCtrl = TextEditingController();
    _addressCtrl = TextEditingController();
    _descCtrl = TextEditingController();
    fetchDashboard();
  }

  @override
  void dispose() {
    // WAJIB: Bersihkan memori saat page ditutup
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _rulesCtrl.dispose();
    _addressCtrl.dispose();
    _descCtrl.dispose();
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
          .eq('is_approved', true);

      final List kos = kosResponse as List;

      final List<Future<dynamic>> penghuniFutures = kos.map((k) {
        return supabase
            .from('profiles')
            .select()
            .eq('kost_id', k['id']);
      }).toList();

      final results = await Future.wait(penghuniFutures);

      int penghuniCount = 0;
      int profit = 0;
      final List<Map<String, dynamic>> kosWithStats = [];

      for (int i = 0; i < results.length; i++) {
        final List tenantsInKos = results[i] as List;
        final int harga = (kos[i]['price'] as num?)?.toInt() ?? 0;
        final int activeTenants = tenantsInKos.length;
        final int monthlyProfit = harga * activeTenants;

        final Map<String, dynamic> currentKos = Map<String, dynamic>.from(kos[i] as Map);
        currentKos['active_tenants'] = activeTenants;
        currentKos['monthly_profit'] = monthlyProfit;
        kosWithStats.add(currentKos);

        penghuniCount += tenantsInKos.length;
        profit += monthlyProfit;
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

  Future<void> _updateKost(Map oldData, bool newListrik, bool newAir, bool newWifi) async {
    List<String> changes = [];

    // Deteksi perubahan untuk pesan reminder
    if (oldData['include_electricity'] != newListrik) {
      changes.add(newListrik ? "Mulai tmsk listrik" : "Tdk tmsk listrik");
    }
    if (oldData['include_water'] != newAir) {
      changes.add(newAir ? "Mulai tmsk air" : "Tdk tmsk air");
    }
    if (oldData['include_wifi'] != newWifi) {
      changes.add(newWifi ? "Mulai tmsk WiFi" : "Tdk tmsk WiFi");
    }
    if (oldData['price'].toString() != _priceCtrl.text) {
      changes.add("Harga ganti ke Rp ${_priceCtrl.text}");
    }

    try {
      // 1. Update data utama
      await supabase.from('kosts').update({
        'name': _nameCtrl.text.trim(),
        'price': int.tryParse(_priceCtrl.text) ?? 0,
        'rules': _rulesCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'include_electricity': newListrik,
        'include_water': newAir,
        'include_wifi': newWifi,
      }).eq('id', oldData['id']);

      // 2. Kirim ke tabel reminders milikmu
      if (changes.isNotEmpty) {
        String pesanLog = "Update ${oldData['name']}: ${changes.join(', ')}";
        await supabase.from('reminders').insert({
          'user_id': supabase.auth.currentUser?.id,
          'title': 'Edit Fasilitas Kos',
          'description': pesanLog,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      if (mounted) {
        Navigator.pop(context); // Tutup dialog edit
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Berhasil Update & Catat di Reminders"), backgroundColor: Colors.green)
        );
        fetchDashboard(); // Refresh UI
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal: $e")));
    }
  }

  void _showEditDialog(Map kos) {
    // Set data awal ke controller
    _nameCtrl.text = kos['name'] ?? '';
    _priceCtrl.text = (kos['price'] ?? 0).toString();
    _rulesCtrl.text = kos['rules'] ?? '';
    _addressCtrl.text = kos['address'] ?? '';
    _descCtrl.text = kos['description'] ?? '';

    bool editListrik = kos['include_electricity'] == true;
    bool editAir = kos['include_water'] == true;
    bool editWifi = kos['include_wifi'] == true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Edit Informasi Unit", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF9C5A1A))),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildField(_nameCtrl, "Nama Kos", Icons.home),
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

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFF9C5A1A)));

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: fetchDashboard,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text("Dashboard Owner", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _summaryCard("Total Kos", "$totalKos", Icons.home_work)),
                const SizedBox(width: 12),
                Expanded(child: _summaryCard("Penghuni Aktif", "$totalPenghuni", Icons.people)),
              ],
            ),
            const SizedBox(height: 12),
            _profitCard(currency.format(totalProfit)),
            const SizedBox(height: 24),
            const Text("Kos Saya", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...kosList.map((kos) => _kosCard(kos)),
          ],
        ),
      ),
    );
  }

  Widget _kosCard(Map kos) {
    final int activeTenants = (kos['active_tenants'] as num?)?.toInt() ?? 0;
    final int monthlyProfit = (kos['monthly_profit'] as num?)?.toInt() ?? 0;
    final int totalKamar = (kos['slots'] as num?)?.toInt() ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        onTap: () => _showDetailDialog(kos),
        contentPadding: const EdgeInsets.all(16),
        leading: const CircleAvatar(backgroundColor: Color(0xFF9C5A1A), child: Icon(Icons.home, color: Colors.white)),
        title: Text(kos['name'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(currency.format(kos['price'] ?? 0)),
            const SizedBox(height: 4),
            Text("Total Kamar: $totalKamar", style: const TextStyle(fontSize: 12)),
            Text("Penghuni Aktif: $activeTenants", style: const TextStyle(fontSize: 12)),
            Text("Profit/Bulan: ${currency.format(monthlyProfit)}", style: const TextStyle(fontSize: 12)),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      ),
    );
  }

  void _showDetailDialog(Map kos) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(kos['name'] ?? 'Detail Kos', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF9C5A1A))),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber.shade300)),
                child: Column(
                  children: [
                    const Text("KODE MASUK PENGHUNI", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                    Text(kos['join_code'] ?? "NO CODE", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              _buildPopupDetail(Icons.location_on, "Alamat", kos['address']),
              _buildPopupDetail(Icons.payments, "Harga", currency.format(kos['price'] ?? 0)),
              const Divider(),
              _buildReadOnlySwitch("WiFi", kos['include_wifi'] == true),
              _buildReadOnlySwitch("Listrik", kos['include_electricity'] == true),
              _buildReadOnlySwitch("Air", kos['include_water'] == true),
              const Divider(),
              _buildPopupDetail(Icons.gavel, "Peraturan", kos['rules'] ?? 'Tidak ada peraturan khusus'),
            ],
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

  // --- REUSABLE COMPONENTS ---

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

  Widget _buildEditToggle(String label, bool value, Function(bool) onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14)),
        Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: const Color(0xFF9C5A1A),
          activeColor: Colors.white,
        ),
      ],
    );
  }

  Widget _buildReadOnlySwitch(String label, bool value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14)),
        Switch(
          value: value,
          onChanged: null, // Read-only
          activeTrackColor: const Color(0xFF9C5A1A),
          activeColor: Colors.white,
          inactiveTrackColor: Colors.grey.shade200,
        ),
      ],
    );
  }

  Widget _buildPopupDetail(IconData icon, String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, size: 14, color: Colors.grey), const SizedBox(width: 4), Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold))]),
          const SizedBox(height: 4),
          Container(width: double.infinity, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFF2E8DA), borderRadius: BorderRadius.circular(8)), child: Text(value ?? '-', style: const TextStyle(fontSize: 13))),
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
          Text(value, style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold)),
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 13)),
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
              const Text("Total Profit Bulan Ini", style: TextStyle(color: Colors.white70, fontSize: 13)),
              Text(profit, style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}
