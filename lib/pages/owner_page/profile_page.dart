import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kostly_pa/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'manage_tenants_page.dart';
import 'dart:math';

class OwnerProfilePage extends StatefulWidget {
  const OwnerProfilePage({super.key});

  @override
  State<OwnerProfilePage> createState() => _OwnerProfilePageState();
}

class _OwnerProfilePageState extends State<OwnerProfilePage> {
  final supabase = SupabaseService.client;

  // Controller untuk Form Kost
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();
  final TextEditingController _priceCtrl = TextEditingController();
  final TextEditingController _slotsCtrl = TextEditingController();
  final TextEditingController _rulesCtrl = TextEditingController();
  
  // Controller untuk Kelola Akun
  final TextEditingController _passwordCtrl = TextEditingController();

  bool isSaving = false;
  bool _includeListrik = false;
  bool _includeAir = false;
  bool _includeWifi = false;
  Map<String, dynamic>? ownerProfile;

  // Ambil email dari Auth Supabase
  String get userEmail => supabase.auth.currentUser?.email ?? 'Email tidak ditemukan';

  @override
  void initState() {
    super.initState();
    _fetchOwnerProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _priceCtrl.dispose();
    _slotsCtrl.dispose();
    _rulesCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // --- LOGIKA DATA ---

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

  String _generateJoinCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random();
    return String.fromCharCodes(
      Iterable.generate(6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
    );
  }

  Future<void> _updatePassword() async {
    if (_passwordCtrl.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password minimal 6 karakter"), backgroundColor: Colors.orange)
      );
      return;
    }

    try {
      await supabase.auth.updateUser(UserAttributes(password: _passwordCtrl.text.trim()));
      if (mounted) {
        _passwordCtrl.clear();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Password berhasil diperbarui!"), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal: $e"), backgroundColor: Colors.red));
    }
  }

  Future<void> _saveNewKost(StateSetter setModalState) async {
    if (_nameCtrl.text.isEmpty || _addressCtrl.text.isEmpty || _priceCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mohon lengkapi data utama")));
      return;
    }

    setModalState(() => isSaving = true);

    try {
      await supabase.from('kosts').insert({
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
        'rules': _rulesCtrl.text.trim(),
        'created_at': DateTime.now().toIso8601String(),
      });

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
      _rulesCtrl.clear();
      setState(() {
        _includeListrik = false;
        _includeAir = false;
        _includeWifi = false;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setModalState(() => isSaving = false);
    }
  }

  // --- UI DIALOGS ---

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFFFBF7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Ubah Password", style: GoogleFonts.sora(fontWeight: FontWeight.bold, color: const Color(0xFF9C5A1A))),
        content: TextField(
          controller: _passwordCtrl,
          obscureText: true,
          decoration: InputDecoration(
            labelText: "Password Baru",
            filled: true,
            fillColor: const Color(0xFFF5F0EA),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          ElevatedButton(
            onPressed: _updatePassword,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9C5A1A)),
            child: const Text("Simpan", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddKostDialog() {
    showDialog(
      context: context,
      barrierDismissible: !isSaving,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: const Color(0xFFFFFBF7),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          contentPadding: EdgeInsets.zero,
          title: Padding(
            padding: const EdgeInsets.only(top: 24, left: 24, right: 24),
            child: Text("Daftarkan Unit Kost", style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: const Color(0xFF9C5A1A), fontSize: 18)),
          ),
          content: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildField(_nameCtrl, "Nama Kost", Icons.home, "Contoh: Kostly Residence", isName: true),
                const SizedBox(height: 16),
                _buildField(_addressCtrl, "Alamat Lengkap", Icons.location_on, "Jl. Merdeka No. 123"),
                const SizedBox(height: 16),
                _buildField(_priceCtrl, "Harga per Bulan", Icons.payments, "1500000", isNumber: true),
                const SizedBox(height: 16),
                _buildField(_slotsCtrl, "Total Kamar", Icons.meeting_room, "Contoh: 12", isNumber: true),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(color: const Color(0xFFF5F0EA), borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    children: [
                      _buildSwitchTile("Termasuk Listrik", _includeListrik, (val) => setModalState(() => _includeListrik = val)),
                      _buildSwitchTile("Termasuk Air", _includeAir, (val) => setModalState(() => _includeAir = val)),
                      _buildSwitchTile("Termasuk WiFi", _includeWifi, (val) => setModalState(() => _includeWifi = val)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildField(_rulesCtrl, "Aturan Kost", Icons.description, "AC, WiFi, dll", maxLines: 3),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "Batal",
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9C5A1A), foregroundColor: Colors.white),
              onPressed: isSaving ? null : () => _saveNewKost(setModalState),
              child: Text(
                isSaving ? "Memproses..." : "Simpan",
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutConfirmation() {
    final pageContext = context;
    showDialog(
      context: pageContext,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFFFFFCF7),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
        contentPadding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
        actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFFFEFF1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.logout_rounded,
                size: 18,
                color: Color(0xFFE24D56),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              "Logout Akun",
              style: GoogleFonts.sora(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: const Color(0xFF2D241A),
              ),
            ),
          ],
        ),
        content: Text(
          "Yakin ingin keluar dari akun sekarang?",
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: const Color(0xFF6B6257),
            height: 1.35,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext, rootNavigator: true).pop(),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF7A6A58),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              "Batal",
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogContext, rootNavigator: true).pop();
              await supabase.auth.signOut();
              if (mounted) {
                Navigator.of(pageContext)
                    .pushNamedAndRemoveUntil('/', (route) => false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE24D56),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              "Logout",
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // --- BUILDER HELPERS ---

  Widget _buildField(TextEditingController ctrl, String label, IconData icon, String hint, {bool isNumber = false, bool isName = false, int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 15,
        color: const Color(0xFF3D3328),
      ),
      inputFormatters: [
        if (isName) FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s]')),
        if (isNumber) FilteringTextInputFormatter.digitsOnly,
      ],
      decoration: InputDecoration(
        labelText: label, hintText: hint,
        labelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          color: const Color(0xFF6B6257),
          fontWeight: FontWeight.w600,
        ),
        hintStyle: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          color: const Color(0xFF8A8074),
        ),
        prefixIcon: Icon(icon, size: 18, color: const Color(0xFF9C5A1A)),
        filled: true, fillColor: const Color(0xFFF5F0EA),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildSwitchTile(String title, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w500)),
      value: value, dense: true, activeColor: const Color(0xFF9C5A1A),
      onChanged: onChanged,
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {VoidCallback? onEdit}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF9C5A1A)),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 10, color: Colors.grey.shade600)),
            Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF3D3328))),
          ],
        ),
        const Spacer(),
        if (onEdit != null) IconButton(onPressed: onEdit, icon: const Icon(Icons.edit, size: 16, color: Color(0xFF9C5A1A))),
      ],
    );
  }

  // --- MAIN BUILD ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2E8DA),
      body: SingleChildScrollView(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 60),
          child: Column(
            children: [
              const CircleAvatar(
                radius: 50, backgroundColor: Color(0xFF9C5A1A), 
                child: Icon(Icons.person, size: 50, color: Colors.white)
              ),
              const SizedBox(height: 10),
              Text(
                ownerProfile?['full_name'] ?? "Owner",
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 28, color: const Color(0xFF2D241A)),
              ),
              const SizedBox(height: 25),

              // Account Management Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white)
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow(Icons.email_outlined, "Email Pengguna", userEmail),
                      const Divider(height: 20),
                      _buildInfoRow(Icons.lock_outline, "Password Akun", "••••••••", onEdit: _showChangePasswordDialog),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9C5A1A), foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                  ),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OwnerManageTenantsPage())),
                  icon: const Icon(Icons.people),
                  label: Text("Kelola Penghuni", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 12),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white, foregroundColor: const Color(0xFF9C5A1A),
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                  ),
                  onPressed: _showAddKostDialog,
                  icon: const Icon(Icons.add_business),
                  label: Text("Tambah Unit Kost Baru", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: _showLogoutConfirmation,
                child: Text("Logout Akun", style: GoogleFonts.plusJakartaSans(color: Colors.red, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
