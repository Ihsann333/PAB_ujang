import 'package:flutter/material.dart';
import 'package:kostly_pa/pages/login_page.dart';
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
  String? adminEmail;

  // Set untuk melacak status loading tombol
  final Set<String> approvingOwnerIds = {};
  final Set<String> approvingKostIds = {};
  final Set<String> rejectingOwnerIds = {};
  final Set<String> rejectingKostIds = {};

  @override
  void initState() {
    super.initState();
    adminEmail = supabase.auth.currentUser?.email;
    fetchOwners();
  }

  // --- UTILS ---
  String formatRupiah(dynamic price) {
    if (price == null) return "0";
    String priceStr = price.toString();
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return priceStr.replaceAllMapped(reg, (Match m) => '${m[1]}.');
  }

  // --- LOGIC FETCH DATA ---
  Future<void> fetchOwners() async {
    try {
      if (mounted) setState(() => isLoading = true);

      // 1. Ambil owner yang belum disetujui
      final pendingOwnersRes = await supabase
          .from('profiles')
          .select('*')
          .eq('role', 'owner')
          .eq('is_approved', false);

      // 2. Ambil semua unit kos yang belum disetujui
      final pendingKostsRes = await supabase
          .from('kosts')
          .select('*')
          .eq('is_approved', false);

      final List pendingOwners = pendingOwnersRes as List;
      final List pendingKosts = pendingKostsRes as List;

      // 3. Gabungkan data agar setiap owner punya list 'kosts'
      final Map<String, Map<String, dynamic>> ownerMap = {};

      for (var owner in pendingOwners) {
        final oId = owner['id'].toString();
        ownerMap[oId] = Map<String, dynamic>.from(owner);
        ownerMap[oId]!['kosts'] = [];
      }

      for (var kost in pendingKosts) {
        final oId = kost['owner_id'].toString();
        // Jika owner-nya sudah ada di list pending, tambahkan kos ke dalamnya
        if (ownerMap.containsKey(oId)) {
          ownerMap[oId]!['kosts'].add(Map<String, dynamic>.from(kost));
        } else {
          // Jika owner-nya sudah approved tapi unit kosnya belum, 
          // kita tetap tampilkan owner tersebut agar unitnya bisa di-approve
          final ownerData = await supabase.from('profiles').select().eq('id', oId).single();
          ownerMap[oId] = Map<String, dynamic>.from(ownerData);
          ownerMap[oId]!['kosts'] = [Map<String, dynamic>.from(kost)];
        }
      }

      if (mounted) {
        setState(() {
          owners = ownerMap.values.toList();
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error Fetching: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  // --- LOGIC ACTIONS ---
  Future<void> handleApproveOwner(String userId) async {
    try {
      if (mounted) setState(() => approvingOwnerIds.add(userId));
      await Future.wait([
        supabase.from('profiles').update({'is_approved': true}).eq('id', userId),
        supabase.from('kosts').update({'is_approved': true}).eq('owner_id', userId),
      ]);
      fetchOwners();
    } finally {
      if (mounted) setState(() => approvingOwnerIds.remove(userId));
    }
  }

  Future<void> handleApproveKost(String kostId) async {
    try {
      if (mounted) setState(() => approvingKostIds.add(kostId));
      await supabase.from('kosts').update({'is_approved': true}).eq('id', kostId);
      fetchOwners();
    } finally {
      if (mounted) setState(() => approvingKostIds.remove(kostId));
    }
  }

  Future<void> handleRejectOwner(String userId) async {
    try {
      if (mounted) setState(() => rejectingOwnerIds.add(userId));
      await supabase.from('profiles').update({'role': 'user', 'is_approved': true}).eq('id', userId);
      await supabase.from('kosts').delete().eq('owner_id', userId).eq('is_approved', false);
      fetchOwners();
    } finally {
      if (mounted) setState(() => rejectingOwnerIds.remove(userId));
    }
  }

  Future<void> handleRejectKost(String kostId) async {
    try {
      if (mounted) setState(() => rejectingKostIds.add(kostId));
      await supabase.from('kosts').delete().eq('id', kostId);
      fetchOwners();
    } finally {
      if (mounted) setState(() => rejectingKostIds.remove(kostId));
    }
  }

Future<void> handleLogout() async {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Konfirmasi Keluar",
          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4A3428)),
        ),
        content: const Text("Apakah Anda yakin ingin keluar dari akun ini?"),
        actions: [
          // Tombol Batal
          TextButton(
            onPressed: () => Navigator.pop(context), // Tutup dialog
            child: const Text("Batal", style: TextStyle(color: Colors.grey)),
          ),
          // Tombol Konfirmasi Keluar
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () async {
              await supabase.auth.signOut();
              if (mounted) {
                // Tutup dialog dulu
                Navigator.pop(context);
                // Baru pindah ke LoginPage dan hapus semua history page
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (route) => false,
                );
              }
            },
            child: const Text(
              "Ya, Keluar",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      );
    },
  );
}

  // --- UI WIDGETS ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF7F0),
      appBar: AppBar(
        title: const Text("Approval Panel", style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        foregroundColor: const Color(0xFF4A3428),
        leading: widget.onBack != null ? IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 20), onPressed: widget.onBack) : null,
      ),
      body: isLoading 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF9C5A1A)))
          : Column(
              children: [
                _buildAdminHeader(),
                Expanded(
                  child: owners.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: owners.length,
                          itemBuilder: (context, i) => _buildOwnerCard(owners[i]),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildAdminHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
      ),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: const Color(0xFF9C5A1A), child: const Text("A", style: TextStyle(color: Colors.white))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Administrator", style: TextStyle(fontSize: 12, color: Colors.grey)),
                Text(adminEmail ?? "admin@gmail.com", style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          IconButton(
            onPressed: handleLogout,
            icon: const Icon(Icons.power_settings_new, color: Colors.redAccent, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildOwnerCard(Map<String, dynamic> item) {
    final List listKos = item['kosts'] ?? [];
    final String ownerId = item['id'].toString();
    final bool profilePending = item['is_approved'] == false;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.brown.withOpacity(0.05), blurRadius: 10)],
      ),
      child: ExpansionTile(
        title: Text(item['full_name'] ?? item['email'], style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4A3428))),
        subtitle: Text(item['email'], style: const TextStyle(fontSize: 12)),
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                if (profilePending) ...[
                  const Text("⚠️ OWNER BARU: Aktivasi Akun & Kost", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF9C5A1A))),
                  const SizedBox(height: 12),
                  _buildActionButtons(
                    onApprove: () => handleApproveOwner(ownerId),
                    onReject: () => handleRejectOwner(ownerId),
                    isApproving: approvingOwnerIds.contains(ownerId),
                    isRejecting: rejectingOwnerIds.contains(ownerId),
                    approveLabel: "APPROVE SEMUA",
                    rejectLabel: "TOLAK",
                  ),
                  const SizedBox(height: 20),
                ],
                if (listKos.isNotEmpty) ...[
                      const Row(children: [Icon(Icons.home_work, size: 16), SizedBox(width: 8), Text("UNIT KOST", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10))]),
                  const SizedBox(height: 12),
                  ...listKos.map((k) => _buildKostItem(k, profilePending)),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKostItem(Map<String, dynamic> k, bool hideButtons) {
    // Data Boolean dari Supabase
    final bool hasWifi = k['include_wifi'] == true;
    final bool hasWater = k['include_water'] == true;
    final bool hasElec = k['include_electricity'] == true;
    final int rooms = k['slots'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFDFD),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k['name'] ?? 'Unit Kost', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.location_on, size: 14, color: Colors.grey),
            Expanded(child: Text(k['address'] ?? "Alamat tidak diisi", style: const TextStyle(fontSize: 12, color: Colors.grey))),
          ]),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Listrik
              _buildFeatureTag(
                Icons.bolt, 
                hasElec ? "Include Listrik" : "Exclude Listrik", 
                hasElec
              ),
              
              // Air
              _buildFeatureTag(
                Icons.water_drop, 
                hasWater ? "Include Air" : "Exclude Air", 
                hasWater
              ),
              
              // WiFi
              _buildFeatureTag(
                Icons.wifi, 
                hasWifi ? "Free WiFi" : "Tanpa WiFi", 
                hasWifi
              ),
              
              // Kamar (Selalu dianggap true karena pasti ada jumlahnya)
              _buildFeatureTag(
                Icons.king_bed, 
                "$rooms Kamar", 
                true
              ),
            ],
          ),
          const SizedBox(height: 12),
                    const Text("ATURAN KOST:", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.brown)),
          Text(k['rules'] ?? "gg", style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 10),
          Text("Harga: Rp ${formatRupiah(k['price'])} / Bulan", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
          if (!hideButtons) ...[
            const SizedBox(height: 12),
            _buildActionButtons(
              onApprove: () => handleApproveKost(k['id'].toString()),
              onReject: () => handleRejectKost(k['id'].toString()),
              isApproving: approvingKostIds.contains(k['id'].toString()),
              isRejecting: rejectingKostIds.contains(k['id'].toString()),
              approveLabel: "SETUJUI",
              rejectLabel: "HAPUS",
            ),
          ]
        ],
      ),
    );
  }

Widget _buildFeatureTag(IconData icon, String label, bool isIncluded) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      // Jika tidak include, pakai warna abu-abu muda, jika include pakai krem
      color: isIncluded ? const Color(0xFFF2E8DA) : Colors.grey[200],
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon, 
          size: 14, 
          color: isIncluded ? const Color(0xFF7A4A1F) : Colors.grey[500],
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11, 
            fontWeight: FontWeight.bold, 
            // Coret teks jika tidak include (opsional) atau ubah warna saja
            color: isIncluded ? const Color(0xFF7A4A1F) : Colors.grey[500],
            decoration: isIncluded ? TextDecoration.none : TextDecoration.lineThrough,
          ),
        ),
      ],
    ),
  );
}

  Widget _buildActionButtons({required VoidCallback onApprove, required VoidCallback onReject, required bool isApproving, required bool isRejecting, required String approveLabel, required String rejectLabel}) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9C5A1A), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: (isApproving || isRejecting) ? null : onApprove,
            child: isApproving ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(approveLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: const BorderSide(color: Color(0xFFFFEBEE)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: (isApproving || isRejecting) ? null : onReject,
            child: isRejecting ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent)) : Text(rejectLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.done_all, size: 50, color: Colors.brown.withOpacity(0.3)), const Text("Tidak ada antrean approval", style: TextStyle(color: Colors.brown))]));
  }
}
