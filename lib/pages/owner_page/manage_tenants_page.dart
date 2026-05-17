import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kostly_pa/services/supabase_service.dart';

class OwnerManageTenantsPage extends StatefulWidget {
  const OwnerManageTenantsPage({
    super.key,
    this.initialShowExitRequests = false,
  });

  final bool initialShowExitRequests;

  @override
  State<OwnerManageTenantsPage> createState() => _OwnerManageTenantsPageState();
}

class _OwnerManageTenantsPageState extends State<OwnerManageTenantsPage> {
  final supabase = SupabaseService.client;
  List tenants = [];
  bool isLoading = true;
  bool _showExitRequestsFirst = false;

  @override
  void initState() {
    super.initState();
    _showExitRequestsFirst = widget.initialShowExitRequests;
    fetchTenants();
  }

  Future<void> fetchTenants() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => isLoading = false);
        return;
      }

      // 1. Ambil ID kost milik owner ini
      final myKosts = await supabase
          .from('kosts')
          .select('id')
          .eq('owner_id', user.id);
      final List ids = (myKosts as List).map((k) => k['id']).toList();

      if (ids.isEmpty) {
        if (mounted) {
          setState(() {
            tenants = [];
            isLoading = false;
          });
        }
        return;
      }

      // 2. QUERY PERBAIKAN: Gunakan format select yang lebih eksplisit
      // Kita ambil data profile dan join ke tabel kosts
      final data = await supabase
          .from('profiles')
          .select('''
            *,
            kosts:kost_id (
              name
            )
          ''')
          .inFilter('kost_id', ids);

      if (mounted) {
        setState(() {
          tenants = List<Map<String, dynamic>>.from(data as List);
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetch: $e'); // Cek error di konsol kalau masih kosong
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> handleUserExit(String userId, {required bool isApproved}) async {
    try {
      Map<String, dynamic> updateData = isApproved
          ? {'kost_id': null, 'exit_request': false}
          : {'exit_request': false};

      await supabase.from('profiles').update(updateData).eq('id', userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isApproved
                  ? 'Permintaan keluar berhasil disetujui.'
                  : 'Permintaan keluar berhasil ditolak.',
            ),
          ),
        );
      }
      await fetchTenants();
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final exitRequests = tenants
        .where((tenant) => tenant['exit_request'] == true)
        .toList();
    final activeTenants = tenants
        .where((tenant) => tenant['exit_request'] != true)
        .toList();
    final sections = _showExitRequestsFirst
        ? [exitRequests, activeTenants]
        : [activeTenants, exitRequests];

    return Scaffold(
      backgroundColor: const Color(0xFFF2E8DA),
      appBar: AppBar(
        title: Text(
          'Manajemen Penghuni',
          style: GoogleFonts.sora(fontWeight: FontWeight.w700),
        ),
        backgroundColor: const Color(0xFF9C5A1A),
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF9C5A1A)),
            )
          : tenants.isEmpty
          ? Center(
              child: Text(
                'Belum ada penghuni yang terhubung ke kost Anda.',
                style: GoogleFonts.plusJakartaSans(),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSummaryCard(
                  totalTenants: tenants.length,
                  exitRequestCount: exitRequests.length,
                ),
                const SizedBox(height: 18),
                for (final section in sections) ...[
                  if (identical(section, exitRequests))
                    _buildTenantSection(
                      title: 'Permintaan Keluar',
                      subtitle:
                          'ACC atau tolak penghuni yang ingin keluar dari kost.',
                      tenants: exitRequests,
                      emptyLabel:
                          'Belum ada penghuni yang mengajukan keluar kost.',
                      isExitSection: true,
                    ),
                  if (identical(section, activeTenants))
                    _buildTenantSection(
                      title: 'Penghuni Aktif',
                      subtitle: 'Daftar penghuni yang saat ini masih menempati kost.',
                      tenants: activeTenants,
                      emptyLabel: 'Belum ada penghuni aktif.',
                      isExitSection: false,
                    ),
                  const SizedBox(height: 18),
                ],
              ],
            ),
    );
  }

  Widget _buildSummaryCard({
    required int totalTenants,
    required int exitRequestCount,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9D7C2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryItem(
              label: 'Total Penghuni',
              value: totalTenants.toString(),
              color: const Color(0xFF9C5A1A),
              icon: Icons.people_alt_rounded,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSummaryItem(
              label: 'Minta Keluar',
              value: exitRequestCount.toString(),
              color: const Color(0xFFDD8A18),
              icon: Icons.logout_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.sora(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF2D241A),
            ),
          ),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: const Color(0xFF6B6257),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTenantSection({
    required String title,
    required String subtitle,
    required List tenants,
    required String emptyLabel,
    required bool isExitSection,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.sora(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF2D241A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: const Color(0xFF6B6257),
          ),
        ),
        const SizedBox(height: 12),
        if (tenants.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE9D7C2)),
            ),
            child: Text(
              emptyLabel,
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF6B6257),
              ),
            ),
          )
        else
          ...tenants.map((tenant) => _buildTenantCard(tenant, isExitSection)),
      ],
    );
  }

  Widget _buildTenantCard(Map tenant, bool isExitSection) {
    final bool isRequesting = tenant['exit_request'] == true;
    final String kostName = tenant['kosts']?['name'] ?? 'Kost tidak diketahui';
    final String tenantName =
        (tenant['full_name']?.toString().trim().isNotEmpty ?? false)
        ? tenant['full_name'].toString().trim()
        : (tenant['email']?.toString().split('@')[0] ?? 'User');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isRequesting ? Colors.orange[50] : Colors.white,
      child: ListTile(
        onTap: () => _showTenantInfoPopup(tenant),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: isRequesting
              ? Colors.orange
              : const Color(0xFF9C5A1A),
          child: const Icon(Icons.person, color: Colors.white),
        ),
        title: Text(
          tenantName,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.home_work_rounded,
                  size: 14,
                  color: Color(0xFF9C5A1A),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    kostName,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: const Color(0xFF9C5A1A),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              isRequesting ? 'Mengajukan keluar kost' : 'Status: Aktif',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: isRequesting ? Colors.orange[900] : Colors.grey[600],
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isExitSection) ...[
              IconButton(
                tooltip: 'Setujui keluar',
                icon: const Icon(Icons.check_circle, color: Colors.green),
                onPressed: () => handleUserExit(tenant['id'], isApproved: true),
              ),
              IconButton(
                tooltip: 'Tolak permintaan',
                icon: const Icon(Icons.cancel, color: Colors.red),
                onPressed: () => handleUserExit(tenant['id'], isApproved: false),
              ),
            ] else
              IconButton(
                tooltip: 'Keluarkan penghuni',
                icon: const Icon(Icons.person_remove, color: Colors.redAccent),
                onPressed: () => _showKickConfirm(tenant['id'], tenantName),
              ),
          ],
        ),
      ),
    );
  }

  void _showTenantInfoPopup(Map tenant) {
    final String name = (tenant['full_name']?.toString().trim().isNotEmpty ?? false)
        ? tenant['full_name'].toString().trim()
        : '-';
    final String phone = (tenant['phone_number']?.toString().trim().isNotEmpty ?? false)
        ? tenant['phone_number'].toString().trim()
        : '-';
    final String email = (tenant['email']?.toString().trim().isNotEmpty ?? false)
        ? tenant['email'].toString().trim()
        : '-';
    
    // Ambil nama kost untuk di popup
    final String kostName = tenant['kosts']?['name'] ?? '-';
    
    final String status = tenant['exit_request'] == true ? 'Mengajukan Keluar' : 'Aktif';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 22),
        contentPadding: EdgeInsets.zero,
        content: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: const Color(0xFFFFFBF5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF5A3A17).withOpacity(0.16),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFC68A4B), Color(0xFFAD7238)],
                  ),
                ),
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 28,
                      backgroundColor: Color(0xFFF1D5B2),
                      child: Icon(Icons.person, size: 28, color: Color(0xFF9C5A1A)),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Informasi Penghuni',
                      style: GoogleFonts.sora(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                child: Column(
                  children: [
                    _buildInfoItem('Nama Pengguna', name),
                    const SizedBox(height: 10),
                    // ITEM INFO BARU: UNIT KOST
                    _buildInfoItem('Unit Kost', kostName), 
                    const SizedBox(height: 10),
                    _buildInfoItem('Nomor Pengguna', phone),
                    const SizedBox(height: 10),
                    _buildInfoItem('Email', email),
                    const SizedBox(height: 10),
                    _buildInfoItem('Status', status),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFFF3E3CF),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Tutup',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF9C5A1A),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFF8EFE3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE9D7C2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: const Color(0xFF8E8E8E),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              color: const Color(0xFF2A221B),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  void _showKickConfirm(String userId, String? tenantName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFFFBF7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Kick Penghuni?', style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
        content: Text(
          'Keluarkan ${tenantName ?? 'user'} sekarang?',
          style: GoogleFonts.plusJakartaSans(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              handleUserExit(userId, isApproved: true);
            },
            child: Text(
              'Ya, Kick',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
