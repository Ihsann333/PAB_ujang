import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kostly_pa/services/kost_location_service.dart';
import 'package:kostly_pa/services/media_service.dart';
import 'package:kostly_pa/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'manage_tenants_page.dart';
import 'owner_ui.dart';
import 'dart:math';
import 'dart:typed_data';

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
  List<Map<String, dynamic>> ownerKosts = [];
  Uint8List? _newKostPhotoBytes;
  String? _newKostPhotoName;
  KostLocationData? _newKostLocation;
  bool isLoading = true;

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
      if (user == null) {
        if (mounted) setState(() => isLoading = false);
        return;
      }
      final data = await supabase.from('profiles').select().eq('id', user.id).single();
      final kosts = await supabase
          .from('kosts')
          .select()
          .eq('owner_id', user.id)
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          ownerProfile = Map<String, dynamic>.from(data);
          ownerKosts = (kosts as List)
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();
          isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => isLoading = false);
    }
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

  Future<void> _updateProfilePhoto() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final photo = await MediaService.pickImage(context);
      if (photo == null) return;

      final bytes = await photo.readAsBytes();
      final photoUrl = await MediaService.uploadImageBytes(
        bytes: bytes,
        bucket: 'kostly-media',
        folder: 'profiles/${user.id}',
        fileName:
            'owner_${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      await supabase.from('profiles').update({
        'profile_photo_url': photoUrl,
      }).eq('id', user.id);

      await _fetchOwnerProfile();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Foto profil berhasil diperbarui.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal memperbarui foto profil: $e")),
        );
      }
    }
  }

  Future<void> _updateKostPhoto() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    if (ownerKosts.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Belum ada kost yang bisa diubah fotonya."),
          ),
        );
      }
      return;
    }

    final selectedKostId = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        backgroundColor: const Color(0xFFFFFBF7),
        title: Text(
          "Pilih Kost",
          style: GoogleFonts.sora(fontWeight: FontWeight.w700),
        ),
        children: ownerKosts
            .map(
              (kost) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, kost['id'].toString()),
                child: Text(kost['name']?.toString() ?? 'Kost'),
              ),
            )
            .toList(),
      ),
    );

    if (selectedKostId == null) return;

    try {
      final photo = await MediaService.pickImage(context);
      if (photo == null) return;

      final bytes = await photo.readAsBytes();
      final photoUrl = await MediaService.uploadImageBytes(
        bytes: bytes,
        bucket: 'kostly-media',
        folder: 'kosts/$selectedKostId',
        fileName:
            'kost_${selectedKostId}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      await supabase.from('kosts').update({
        'photo_url': photoUrl,
      }).eq('id', selectedKostId);

      await _fetchOwnerProfile();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Foto kost berhasil diperbarui.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal memperbarui foto kost: $e")),
        );
      }
    }
  }

  Future<void> _updateKostLocation() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    if (ownerKosts.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Belum ada kost yang bisa diatur lokasinya."),
          ),
        );
      }
      return;
    }

    final selectedKostId = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        backgroundColor: const Color(0xFFFFFBF7),
        title: Text(
          "Pilih Kost",
          style: GoogleFonts.sora(fontWeight: FontWeight.w700),
        ),
        children: ownerKosts
            .map(
              (kost) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, kost['id'].toString()),
                child: Text(kost['name']?.toString() ?? 'Kost'),
              ),
            )
            .toList(),
      ),
    );

    if (selectedKostId == null) return;

    try {
      final location = await KostLocationService.getCurrentLocation();
      await KostLocationService.saveKostWithLocation(
        supabase: supabase,
        kostId: selectedKostId,
        basePayload: {},
        location: location,
      );

      await _fetchOwnerProfile();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Lokasi kost berhasil diperbarui.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal memperbarui lokasi kost: $e")),
        );
      }
    }
  }

  Future<void> _saveNewKost(StateSetter setModalState) async {
    if (_nameCtrl.text.isEmpty || _addressCtrl.text.isEmpty || _priceCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mohon lengkapi data utama")));
      return;
    }

    setModalState(() => isSaving = true);

    try {
      final kostPhotoUrl = _newKostPhotoBytes == null
          ? null
          : await MediaService.uploadImageBytes(
              bytes: _newKostPhotoBytes!,
              bucket: 'kostly-media',
              folder: 'kosts/${supabase.auth.currentUser?.id ?? 'unknown'}',
              fileName:
                  _newKostPhotoName ?? 'kost_${DateTime.now().millisecondsSinceEpoch}.jpg',
            );

      await KostLocationService.saveKostWithLocation(
        supabase: supabase,
        basePayload: {
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
          'photo_url': kostPhotoUrl,
          'created_at': DateTime.now().toIso8601String(),
        },
        location: _newKostLocation,
      );

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
      _newKostPhotoBytes = null;
      _newKostPhotoName = null;
      _newKostLocation = null;
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
    _newKostPhotoBytes = null;
    _newKostPhotoName = null;
    _newKostLocation = null;
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
                _buildPhotoPicker(
                  label: "Foto Kost",
                  bytes: _newKostPhotoBytes,
                  onTap: () async {
                    final photo = await MediaService.pickImage(context);
                    if (photo == null) return;
                    final bytes = await photo.readAsBytes();
                    setModalState(() {
                      _newKostPhotoBytes = bytes;
                      _newKostPhotoName = photo.name;
                    });
                  },
                ),
                const SizedBox(height: 16),
                _buildField(_nameCtrl, "Nama Kost", Icons.home, "Contoh: Kostly Residence", isName: true),
                const SizedBox(height: 16),
                _buildField(_addressCtrl, "Alamat Lengkap", Icons.location_on, "Jl. Merdeka No. 123"),
                const SizedBox(height: 16),
                _buildLocationPicker(
                  location: _newKostLocation,
                  onTap: () async {
                    try {
                      final location =
                          await KostLocationService.getCurrentLocation();
                      setModalState(() => _newKostLocation = location);
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            e.toString().replaceFirst('Exception: ', ''),
                          ),
                        ),
                      );
                    }
                  },
                ),
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
              "Keluar Dashboard Owner",
              style: GoogleFonts.sora(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: const Color(0xFF2D241A),
              ),
            ),
          ],
        ),
        content: Text(
          "Anda akan keluar dari panel pengelolaan kost. Semua data tetap tersimpan dan bisa dilanjutkan lagi saat login.",
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
              "Keluar Sekarang",
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

  Widget _buildPhotoPicker({
    required String label,
    required Uint8List? bytes,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F0EA),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFFEADBC9),
              backgroundImage: bytes != null ? MemoryImage(bytes) : null,
              child: bytes == null
                  ? const Icon(
                      Icons.camera_alt_rounded,
                      color: Color(0xFF9C5A1A),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                bytes == null
                    ? "Tap untuk pilih $label"
                    : "$label sudah dipilih",
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF4A2C0A),
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF9C5A1A)),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationPicker({
    required KostLocationData? location,
    required VoidCallback onTap,
  }) {
    final hasLocation = location != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F0EA),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFFEADBC9),
              child: Icon(
                hasLocation
                    ? Icons.my_location_rounded
                    : Icons.location_searching_rounded,
                color: const Color(0xFF9C5A1A),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Titik Lokasi Kost',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF4A2C0A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasLocation
                        ? location.coordinateLabel
                        : "Tap untuk ambil lokasi kost dari GPS perangkat",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: const Color(0xFF6B6257),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF9C5A1A),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {VoidCallback? onEdit}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF9C5A1A)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 10, color: Colors.grey.shade600)),
              Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF3D3328))),
            ],
          ),
        ),
        if (onEdit != null) IconButton(onPressed: onEdit, icon: const Icon(Icons.edit, size: 16, color: Color(0xFF9C5A1A))),
      ],
    );
  }

  String _resolveOwnerValue(String key, {String fallback = '-'}) {
    final value = ownerProfile?[key];
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  String _resolveFirstKostValue(String key, {String fallback = '-'}) {
    if (ownerKosts.isEmpty) return fallback;
    final value = ownerKosts.first[key];
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  Widget _buildProfileField(
    String label,
    String value, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF7F0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OwnerPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ),
              if (actionLabel != null && onAction != null)
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    actionLabel,
                    style: GoogleFonts.plusJakartaSans(
                      color: OwnerPalette.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleActionButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color backgroundColor,
    required Color foregroundColor,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: foregroundColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: foregroundColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: foregroundColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: foregroundColor.withOpacity(0.8),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: foregroundColor),
          ],
        ),
      ),
    );
  }

  // --- MAIN BUILD ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OwnerPalette.background,
      body: SafeArea(
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: OwnerPalette.primary),
              )
            : RefreshIndicator(
                onRefresh: _fetchOwnerProfile,
                color: OwnerPalette.primary,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      OwnerPageHeader(
                        title: 'Profil Owner',
                        subtitle:
                            'Kelola akun, unit kost, foto, dan akses operasional dari satu halaman.',
                        trailing: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.storefront_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      OwnerSurfaceCard(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 42,
                              backgroundColor: OwnerPalette.softAccent,
                              backgroundImage:
                                  ownerProfile?['profile_photo_url'] != null
                                  ? NetworkImage(
                                      ownerProfile!['profile_photo_url']
                                          .toString(),
                                    )
                                  : null,
                              child: ownerProfile?['profile_photo_url'] == null
                                  ? const Icon(
                                      Icons.person_rounded,
                                      size: 42,
                                      color: OwnerPalette.primary,
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              _resolveOwnerValue('full_name', fallback: 'Owner'),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.sora(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: OwnerPalette.primaryDark,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              userEmail,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                color: OwnerPalette.muted,
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextButton.icon(
                              onPressed: _updateProfilePhoto,
                              icon: const Icon(
                                Icons.camera_alt_rounded,
                                color: OwnerPalette.primary,
                                size: 18,
                              ),
                              label: Text(
                                'Ubah Foto Profil',
                                style: GoogleFonts.plusJakartaSans(
                                  color: OwnerPalette.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const OwnerSectionHeader(
                        title: 'Informasi Akun',
                        subtitle: 'Ringkasan akun owner yang sedang aktif.',
                      ),
                      const SizedBox(height: 14),
                      _buildProfileField(
                        'Nama Owner',
                        _resolveOwnerValue('full_name', fallback: 'Owner'),
                      ),
                      _buildProfileField('Email Pengguna', userEmail),
                      _buildProfileField(
                        'Password Akun',
                        '••••••••',
                        actionLabel: 'Ubah',
                        onAction: _showChangePasswordDialog,
                      ),
                      const SizedBox(height: 8),
                      const OwnerSectionHeader(
                        title: 'Informasi Kost',
                        subtitle:
                            'Data unit pertama yang aktif ditampilkan untuk akses cepat.',
                      ),
                      const SizedBox(height: 14),
                      _buildProfileField(
                        'Jumlah Unit Kost',
                        ownerKosts.length.toString(),
                      ),
                      _buildProfileField(
                        'Nama Kost',
                        _resolveFirstKostValue('name', fallback: 'Belum ada kost'),
                      ),
                      _buildProfileField(
                        'Alamat Kost',
                        _resolveFirstKostValue(
                          'address',
                          fallback: 'Belum ada kost',
                        ),
                      ),
                      _buildProfileField(
                        'Lokasi Kost',
                        ownerKosts.isEmpty
                            ? 'Belum ada kost'
                            : (KostLocationService.hasLocation(ownerKosts.first)
                                  ? KostLocationService.coordinateLabelFromMap(
                                      ownerKosts.first,
                                    )
                                  : 'Belum diatur'),
                        actionLabel: ownerKosts.isEmpty ? null : 'Atur',
                        onAction: ownerKosts.isEmpty ? null : _updateKostLocation,
                      ),
                      _buildProfileField(
                        'Foto Kost',
                        ownerKosts.isEmpty
                            ? 'Belum ada kost'
                            : (ownerKosts.first['photo_url'] != null
                                  ? 'Sudah ada foto'
                                  : 'Belum ada foto'),
                        actionLabel: ownerKosts.isEmpty ? null : 'Ubah',
                        onAction: ownerKosts.isEmpty ? null : _updateKostPhoto,
                      ),
                      const SizedBox(height: 8),
                      const OwnerSectionHeader(
                        title: 'Aksi Owner',
                        subtitle:
                            'Shortcut untuk kelola penghuni dan pembaruan unit kost.',
                      ),
                      const SizedBox(height: 14),
                      _buildRoleActionButton(
                        title: 'Kelola Penghuni',
                        subtitle:
                            'Lihat tenant aktif dan kelola status penghuni.',
                        icon: Icons.people_rounded,
                        backgroundColor: OwnerPalette.primary,
                        foregroundColor: Colors.white,
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const OwnerManageTenantsPage(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildRoleActionButton(
                        title: 'Tambah Unit Kost Baru',
                        subtitle:
                            'Ajukan unit baru lengkap dengan foto dan lokasi.',
                        icon: Icons.add_business_rounded,
                        backgroundColor: Colors.white,
                        foregroundColor: OwnerPalette.primary,
                        onPressed: _showAddKostDialog,
                      ),
                      const SizedBox(height: 12),
                      _buildRoleActionButton(
                        title: 'Ubah Foto Kost',
                        subtitle:
                            'Perbarui foto unit agar tampil lebih rapi di aplikasi.',
                        icon: Icons.photo_camera_back_outlined,
                        backgroundColor: Colors.white,
                        foregroundColor: OwnerPalette.primary,
                        onPressed: _updateKostPhoto,
                      ),
                      const SizedBox(height: 12),
                      _buildRoleActionButton(
                        title: 'Setel Lokasi Kost',
                        subtitle:
                            'Sinkronkan titik GPS agar lokasi mudah ditemukan.',
                        icon: Icons.my_location_rounded,
                        backgroundColor: Colors.white,
                        foregroundColor: OwnerPalette.primary,
                        onPressed: _updateKostLocation,
                      ),
                      const SizedBox(height: 12),
                      _buildRoleActionButton(
                        title: 'Keluar Dashboard Owner',
                        subtitle: 'Data login akan tetap tersimpan.',
                        icon: Icons.logout_rounded,
                        backgroundColor: const Color(0xFFFFF3F4),
                        foregroundColor: const Color(0xFFE24D56),
                        onPressed: _showLogoutConfirmation,
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
