import 'package:flutter/material.dart';
import 'package:kostly_pa/services/supabase_service.dart';
import 'package:intl/intl.dart';

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
  String? adminEmail; // Variabel untuk menyimpan email admin

  // State untuk loading per button
  final Set<String> approvingOwnerIds = {};
  final Set<String> approvingKostIds = {};
  final Set<String> rejectingOwnerIds = {};
  final Set<String> rejectingKostIds = {};

  @override
  void initState() {
    super.initState();
    // Mengambil email admin yang sedang login
    adminEmail = supabase.auth.currentUser?.email;
    fetchOwners();
  }

  Future<void> fetchOwners() async {
    try {
      if (mounted) setState(() => isLoading = true);

      // 1) Owner yang akunnya masih pending
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

      // 3) Ambil owner dari kos pending
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

  // --- LOGIC HANDLERS ---

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
      await supabase.from('profiles').update({'role': 'user', 'is_approved': true}).eq('id', userId);
      await supabase.from('kosts').delete().eq('owner_id', userId).eq('is_approved', false);
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
    return Scaffold(
      backgroundColor: const Color(0xFFFDF7F0),
      appBar: AppBar(
        title: const Text("Approval Owner", 
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        foregroundColor: const Color(0xFF4A3428),
        leading: widget.onBack != null 
          ? IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 20), onPressed: widget.onBack) 
          : null,
      ),
      body: isLoading 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF9C5A1A)))
          : Column(
              children: [
                _buildAdminHeader(), // Memanggil Header Admin
                Expanded(
                  child: owners.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                          itemCount: owners.length,
                          itemBuilder: (context, i) => _buildOwnerCard(owners[i]),
                        ),
                ),
              ],
            ),
    );
  }

  // --- WIDGET COMPONENTS ---

  Widget _buildAdminHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 45, height: 45,
            decoration: const BoxDecoration(color: Color(0xFF9C5A1A), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: const Text("A", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Administrator", style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500)),
                Text(adminEmail ?? "admin@gmail.com", 
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF4A3428))),
              ],
            ),
          ),
          IconButton(
            onPressed: () => supabase.auth.signOut(),
            icon: const Icon(Icons.power_settings_new_rounded, color: Colors.redAccent, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: Colors.brown.withOpacity(0.3)),
          const SizedBox(height: 16),
          const Text("Tidak ada antrean approval", style: TextStyle(color: Colors.brown, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildOwnerCard(Map<String, dynamic> item) {
    final List listKos = item['kosts'] ?? [];
    final String ownerId = item['id'].toString();
    final bool profilePending = item['is_approved'] == false;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.brown.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          title: Text(item['full_name'] ?? item['email'] ?? 'Tanpa Nama', 
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Color(0xFF4A3428))),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item['email'] ?? '-', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _buildStatusChip(
                    profilePending ? "Owner Pending" : "Owner Aktif",
                    profilePending ? const Color(0xFFFFE9CC) : const Color(0xFFE7F5EA),
                    profilePending ? const Color(0xFF9C5A1A) : const Color(0xFF2F8F46),
                  ),
                  Text(listKos.isNotEmpty ? "• ${listKos.length} Unit Kos" : "• Verifikasi Akun", 
                    style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ),
            ],
          ),
          children: [
            const Divider(height: 30),
            if (profilePending) ...[
              _buildActionButtons(
                context: context,
                onApprove: () => handleApproveOwner(ownerId),
                onReject: () async {
                  if (await _confirmReject("Tolak Owner", "Owner akan ditolak dan unit kos dihapus.")) handleRejectOwner(ownerId);
                },
                isApproving: approvingOwnerIds.contains(ownerId),
                isRejecting: rejectingOwnerIds.contains(ownerId),
                approveLabel: "APPROVE OWNER",
                rejectLabel: "TOLAK",
              ),
              const SizedBox(height: 20),
            ],
            if (listKos.isNotEmpty) ...[
              const Row(
                children: [
                  Icon(Icons.home_work_outlined, size: 18, color: Color(0xFF9C5A1A)),
                  SizedBox(width: 8),
                  Text("DETAIL UNIT KOS", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1, color: Color(0xFF9C5A1A))),
                ],
              ),
              const SizedBox(height: 12),
              ...listKos.map((k) => _buildKostItem(k)),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildKostItem(Map<String, dynamic> k) {
    final String kostId = k['id'].toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFCFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0E5D8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k['name'] ?? 'Nama Kost', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          Text(k['address'] ?? 'Alamat tidak diisi', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 12),
          Text("Rp ${NumberFormat.decimalPattern('id').format(k['price'] ?? 0)} / Bulan", 
            style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF2F8F46))),
          const SizedBox(height: 16),
          _buildActionButtons(
            context: context,
            onApprove: () => handleApproveKost(kostId),
            onReject: () async {
              if (await _confirmReject("Tolak Kos", "Kos ini akan dihapus.")) handleRejectKost(kostId);
            },
            isApproving: approvingKostIds.contains(kostId),
            isRejecting: rejectingKostIds.contains(kostId),
            approveLabel: "APPROVE KOS",
            rejectLabel: "TOLAK",
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons({
    required BuildContext context,
    required VoidCallback onApprove,
    required VoidCallback onReject,
    required bool isApproving,
    required bool isRejecting,
    required String approveLabel,
    required String rejectLabel,
  }) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9C5A1A), foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: (isApproving || isRejecting) ? null : onApprove,
            child: isApproving 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(approveLabel, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 1,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent, side: const BorderSide(color: Color(0xFFFFEBEE)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: (isApproving || isRejecting) ? null : onReject,
            child: isRejecting
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent))
              : Text(rejectLabel, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String label, Color backColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: backColor, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }
}