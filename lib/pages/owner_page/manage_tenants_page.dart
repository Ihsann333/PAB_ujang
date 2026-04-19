import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kostly_pa/services/supabase_service.dart';

class OwnerManageTenantsPage extends StatefulWidget {
  const OwnerManageTenantsPage({super.key});

  @override
  State<OwnerManageTenantsPage> createState() => _OwnerManageTenantsPageState();
}

class _OwnerManageTenantsPageState extends State<OwnerManageTenantsPage> {
  final supabase = SupabaseService.client;
  List tenants = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
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
      final myKosts = await supabase.from('kosts').select('id').eq('owner_id', user.id);
      final List ids = (myKosts as List).map((k) => k['id']).toList();

      if (ids.isEmpty) {
        if (mounted) setState(() { tenants = []; isLoading = false; });
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
          tenants = data as List;
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
          SnackBar(content: Text(isApproved ? 'Berhasil diproses' : 'Permintaan ditolak'))
        );
        fetchTenants();
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
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
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF9C5A1A)))
          : tenants.isEmpty
              ? Center(child: Text('Belum ada penghuni aktif.', style: GoogleFonts.plusJakartaSans()))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: tenants.length,
                  itemBuilder: (context, index) {
                    final t = tenants[index];
                    final bool isRequesting = t['exit_request'] ?? false;
                    
                    // Ambil nama kost dari hasil join
                    final String kostName = t['kosts']?['name'] ?? 'Kost Tidak Diketahui';
                    
                    final String tenantName = (t['full_name']?.toString().trim().isNotEmpty ?? false)
                        ? t['full_name'].toString().trim()
                        : (t['email']?.toString().split('@')[0] ?? 'User');

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      color: isRequesting ? Colors.orange[50] : Colors.white,
                      child: ListTile(
                        onTap: () => _showTenantInfoPopup(t),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: isRequesting ? Colors.orange : const Color(0xFF9C5A1A),
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
                            // INFO UNIT KOS DI LIST
                            Row(
                              children: [
                                const Icon(Icons.home_work_rounded, size: 14, color: Color(0xFF9C5A1A)),
                                const SizedBox(width: 4),
                                Text(
                                  kostName,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                    color: const Color(0xFF9C5A1A),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isRequesting ? 'Ingin keluar kost' : 'Status: Aktif',
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
                            if (isRequesting) ...[
                              IconButton(
                                icon: const Icon(Icons.check_circle, color: Colors.green), 
                                onPressed: () => handleUserExit(t['id'], isApproved: true)
                              ),
                              IconButton(
                                icon: const Icon(Icons.cancel, color: Colors.red), 
                                onPressed: () => handleUserExit(t['id'], isApproved: false)
                              ),
                            ] else
                              IconButton(
                                icon: const Icon(Icons.person_remove, color: Colors.redAccent), 
                                onPressed: () => _showKickConfirm(t['id'], tenantName)
                              ),
                          ],
                        ),
                      ),
                    );
                  },
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