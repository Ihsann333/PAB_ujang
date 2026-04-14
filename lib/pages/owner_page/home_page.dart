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

  @override
  void initState() {
    super.initState();
    fetchDashboard();
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

      for (int i = 0; i < results.length; i++) {
        final List tenantsInKos = results[i] as List;
        final int harga = (kos[i]['price'] as num?)?.toInt() ?? 0;
        penghuniCount += tenantsInKos.length;
        profit += harga * tenantsInKos.length;
      }

      if (mounted) {
        setState(() {
          kosList = kos;
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

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());

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

//eh ini buat nampilin detail kos pas card kos di klik, biar ga cuman list doang
Widget _kosCard(Map kos) {
  void _showDetailDialog() {
    // Buat format rupiah khusus buat di pop-up biar cakep
    final priceFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.home_work, color: Color(0xFF9C5A1A)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(kos['name'] ?? 'Detail Kos', 
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF4A2C0A))),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Alamat
              _buildPopupDetail(Icons.location_on, "Alamat", kos['address'] ?? '-'),
              const Divider(),
              
              // Harga
              _buildPopupDetail(Icons.payments, "Harga/Bulan", priceFormatter.format(kos['price'] ?? 0)),
              const SizedBox(height: 10),

              // Status Listrik & Air (Pake SwitchListTile dummy biar mirip form input)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("Termasuk Listrik", style: TextStyle(fontSize: 14)),
                value: kos['include_listrik'] == true, 
                onChanged: null, // null berarti read-only (gabisa diubah)
                activeThumbColor: const Color(0xFF9C5A1A),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("Termasuk Air", style: TextStyle(fontSize: 14)),
                value: kos['include_air'] == true, 
                onChanged: null, 
                activeThumbColor: const Color(0xFF9C5A1A),
              ),
              
              const Divider(),
              // Fasilitas/Deskripsi
              _buildPopupDetail(Icons.description, "Fasilitas & Deskripsi", kos['description'] ?? '-'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Tutup", style: TextStyle(color: Color(0xFF9C5A1A))),
          ),
        ],
      ),
    );
  }

  //card utama kos (ingatin kocak)
  return Card(
    margin: const EdgeInsets.only(bottom: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: ListTile(
      onTap: _showDetailDialog, // <--- SEKARANG JIKA DITEKAN, POP-UP MUNCUL!
      contentPadding: const EdgeInsets.all(16),
      leading: const CircleAvatar(
        backgroundColor: Color(0xFF9C5A1A), 
        child: Icon(Icons.home, color: Colors.white)
      ),
      title: Text(kos['name'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text("Rp ${kos['price'] ?? '-'} / bulan"),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
    ),
  );
}

  Widget _buildPopupDetail(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF2E8DA), // Warna background input biar mirip form
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
  }