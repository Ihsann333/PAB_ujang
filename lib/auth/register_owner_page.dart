import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kostly_pa/auth/auth_ui.dart';
import 'package:kostly_pa/services/kost_location_service.dart';
import 'package:kostly_pa/services/media_service.dart';
import 'package:kostly_pa/services/supabase_service.dart';

class RegisterOwnerPage extends StatefulWidget {
  const RegisterOwnerPage({super.key});

  @override
  State<RegisterOwnerPage> createState() => _RegisterOwnerPageState();
}

class _RegisterOwnerPageState extends State<RegisterOwnerPage> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final namaKosController = TextEditingController();
  final addressController = TextEditingController();
  final hargaController = TextEditingController();
  final rulesController = TextEditingController();
  final slotController = TextEditingController();

  bool listrik = false;
  bool air = false;
  bool wifi = false;
  bool isLoading = false;
  bool _obscurePassword = true;
  Uint8List? _ownerPhotoBytes;
  Uint8List? _kostPhotoBytes;
  String? _ownerPhotoName;
  String? _kostPhotoName;
  KostLocationData? _kostLocation;

  final supabase = SupabaseService.client;

  String generateCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random();
    return String.fromCharCodes(
      Iterable.generate(6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
    );
  }

  void _showNotice(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : AuthPalette.primary,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _pickOwnerPhoto() async {
    final photo = await MediaService.pickImage(context);
    if (photo == null) return;
    final bytes = await photo.readAsBytes();
    if (!mounted) return;
    setState(() {
      _ownerPhotoBytes = bytes;
      _ownerPhotoName = photo.name;
    });
  }

  Future<void> _pickKostPhoto() async {
    final photo = await MediaService.pickImage(context);
    if (photo == null) return;
    final bytes = await photo.readAsBytes();
    if (!mounted) return;
    setState(() {
      _kostPhotoBytes = bytes;
      _kostPhotoName = photo.name;
    });
  }

  Future<String?> _uploadPhoto({
    required Uint8List? bytes,
    required String folder,
    required String fileName,
  }) async {
    if (bytes == null) return null;
    try {
      final uploaded = await MediaService.uploadImageBytes(
        bytes: bytes,
        bucket: MediaService.bucketName,
        folder: folder,
        fileName: MediaService.buildFileName(
          prefix: folder.startsWith('profiles/') ? 'owner_profile' : 'kost_photo',
          originalFileName: fileName,
        ),
      );
      return uploaded.publicUrl;
    } catch (e) {
      if (mounted) {
        final message = e.toString().contains('Bucket not found')
            ? 'Foto belum tersimpan karena storage media belum tersedia. Registrasi tetap dilanjutkan tanpa foto.'
            : 'Upload foto gagal, tapi registrasi tetap dilanjutkan tanpa foto.';
        _showNotice(message);
      }
      return null;
    }
  }

  Future<void> registerOwner() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      final res = await supabase.auth.signUp(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final user = res.user;
      if (user == null) throw "Gagal mendaftarkan akun.";

      final ownerPhotoUrl = await _uploadPhoto(
        bytes: _ownerPhotoBytes,
        folder: 'profiles/${user.id}',
        fileName: _ownerPhotoName ??
            'owner_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      final kostPhotoUrl = await _uploadPhoto(
        bytes: _kostPhotoBytes,
        folder: 'kosts/${user.id}',
        fileName:
            _kostPhotoName ?? 'kost_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      await supabase.from('profiles').insert({
        'id': user.id,
        'full_name': nameController.text.trim(),
        'phone_number': phoneController.text.trim(),
        'email': emailController.text.trim(),
        'role': 'owner',
        'is_approved': false,
      });
      if (ownerPhotoUrl != null) {
        await MediaService.upsertProfileImage(
          userId: user.id,
          imageUrl: ownerPhotoUrl,
        );
      }

      final createdKost = await KostLocationService.saveKostWithLocation(
        supabase: supabase,
        basePayload: {
          'owner_id': user.id,
          'name': namaKosController.text.trim(),
          'address': addressController.text.trim(),
          'price': int.tryParse(hargaController.text.trim()) ?? 0,
          'include_electricity': listrik,
          'include_water': air,
          'include_wifi': wifi,
          'rules': rulesController.text.trim(),
          'slots': int.tryParse(slotController.text.trim()) ?? 0,
          'join_code': generateCode(),
          'is_approved': false,
        },
        location: _kostLocation,
      );
      final createdKostId = createdKost?['id']?.toString();
      if (kostPhotoUrl != null && createdKostId != null && createdKostId.isNotEmpty) {
        await MediaService.upsertKostImage(
          kostId: createdKostId,
          imageUrl: kostPhotoUrl,
        );
      }

      _showNotice("Registrasi Berhasil! Menunggu persetujuan admin.");
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showNotice(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScreenShell(
      title: "Sign Up",
      subtitle: "Daftarkan akun owner dan unit kost Anda",
      backLabel: "Kembali ke login",
      onBack: () => Navigator.pop(context),
      maxWidth: 520,
      headerHeight: 240,
      cardOverlap: 18,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Daftar Owner",
              style: GoogleFonts.sora(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: AuthPalette.primaryDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Lengkapi data akun dan informasi kost agar bisa direview admin.",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AuthPalette.muted,
              ),
            ),
            const SizedBox(height: 20),
            AuthSectionCard(
              title: "Informasi Akun",
              subtitle: "Data pemilik yang dipakai untuk akses dan verifikasi.",
              child: Column(
                children: [
                  AuthImagePickerPreview(
                    title: "Foto Profil Owner",
                    subtitle: _ownerPhotoBytes == null
                        ? "Tambahkan foto profil owner"
                        : "Foto profil owner sudah dipilih",
                    onTap: _pickOwnerPhoto,
                    imageProvider: _ownerPhotoBytes != null
                        ? MemoryImage(_ownerPhotoBytes!)
                        : null,
                  ),
                  const SizedBox(height: 16),
                  _inputField(
                    "Nama Pengguna",
                    nameController,
                    Icons.person_outline_rounded,
                    isName: true,
                  ),
                  _inputField(
                    "Nomor Pengguna (08...)",
                    phoneController,
                    Icons.phone_outlined,
                    isPhone: true,
                  ),
                  _inputField(
                    "Email",
                    emailController,
                    Icons.email_outlined,
                    isEmail: true,
                  ),
                  _inputField(
                    "Password",
                    passwordController,
                    Icons.lock_outline_rounded,
                    isPassword: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AuthSectionCard(
              title: "Detail Kost",
              subtitle: "Informasi ini akan ditinjau admin sebelum aktif.",
              child: Column(
                children: [
                  AuthImagePickerPreview(
                    title: "Foto Kost",
                    subtitle: _kostPhotoBytes == null
                        ? "Tambahkan foto utama kost"
                        : "Foto kost sudah dipilih",
                    onTap: _pickKostPhoto,
                    imageProvider: _kostPhotoBytes != null
                        ? MemoryImage(_kostPhotoBytes!)
                        : null,
                  ),
                  const SizedBox(height: 16),
                  _inputField(
                    "Nama Kost",
                    namaKosController,
                    Icons.home_work_outlined,
                  ),
                  _inputField(
                    "Alamat Lengkap Kost",
                    addressController,
                    Icons.location_on_outlined,
                    maxLines: 2,
                  ),
                  _locationPickerCard(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _inputField(
                          "Harga (Rp)",
                          hargaController,
                          Icons.payments_outlined,
                          isNumber: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _inputField(
                          "Jumlah Kamar",
                          slotController,
                          Icons.meeting_room_outlined,
                          isNumber: true,
                        ),
                      ),
                    ],
                  ),
                  _inputField(
                    "Peraturan Kost",
                    rulesController,
                    Icons.rule_folder_outlined,
                    maxLines: 3,
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Fasilitas Tambahan",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AuthPalette.primaryDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _buildFacilityChip(
                        "Listrik Include",
                        listrik,
                        (v) => setState(() => listrik = v),
                      ),
                      _buildFacilityChip(
                        "Air Include",
                        air,
                        (v) => setState(() => air = v),
                      ),
                      _buildFacilityChip(
                        "WiFi Include",
                        wifi,
                        (v) => setState(() => wifi = v),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: isLoading ? null : registerOwner,
              style: authPrimaryButtonStyle(),
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text("Daftar"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFacilityChip(
    String title,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return FilterChip(
      label: Text(
        title,
        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
      ),
      selected: value,
      onSelected: onChanged,
      selectedColor: const Color(0xFFF3E3CF),
      checkmarkColor: AuthPalette.primary,
      labelStyle: GoogleFonts.plusJakartaSans(
        color: value ? AuthPalette.primary : AuthPalette.primaryDark,
      ),
      side: BorderSide(
        color: value ? AuthPalette.primary : AuthPalette.border,
      ),
      backgroundColor: AuthPalette.inputFill,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    );
  }

  Future<void> _captureKostLocation() async {
    try {
      final location = await KostLocationService.getCurrentLocation();
      if (!mounted) return;
      setState(() => _kostLocation = location);
      _showNotice('Lokasi kost berhasil diambil dari perangkat.');
    } catch (e) {
      _showNotice(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Widget _locationPickerCard() {
    final hasLocation = _kostLocation != null;
    return InkWell(
      onTap: _captureKostLocation,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AuthPalette.inputFill,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AuthPalette.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFFF0DAC0),
              child: Icon(
                hasLocation
                    ? Icons.my_location_rounded
                    : Icons.location_searching_rounded,
                color: AuthPalette.primary,
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
                      fontWeight: FontWeight.w700,
                      color: AuthPalette.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasLocation
                        ? _kostLocation!.coordinateLabel
                        : 'Tap untuk ambil lokasi kost dari GPS perangkat',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AuthPalette.muted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    hasLocation
                        ? 'Lokasi siap ditinjau admin dan ditampilkan ke user.'
                        : 'Disarankan diambil saat Anda berada di area kost.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: AuthPalette.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AuthPalette.primary),
          ],
        ),
      ),
    );
  }

  Widget _inputField(
    String label,
    TextEditingController controller,
    IconData icon, {
    bool isPassword = false,
    bool isEmail = false,
    bool isNumber = false,
    bool isPhone = false,
    bool isName = false,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword ? _obscurePassword : false,
        maxLines: maxLines,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          color: AuthPalette.primaryDark,
        ),
        inputFormatters: [
          if (isName) FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
          if (isPhone || isNumber) FilteringTextInputFormatter.digitsOnly,
          if (isPassword || isEmail)
            FilteringTextInputFormatter.deny(RegExp(r'\s')),
        ],
        keyboardType: isNumber
            ? TextInputType.number
            : (isPhone
                ? TextInputType.phone
                : (isEmail ? TextInputType.emailAddress : TextInputType.text)),
        decoration: authInputDecoration(
          hint: label,
          icon: icon,
          suffixIcon: isPassword
              ? IconButton(
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: AuthPalette.muted,
                    size: 20,
                  ),
                )
              : null,
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) return "$label wajib diisi";
          if (isName && value.length < 3) return "Nama minimal 3 karakter";
          if (isEmail &&
              !RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
            return "Format email tidak sesuai";
          }
          if (isPassword && value.length < 6) {
            return "Password minimal 6 karakter";
          }
          if (isNumber) {
            final n = int.tryParse(value);
            if (n == null) return "Harus berupa angka";
            if (n <= 0) return "Nilai harus lebih dari 0";
          }
          if (isPhone) {
            if (!value.startsWith('08')) return "Nomor harus diawali dengan 08";
            if (value.length < 10) return "Nomor terlalu pendek";
            if (value.length > 13) return "Nomor terlalu panjang";
          }
          return null;
        },
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    passwordController.dispose();
    namaKosController.dispose();
    addressController.dispose();
    hargaController.dispose();
    rulesController.dispose();
    slotController.dispose();
    super.dispose();
  }
}
