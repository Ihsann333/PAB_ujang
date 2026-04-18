import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
    if (value is String) {
      String v = value.toLowerCase();
      return v == "ya" || v == "yes" || v == "include" || v == "tersedia" || v == "1";
    }
    return false;
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
                  // Nama Kos (Tanpa Label Premium)
                  Text(
                    kos['name'] ?? 'Nama Kost',
                    style: GoogleFonts.sora(fontSize: 26, fontWeight: FontWeight.w700, color: const Color(0xFF2D1E12)),
                  ),
                  const SizedBox(height: 10),
                  
                  // Harga
                  Text(
                    "Rp ${formatRupiah(kos['price'])}",
                    style: GoogleFonts.sora(fontSize: 22, color: const Color(0xFF9C5A1A), fontWeight: FontWeight.w700),
                  ),
                  Text("per bulan", style: GoogleFonts.plusJakartaSans(color: Colors.grey, fontSize: 14)),
                  
                  const SizedBox(height: 30),
                  Text("Fasilitas Utama", style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 15),

                  // PERBAIKAN: Menggunakan Wrap agar tidak jauhan/renggang
                  Wrap(
                    spacing: 15, // Jarak horizontal antar kotak
                    runSpacing: 15, // Jarak vertikal jika baris baru
                    children: [
                      _buildFasilitasItem(Icons.wifi, "WiFi", cekFasilitas(kos['include_wifi'] ?? kos['is_wifi'])),
                      _buildFasilitasItem(Icons.water_drop, "Air", cekFasilitas(kos['include_water'] ?? kos['is_air'])),
                      _buildFasilitasItem(Icons.bolt, "Listrik", cekFasilitas(kos['include_electricity'] ?? kos['is_listrik'])),
                    ],
                  ),

                  const SizedBox(height: 35),
                  Text("Aturan", style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700)),
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
      width: 90, // Ukuran kotak yang pas
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isAvailable ? Colors.white : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isAvailable ? const Color(0xFF9C5A1A).withOpacity(0.2) : Colors.grey.shade200
        ),
        boxShadow: isAvailable 
            ? [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4))] 
            : [],
      ),
      child: Column(
        children: [
          Icon(icon, color: isAvailable ? const Color(0xFF9C5A1A) : Colors.grey, size: 24),
          const SizedBox(height: 6),
          Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
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
