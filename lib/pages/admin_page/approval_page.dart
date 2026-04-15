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
  final Set<String> approvingOwnerIds = {};
  final Set<String> approvingKostIds = {};
  final Set<String> rejectingOwnerIds = {};
  final Set<String> rejectingKostIds = {};

  @override
  void initState() {
    super.initState();
    fetchOwners();
  }

  Future<void> fetchOwners() async {
    try {
      // 1) Owner yang akunnya masih pending (belum approved admin)
      final pendingOwnersRes = await supabase
          .from('profiles')
          .select('*')
          .eq('role', 'owner')
          .eq('is_approved', false);

      // 2) Semua kos yang masih pending approval
      final pendingKostsRes = await supabase
          .from('kosts')
          .select('*')
          .eq('is_approved', false);

      final List pendingOwners = pendingOwnersRes as List;
      final List pendingKosts = pendingKostsRes as List;

      // 3) Ambil owner dari kos pending (termasuk owner yang akunnya sudah approved)
      final Set<String> ownerIdsFromKost = pendingKosts
          .map((k) => k['owner_id']?.toString())
          .whereType<String>()
          .toSet();

      List ownersFromKost = [];
      if (ownerIdsFromKost.isNotEmpty) {
        final String inClause = ownerIdsFromKost.map((id) => '"$id"').join(',');
        ownersFromKost = await supabase
            .from('profiles')
            .select('*')
            .eq('role', 'owner')
            .filter('id', 'in', '($inClause)');
      }

      // 4) Gabungkan owner unik + sisipkan list kos pending per owner
      final Map<String, Map<String, dynamic>> ownerMap = {};
      for (final dynamic row in [...pendingOwners, ...ownersFromKost]) {
        final m = Map<String, dynamic>.from(row as Map);
        ownerMap[m['id'].toString()] = m;
      }

      final List merged = ownerMap.values.map((owner) {
        final ownerId = owner['id'].toString();
        final ownerPendingKosts = pendingKosts
            .where((k) => k['owner_id']?.toString() == ownerId)
            .map((k) => Map<String, dynamic>.from(k as Map))
            .toList();

        return {
          ...owner,
          'kosts': ownerPendingKosts,
        };
      }).toList();

      // Tampilkan yang memang butuh aksi admin:
      // - akun owner pending, atau
      // - punya kos pending
      final List actionableOwners = merged.where((o) {
        final bool profilePending = o['is_approved'] == false;
        final List listKos = o['kosts'] as List? ?? [];
        return profilePending || listKos.isNotEmpty;
      }).toList();

      if (mounted) {
        setState(() {
          owners = actionableOwners;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error Fetching: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> handleApproveOwner(String userId) async {
    try {
      if (mounted) setState(() => approvingOwnerIds.add(userId));
      await supabase.from('profiles').update({'is_approved': true}).eq('id', userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Owner berhasil disetujui"), backgroundColor: Colors.green),
        );
        fetchOwners();
      }
    } catch (e) {
      debugPrint("Gagal Approve Owner: $e");
    } finally {
      if (mounted) setState(() => approvingOwnerIds.remove(userId));
    }
  }

  Future<void> handleApproveKost(String kostId) async {
    try {
      if (mounted) setState(() => approvingKostIds.add(kostId));
      await supabase.from('kosts').update({'is_approved': true}).eq('id', kostId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Kos berhasil disetujui"), backgroundColor: Colors.green),
        );
        fetchOwners();
      }
    } catch (e) {
      debugPrint("Gagal Approve Kos: $e");
    } finally {
      if (mounted) setState(() => approvingKostIds.remove(kostId));
    }
  }

  Future<void> handleRejectOwner(String userId) async {
    try {
      if (mounted) setState(() => rejectingOwnerIds.add(userId));

      // Demote owner menjadi user agar keluar dari antrean approval owner
      await supabase.from('profiles').update({
        'role': 'user',
        'is_approved': true,
      }).eq('id', userId);

      // Hapus kos yang masih pending milik owner tersebut
      await supabase
          .from('kosts')
          .delete()
          .eq('owner_id', userId)
          .eq('is_approved', false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Owner ditolak"), backgroundColor: Colors.redAccent),
        );
        fetchOwners();
      }
    } catch (e) {
      debugPrint("Gagal Tolak Owner: $e");
    } finally {
      if (mounted) setState(() => rejectingOwnerIds.remove(userId));
    }
  }

  Future<void> handleRejectKost(String kostId) async {
    try {
      if (mounted) setState(() => rejectingKostIds.add(kostId));
      await supabase.from('kosts').delete().eq('id', kostId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Kost berhasil ditolak"), backgroundColor: Colors.redAccent),
        );
        fetchOwners();
      }
    } catch (e) {
      debugPrint("Gagal Tolak Kost: $e");
    } finally {
      if (mounted) setState(() => rejectingKostIds.remove(kostId));
    }
  }

  Future<bool> _confirmReject(String title, String message) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Tolak", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFF9C5A1A)));

    return Scaffold(
      backgroundColor: const Color(0xFFF2E8DA),
      appBar: AppBar(
        title: const Text("Approval Owner", style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
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
                final String ownerId = item['id'].toString();
                final bool profilePending = item['is_approved'] == false;
                final bool isApprovingOwner = approvingOwnerIds.contains(ownerId);
                final bool isRejectingOwner = rejectingOwnerIds.contains(ownerId);
                return Card(
                  color: const Color(0xFFFFFCF7),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  margin: const EdgeInsets.only(bottom: 15),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    title: Text(item['email'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          listKos.isNotEmpty ? "${listKos.length} Kost menunggu persetujuan" : "Menunggu verifikasi akun",
                          style: const TextStyle(color: Color(0xFF6B6257), fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: profilePending ? const Color(0xFFFFE9CC) : const Color(0xFFE7F5EA),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            profilePending ? "Owner Pending" : "Owner Aktif",
                            style: TextStyle(
                              color: profilePending ? const Color(0xFF9C5A1A) : const Color(0xFF2F8F46),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (profilePending)
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF9C5A1A),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        icon: isApprovingOwner
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                              )
                                            : const Icon(Icons.verified_user),
                                        label: Text(isApprovingOwner ? "MEMPROSES..." : "APPROVE OWNER"),
                                        onPressed: (isApprovingOwner || isRejectingOwner)
                                            ? null
                                            : () => handleApproveOwner(ownerId),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.redAccent,
                                          side: const BorderSide(color: Colors.redAccent),
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        icon: isRejectingOwner
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent),
                                              )
                                            : const Icon(Icons.close),
                                        label: Text(isRejectingOwner ? "MEMPROSES..." : "TOLAK OWNER"),
                                        onPressed: (isApprovingOwner || isRejectingOwner)
                                            ? null
                                            : () async {
                                                final ok = await _confirmReject(
                                                  "Tolak Owner",
                                                  "Owner akan ditolak dan unit kos pending miliknya dihapus. Lanjutkan?",
                                                );
                                                if (ok) handleRejectOwner(ownerId);
                                              },
                                      ),
                                    ),
                                  ],
                                ),
                              if (profilePending) const SizedBox(height: 14),
                              if (listKos.isNotEmpty) ...[
                                const Text("Detail Fasilitas & Kost:", 
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF9C5A1A))),
                                const Divider(),
                                ...listKos.map((k) {
                                  final String kostId = k['id'].toString();
                                  final bool isApprovingKost = approvingKostIds.contains(kostId);
                                  final bool isRejectingKost = rejectingKostIds.contains(kostId);
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8F2E8),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: const Color(0xFFEADBC9)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(k['name'] ?? 'Nama Kost', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                                        const SizedBox(height: 5),
                                        Row(
                                          children: [
                                            const Icon(Icons.location_on, size: 16, color: Colors.grey),
                                            const SizedBox(width: 5),
                                            Expanded(child: Text(k['address'] ?? 'Alamat tidak diisi', style: const TextStyle(fontSize: 12))),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
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
                                        Text("Harga: Rp ${k['price']} / Bulan", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFF9C5A1A),
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(vertical: 11),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                ),
                                                icon: isApprovingKost
                                                    ? const SizedBox(
                                                        width: 16,
                                                        height: 16,
                                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                                      )
                                                    : const Icon(Icons.check_circle),
                                                label: Text(isApprovingKost ? "MEMPROSES..." : "APPROVE KOS INI"),
                                                onPressed: (isApprovingKost || isRejectingKost) ? null : () => handleApproveKost(kostId),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: OutlinedButton.icon(
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: Colors.redAccent,
                                                  side: const BorderSide(color: Colors.redAccent),
                                                  padding: const EdgeInsets.symmetric(vertical: 11),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                ),
                                                icon: isRejectingKost
                                                    ? const SizedBox(
                                                        width: 16,
                                                        height: 16,
                                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent),
                                                      )
                                                    : const Icon(Icons.close),
                                                label: Text(isRejectingKost ? "MEMPROSES..." : "TOLAK KOS INI"),
                                                onPressed: (isApprovingKost || isRejectingKost)
                                                    ? null
                                                    : () async {
                                                        final ok = await _confirmReject(
                                                          "Tolak Kos",
                                                          "Kos ini akan dihapus dari antrean pendaftaran. Lanjutkan?",
                                                        );
                                                        if (ok) handleRejectKost(kostId);
                                                      },
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                              if (!profilePending && listKos.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.only(top: 4, bottom: 8),
                                  child: Text("Tidak ada item yang perlu di-approve"),
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
