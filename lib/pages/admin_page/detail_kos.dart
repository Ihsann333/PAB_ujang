import 'package:flutter/material.dart';

class DetailKosPage extends StatelessWidget {
  final Map kos;

  const DetailKosPage({super.key, required this.kos});

  // --- FUNGSI FORMAT RUPIAH ---
  String formatRupiah(dynamic price) {
    if (price == null) return "0";
    String priceStr = price.toString();
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return priceStr.replaceAllMapped(reg, (Match m) => '${m[1]}.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F2),
      appBar: AppBar(
        title: Text(kos['name'] ?? 'Detail Kos', 
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF9C5A1A),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER VISUAL ---
            Container(
              height: 200,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFFEADBC8),
              ),
              child: const Center(
                child: Icon(Icons.apartment_rounded, size: 100, color: Color(0xFF9C5A1A)),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- NAMA & HARGA ---
                  Text(
                    kos['name'] ?? 'Nama Kos Tidak Tersedia',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF4A2C0A)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Rp ${formatRupiah(kos['price'])} / Bulan",
                    style: const TextStyle(fontSize: 18, color: Colors.green, fontWeight: FontWeight.bold),
                  ),
                  
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 20),

                  // --- INFORMASI KOST ---
                  const Text("Informasi Kost", 
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4A2C0A))),
                  const SizedBox(height: 15),
                  
                  // Menggunakan Card agar lebih rapi
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow(Icons.wifi, "WiFi", kos['wifi'] == true ? "Tersedia" : "Tidak Tersedia"),
                        const Divider(height: 25),
                        _buildInfoRow(Icons.water_drop, "Air", kos['air'] == true ? "Include" : "Tidak Include"),
                        const Divider(height: 25),
                        _buildInfoRow(Icons.bolt, "Listrik", kos['listrik'] == true ? "Include" : "Tidak Include"),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // --- DESKRIPSI (Ganti kolom ini jika namanya berbeda di DB) ---
                  const Text("rules", 
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4A2C0A))),
                  const SizedBox(height: 10),
                  Text(
                    kos['rules'] ?? "Tidak ada aturan tambahan untuk kos ini.",
                    style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET ROW INFO ---
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF9C5A1A), size: 24),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }
}