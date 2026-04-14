import 'package:flutter/material.dart';
import 'package:kostly_pa/services/supabase_service.dart';

class ApprovalPage extends StatefulWidget {
  final VoidCallback? onBack;
  const ApprovalPage({super.key, this.onBack});

  @override
  State<ApprovalPage> createState() => _ApprovalPageState();
}

class _ApprovalPageState extends State<ApprovalPage> {
  final supabase = SupabaseService.client;
  List owners = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchOwners();
  }

  Future<void> fetchOwners() async {
    // ...
    try {
      final data = await supabase
          .from('profiles')
          .select('*, kosts!kosts_owner_id_fkey(*)')
          .eq('role', 'owner')
          .eq('is_approved', false);

      if (mounted) {
        setState(() {
          owners = data as List;
          isLoading = false;
        });
      }
        } catch (e) {
            debugPrint("Error Fetching: $e");
            if (mounted) setState(() => isLoading = false);
          }
        }

  Future<void> handleApprove(String userId) async {
    try {
      await supabase.from('profiles').update({'is_approved': true}).eq('id', userId);
      await supabase.from('kosts').update({'is_approved': true}).eq('owner_id', userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Owner & Kost Berhasil Disetujui!"), backgroundColor: Colors.green),
        );
        fetchOwners();
      }
    } catch (e) {
      debugPrint("Gagal Approve: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFF9C5A1A)));

    return Scaffold(
      backgroundColor: const Color(0xFFF2E8DA),
      appBar: AppBar(
        title: const Text("Approval Owner", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent, elevation: 0, foregroundColor: Colors.black,
        leading: widget.onBack != null ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onBack) : null,
      ),
      body: owners.isEmpty
          ? const Center(child: Text("Tidak ada antrean approval"))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: owners.length,
              itemBuilder: (context, i) {
                final item = owners[i];
                final List listKos = item['kosts'] ?? [];
                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  margin: const EdgeInsets.only(bottom: 15),
                  child: ExpansionTile(
                    initiallyExpanded: true,
                    title: Text(item['email'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: listKos.isNotEmpty 
                      ? Text("${listKos.length} Kost menunggu persetujuan") 
                      : const Text("Menunggu verifikasi akun", style: TextStyle(color: Colors.orange)),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (listKos.isNotEmpty) ...[
                                const Text("Detail Fasilitas & Kost:", 
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF9C5A1A))),
                                const Divider(),
                                ...listKos.map((k) => Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(k['name'] ?? 'Nama Kost', 
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      const SizedBox(height: 5),
                                      // Informasi Harga & Alamat
                                      Row(
                                        children: [
                                          const Icon(Icons.location_on, size: 16, color: Colors.grey),
                                          const SizedBox(width: 5),
                                          Expanded(child: Text(k['address'] ?? 'Alamat tidak diisi', style: const TextStyle(fontSize: 12))),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      // Detail Fasilitas (Listrik, Air, dll)
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        children: [
                                          _buildChip(Icons.flash_on, k['include_electricity'] == true ? "Termasuk Listrik" : "Listrik Sendiri"),
                                          _buildChip(Icons.water_drop, k['include_water'] == true ? "Termasuk Air" : "Air Sendiri"),
                                          _buildChip(Icons.wifi, k['include_wifi'] == true ? "Ada WiFi" : "No WiFi"),
                                          _buildChip(Icons.king_bed, "${k['slots'] ?? 0} Kamar"),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Text("Harga: Rp ${k['price']} / Bulan", 
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                    ],
                                  ),
                                )),
                              ],
                                const SizedBox(height: 15),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF9C5A1A), 
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    icon: const Icon(Icons.check_circle),
                                    label: const Text("APPROVE OWNER & KOS"),
                                    onPressed: () => handleApprove(item['id']),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                  ),
                );
              },
            ),
    );
  }
}

Widget _buildChip(IconData icon, String label) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFF9C5A1A).withAlpha(25),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF9C5A1A)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
      ],
    ),
  );
}