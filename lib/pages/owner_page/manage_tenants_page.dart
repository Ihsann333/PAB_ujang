import 'package:flutter/material.dart';
import 'package:kostly_pa/services/supabase_service.dart';
import 'package:postgrest/src/postgrest_builder.dart';
import 'package:postgrest/src/types.dart';

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
      if (user == null) return;

      final myKosts = await supabase.from('kosts').select('id').eq('owner_id', user.id);
      final List ids = (myKosts as List).map((k) => k['id']).toList();

      if (ids.isEmpty) {
        if (mounted) setState(() { tenants = []; isLoading = false; });
        return;
      }

      final data = await supabase
          .from('profiles')
          .select()
          .filter('kost_id', 'in', '(${ids.join(',')})');

      if (mounted) {
        setState(() {
          tenants = data as List;
          isLoading = false;
        });
      }
    } catch (e) {
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
          SnackBar(content: Text(isApproved ? "Berhasil diproses" : "Permintaan ditolak"))
        );
        fetchTenants();
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2E8DA),
      appBar: AppBar(
        title: const Text("Manajemen Penghuni", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF9C5A1A),
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF9C5A1A)))
          : tenants.isEmpty
              ? const Center(child: Text("Belum ada penghuni aktif."))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: tenants.length,
                  itemBuilder: (context, index) {
                    final t = tenants[index];
                    final bool isRequesting = t['exit_request'] ?? false;
                    final String tenantName = (t['full_name']?.toString().trim().isNotEmpty ?? false)
                        ? t['full_name'].toString().trim()
                        : (t['email']?.toString().split('@')[0] ?? 'User');

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: isRequesting ? Colors.orange[50] : Colors.white,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isRequesting ? Colors.orange : const Color(0xFF9C5A1A),
                          child: const Icon(Icons.person, color: Colors.white),
                        ),
                        title: Text(tenantName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(isRequesting ? "⚠️ Ingin keluar kos" : "Status: Aktif"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isRequesting) ...[
                              IconButton(icon: const Icon(Icons.check_circle, color: Colors.green), onPressed: () => handleUserExit(t['id'], isApproved: true)),
                              IconButton(icon: const Icon(Icons.cancel, color: Colors.red), onPressed: () => handleUserExit(t['id'], isApproved: false)),
                            ] else
                              IconButton(icon: const Icon(Icons.person_remove, color: Colors.redAccent), onPressed: () => _showKickConfirm(t['id'], tenantName)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  void _showKickConfirm(String userId, String? tenantName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Kick Penghuni?"),
        content: Text("Keluarkan ${tenantName ?? 'user'} sekarang?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              handleUserExit(userId, isApproved: true);
            },
            child: const Text("Ya, Kick", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

extension on PostgrestFilterBuilder<PostgrestList> {
}
