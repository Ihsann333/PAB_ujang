import 'package:flutter/material.dart';

class DetailKosPage extends StatelessWidget {
  final Map kos;
  const DetailKosPage({super.key, required this.kos});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2E8DA),
      appBar: AppBar(
        title: Text(kos['name'] ?? 'Detail Kos'),
        backgroundColor: const Color(0xFF9C5A1A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 250, width: double.infinity, color: const Color(0xFFDCC8B0),
              child: const Icon(Icons.apartment, size: 100, color: Color(0xFF9C5A1A)),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(kos['name'] ?? 'Nama Tidak Tersedia', 
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF4A2C0A))),
                  const SizedBox(height: 8),
                  Text("Rp ${kos['price'] ?? '0'} / Bulan", 
                    style: const TextStyle(fontSize: 20, color: Color(0xFF9C5A1A), fontWeight: FontWeight.w600)),
                  const Divider(height: 40, thickness: 1),
                  const Text("Informasi Kost", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _infoRow(Icons.wifi, "WiFi", kos['include_wifi'] == true ? "Include" : "Tidak Tersedia"),
                  _infoRow(Icons.water_drop, "Air", kos['include_water'] == true ? "Include" : "Bayar Sendiri"),
                  _infoRow(Icons.flash_on, "Listrik", kos['include_electricity'] == true ? "Include" : "Token / Bayar Sendiri"),
                  _infoRow(Icons.description, "Peraturan", kos['rules'] ?? "Tidak ada peraturan khusus"),
                  const SizedBox(height: 24),
                  const Text("Informasi Pemilik", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 25,
                          backgroundColor: Color(0xFFF2E8DA),
                          child: Icon(Icons.person, color: Color(0xFF9C5A1A)),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                kos['profiles']?['name'] ?? 'Nama Pemilik Tidak Ada',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                kos['profiles']?['email'] ?? 'Email tidak tersedia',
                                style: const TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Telp: ${kos['profiles']?['phone'] ?? 'Tidak ada nomor WA'}",
                                style: const TextStyle(color: Color(0xFF9C5A1A), fontSize: 13, fontWeight: FontWeight.w600),
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
    );
  }

    Widget _infoRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 24, color: const Color(0xFF9C5A1A)),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}