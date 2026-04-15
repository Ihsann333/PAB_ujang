import 'package:flutter/material.dart';
import 'package:kostly_pa/services/supabase_service.dart';
import 'manage_tenants_page.dart';
import 'dart:math';

class OwnerProfilePage extends StatefulWidget {
  const OwnerProfilePage({super.key});

  @override
  State<OwnerProfilePage> createState() => _OwnerProfilePageState();
}

class _OwnerProfilePageState extends State<OwnerProfilePage> {
  final supabase = SupabaseService.client;

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();
  final TextEditingController _priceCtrl = TextEditingController();
  final TextEditingController _slotsCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();

  bool isSaving = false;
  bool _includeListrik = false;
  bool _includeAir = false;
  bool _includeWifi = false;
  Map<String, dynamic>? ownerProfile;

  String _generateJoinCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random();
    return String.fromCharCodes(
      Iterable.generate(6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchOwnerProfile();
  }

  Future<void> _fetchOwnerProfile() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final data = await supabase.from('profiles').select().eq('id', user.id).single();
      if (mounted) {
        setState(() {
          ownerProfile = Map<String, dynamic>.from(data);
        });
      }
    } catch (_) {}
  }

  void _showAddKostDialog() {
    showDialog(
      context: context,
      barrierDismissible: !isSaving,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Daftarkan Unit Kos Baru", 
            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF9C5A1A))),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildField(_nameCtrl, "Nama Kos", Icons.home, "Contoh: Kostly Residence"),
                const SizedBox(height: 12),
                _buildField(_addressCtrl, "Alamat Lengkap", Icons.location_on, "Jl. Merdeka No. 123"),
                const SizedBox(height: 12),
                _buildField(_priceCtrl, "Harga per Bulan", Icons.payments, "1500000", isNumber: true),
                const SizedBox(height: 12),
                _buildField(_slotsCtrl, "Total Kamar", Icons.meeting_room, "Contoh: 12", isNumber: true),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text("Termasuk Listrik", style: TextStyle(fontSize: 14)),
                  value: _includeListrik,
                  activeThumbColor: const Color(0xFF9C5A1A),
                  onChanged: (val) => setModalState(() => _includeListrik = val),
                ),
                SwitchListTile(
                  title: const Text("Termasuk Air", style: TextStyle(fontSize: 14)),
                  value: _includeAir,
                  activeThumbColor: const Color(0xFF9C5A1A),
                  onChanged: (val) => setModalState(() => _includeAir = val),
                ),
                SwitchListTile(
                  title: const Text("Termasuk WiFi", style: TextStyle(fontSize: 14)),
                  value: _includeWifi,
                  activeThumbColor: const Color(0xFF9C5A1A),
                  onChanged: (val) => setModalState(() => _includeWifi = val),
                ),
                const SizedBox(height: 12),
                _buildField(_descCtrl, "Deskripsi kos", Icons.description, "AC, WiFi, dll", maxLines: 3),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(context),
              child: const Text("Batal"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9C5A1A),
                foregroundColor: Colors.white,
              ),
              onPressed: isSaving ? null : () => _saveNewKost(setModalState),
              child: Text(isSaving ? "Memproses..." : "Daftarkan Kos"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String label, IconData icon, String hint, {bool isNumber = false, int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF9C5A1A)),
        filled: true,
        fillColor: const Color(0xFFF5F0EA),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  Future<void> _saveNewKost(StateSetter setModalState) async {
    if (_nameCtrl.text.isEmpty || _addressCtrl.text.isEmpty || _priceCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mohon lengkapi data utama")));
      return;
    }

    setModalState(() => isSaving = true);

    try {
      final basePayload = {
        'owner_id': supabase.auth.currentUser?.id,
        'name': _nameCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'price': int.tryParse(_priceCtrl.text.trim()) ?? 0,
        'slots': int.tryParse(_slotsCtrl.text.trim()) ?? 0,
        'include_electricity': _includeListrik,
        'include_water': _includeAir,
        'include_wifi': _includeWifi,
        'join_code': _generateJoinCode(),
        'is_approved': false,
        'created_at': DateTime.now().toIso8601String(),
      };

      bool inserted = false;
      Object? lastError;

      // Coba dengan kolom description (jika ada di skema)
      try {
        await supabase.from('kosts').insert({
          ...basePayload,
          'description': _descCtrl.text.trim(),
        });
        inserted = true;
      } catch (e) {
        lastError = e;
      }

      // Fallback tanpa description (untuk skema yang belum punya kolom ini)
      if (!inserted) {
        try {
          await supabase.from('kosts').insert(basePayload);
          inserted = true;
        } catch (e) {
          lastError = e;
        }
      }

      if (!inserted) {
        throw Exception(lastError?.toString() ?? "Gagal menyimpan data kost");
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Unit berhasil diajukan ke admin!"), backgroundColor: Colors.green),
        );
      }
      _nameCtrl.clear();
      _addressCtrl.clear();
      _priceCtrl.clear();
      _slotsCtrl.clear();
      _descCtrl.clear();
      setState(() {
        _includeListrik = false;
        _includeAir = false;
        _includeWifi = false;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal: $e")));
    } finally {
      if (mounted) setModalState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2E8DA),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleAvatar(radius: 50, backgroundColor: Color(0xFF9C5A1A), child: Icon(Icons.person, size: 50, color: Colors.white)),
            const SizedBox(height: 10),
            Text(
              ownerProfile?['full_name'] ?? supabase.auth.currentUser?.email ?? "Owner",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            
            // Tombol Navigasi ke Manajemen Penghuni
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9C5A1A),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                ),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OwnerManageTenantsPage())),
                icon: const Icon(Icons.people),
                label: const Text("Kelola Penghuni", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF9C5A1A),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                ),
                onPressed: _showAddKostDialog,
                icon: const Icon(Icons.add_business),
                label: const Text("Tambah Unit Kos Baru", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () async {
                await supabase.auth.signOut();
                if (mounted) Navigator.pushReplacementNamed(context, '/');
              },
              child: const Text("Logout", style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _priceCtrl.dispose();
    _slotsCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }
}
