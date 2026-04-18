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

  // Controllers untuk Form Kost
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();
  final TextEditingController _priceCtrl = TextEditingController();
  final TextEditingController _slotsCtrl = TextEditingController();
  final TextEditingController _rulesCtrl = TextEditingController();
  
  // Controllers untuk Kelola Akun
  final TextEditingController _oldPasswordCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();

  bool isSaving = false;
  bool _includeListrik = false;
  bool _includeAir = false;
  bool _includeWifi = false;
  bool _showOldPass = false;
  bool _showNewPass = false;
  Map<String, dynamic>? ownerProfile;

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
    _oldPasswordCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // --- LOGIKA DATA ---

  Future<void> _fetchOwnerProfile() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final data = await supabase.from('profiles').select().eq('id', user.id).single();
      if (mounted) setState(() => ownerProfile = Map<String, dynamic>.from(data));
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
    if (_oldPasswordCtrl.text.isEmpty || _passwordCtrl.text.isEmpty) {
      _showSnackBar("Mohon isi semua kolom", Colors.orange);
      return;
    }
    try {
      // Validasi password lama dengan re-auth
      await supabase.auth.signInWithPassword(email: userEmail, password: _oldPasswordCtrl.text.trim());
      // Update ke password baru
      await supabase.auth.updateUser(UserAttributes(password: _passwordCtrl.text.trim()));
      
      if (mounted) {
        Navigator.pop(context);
        _showSnackBar("Password berhasil diperbarui!", Colors.green);
        _oldPasswordCtrl.clear();
        _passwordCtrl.clear();
      }
    } catch (e) {
      _showSnackBar("Gagal: Password lama salah", Colors.red);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  Future<void> _saveNewKost(StateSetter setModalState) async {
    if (_nameCtrl.text.isEmpty || _addressCtrl.text.isEmpty || _priceCtrl.text.isEmpty) {
      _showSnackBar("Mohon lengkapi data utama", Colors.orange);
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
        _showSnackBar("Unit berhasil diajukan!", Colors.green);
        _clearKostForm();
      }
    } catch (e) {
      _showSnackBar("Gagal simpan kost: $e", Colors.red);
    } finally {
      if (mounted) setModalState(() => isSaving = false);
    }
  }

  void _clearKostForm() {
    _nameCtrl.clear(); _addressCtrl.clear(); _priceCtrl.clear(); _slotsCtrl.clear(); _rulesCtrl.clear();
    setState(() { _includeListrik = false; _includeAir = false; _includeWifi = false; });
  }

  // --- UI COMPONENTS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBFA),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 70), // Jarak karena avatar floating
            _buildAccountSection(),
            const SizedBox(height: 24),
            _buildActionSection(),
            const SizedBox(height: 40),
            _buildLogoutButton(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 180,
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF9C5A1A), Color(0xFF633A11)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)),
          ),
        ),
        Positioned(
          bottom: -50,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const CircleAvatar(
                  radius: 50, backgroundColor: Color(0xFFEFE6DD),
                  child: Icon(Icons.person_rounded, size: 55, color: Color(0xFF9C5A1A)),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                ownerProfile?['full_name'] ?? "Owner Kostly",
                style: GoogleFonts.sora(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF2D241A)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAccountSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("PENGATURAN AKUN", style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 1.2)),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 8))],
            ),
            child: Column(
              children: [
                _buildInfoTile(Icons.alternate_email_rounded, "Email", userEmail),
                Divider(height: 1, color: Colors.grey.shade100, indent: 60),
                _buildInfoTile(Icons.lock_person_rounded, "Keamanan Password", "••••••••", onTap: _showPasswordDialog),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String title, String value, {VoidCallback? onTap}) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: const Color(0xFFFDF3E7), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: const Color(0xFF9C5A1A), size: 20),
      ),
      title: Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey.shade600)),
      subtitle: Text(value, style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF2D241A))),
      trailing: onTap != null ? const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey) : null,
    );
  }

  Widget _buildActionSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          _buildMenuButton("Kelola Penghuni", "Atur penyewa aktif", Icons.people_alt_rounded, const Color(0xFF9C5A1A), 
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OwnerManageTenantsPage()))),
          const SizedBox(height: 12),
          _buildMenuButton("Tambah Unit Baru", "Daftarkan properti kost", Icons.add_business_rounded, const Color(0xFF2D241A), 
            _showAddKostDialog),
        ],
      ),
    );
  }

  Widget _buildMenuButton(String title, String sub, IconData icon, Color color, VoidCallback press) {
    return InkWell(
      onTap: press,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color, borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: color.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: GoogleFonts.sora(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                Text(sub, style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 11)),
              ]),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return TextButton.icon(
      onPressed: () async {
        await supabase.auth.signOut();
        if (mounted) Navigator.pushReplacementNamed(context, '/');
      },
      icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 18),
      label: Text("Logout Akun", style: GoogleFonts.plusJakartaSans(color: Colors.redAccent, fontWeight: FontWeight.bold)),
    );
  }

  // --- DIALOGS ---

  void _showPasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModal) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text("Ubah Password", style: GoogleFonts.sora(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildModernField(_oldPasswordCtrl, "Password Saat Ini", Icons.lock_open, isPass: true, show: _showOldPass, 
                onToggle: () => setModal(() => _showOldPass = !_showOldPass)),
              const SizedBox(height: 12),
              _buildModernField(_passwordCtrl, "Password Baru", Icons.lock_outline, isPass: true, show: _showNewPass, 
                onToggle: () => setModal(() => _showNewPass = !_showNewPass)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
            ElevatedButton(
              onPressed: _updatePassword,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9C5A1A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: const Text("Update", style: TextStyle(color: Colors.white)),
            )
          ],
        ),
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
          title: Text("Daftar Unit Kost", style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: const Color(0xFF9C5A1A))),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildModernField(_nameCtrl, "Nama Kost", Icons.home),
                const SizedBox(height: 12),
                _buildModernField(_addressCtrl, "Alamat", Icons.location_on),
                const SizedBox(height: 12),
                _buildModernField(_priceCtrl, "Harga", Icons.payments, isNum: true),
                const SizedBox(height: 12),
                _buildModernField(_slotsCtrl, "Total Kamar", Icons.meeting_room, isNum: true),
                const SizedBox(height: 12),
                _buildSwitchTile("Listrik", _includeListrik, (v) => setModalState(() => _includeListrik = v)),
                _buildSwitchTile("Air", _includeAir, (v) => setModalState(() => _includeAir = v)),
                _buildSwitchTile("WiFi", _includeWifi, (v) => setModalState(() => _includeWifi = v)),
                const SizedBox(height: 12),
                _buildModernField(_rulesCtrl, "Aturan", Icons.description, maxL: 3),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9C5A1A)),
              onPressed: isSaving ? null : () => _saveNewKost(setModalState),
              child: Text(isSaving ? "..." : "Simpan", style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernField(TextEditingController ctrl, String label, IconData icon, {bool isPass = false, bool? show, VoidCallback? onToggle, bool isNum = false, int maxL = 1}) {
    return TextField(
      controller: ctrl,
      obscureText: isPass ? !(show ?? false) : false,
      keyboardType: isNum ? TextInputType.number : TextInputType.text,
      maxLines: maxL,
      decoration: InputDecoration(
        labelText: label, prefixIcon: Icon(icon, size: 20, color: const Color(0xFF9C5A1A)),
        suffixIcon: isPass ? IconButton(icon: Icon((show ?? false) ? Icons.visibility : Icons.visibility_off, size: 18), onPressed: onToggle) : null,
        filled: true, fillColor: const Color(0xFFF5F0EA),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildSwitchTile(String t, bool v, Function(bool) c) {
    return SwitchListTile(
      title: Text(t, style: GoogleFonts.plusJakartaSans(fontSize: 13)),
      value: v, dense: true, activeColor: const Color(0xFF9C5A1A), onChanged: c,
    );
  }
}