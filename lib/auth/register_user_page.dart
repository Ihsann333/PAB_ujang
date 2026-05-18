import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kostly_pa/auth/auth_ui.dart';
import 'package:kostly_pa/services/media_service.dart';
import 'package:kostly_pa/services/supabase_service.dart';

class RegisterUserPage extends StatefulWidget {
  const RegisterUserPage({super.key});

  @override
  State<RegisterUserPage> createState() => _RegisterUserPageState();
}

class _RegisterUserPageState extends State<RegisterUserPage> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final supabase = SupabaseService.client;
  final _formKey = GlobalKey<FormState>();

  bool isLoading = false;
  bool _obscurePassword = true;
  Uint8List? _profilePhotoBytes;
  String? _profilePhotoName;

  void _showSnackBar(String message, {bool isError = false}) {
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

  Future<void> _pickProfilePhoto() async {
    final photo = await MediaService.pickImage(context);
    if (photo == null) return;

    final bytes = await photo.readAsBytes();
    if (!mounted) return;

    setState(() {
      _profilePhotoBytes = bytes;
      _profilePhotoName = photo.name;
    });
  }

  Future<String?> _uploadProfilePhoto(String userId) async {
    final bytes = _profilePhotoBytes;
    if (bytes == null) return null;

    final fileName = _profilePhotoName ??
        'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';

    try {
      return await MediaService.uploadImageBytes(
        bytes: bytes,
        bucket: 'kostly-media',
        folder: 'profiles/$userId',
        fileName: fileName,
      );
    } catch (e) {
      if (mounted) {
        final message = e.toString().contains('Bucket not found')
            ? 'Foto profil belum tersimpan karena storage media belum tersedia. Akun tetap akan dibuat tanpa foto.'
            : 'Upload foto profil gagal, tapi akun tetap akan dibuat tanpa foto.';
        _showSnackBar(message);
      }
      return null;
    }
  }

  Future<void> registerUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      final res = await supabase.auth.signUp(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final user = res.user;
      if (user == null) throw "Gagal membuat akun, silahkan coba lagi.";

      final profilePhotoUrl = await _uploadProfilePhoto(user.id);

      await supabase.from('profiles').insert({
        'id': user.id,
        'full_name': nameController.text.trim(),
        'phone_number': phoneController.text.trim(),
        'email': emailController.text.trim(),
        'role': 'user',
        'is_approved': true,
        'profile_photo_url': profilePhotoUrl,
      });

      _showSnackBar("Registrasi Berhasil! Silahkan Login.");
      if (mounted) Navigator.pop(context);
    } catch (e) {
      String errorMsg = e.toString();
      if (errorMsg.contains("already registered")) {
        errorMsg = "Email ini sudah terdaftar!";
      } else if (errorMsg.contains("network")) {
        errorMsg = "Koneksi internet bermasalah.";
      }
      _showSnackBar(errorMsg, isError: true);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScreenShell(
      title: "Sign Up",
      subtitle: "Buat akun penghuni untuk mulai pakai Kostly",
      backLabel: "Kembali ke login",
      onBack: () => Navigator.pop(context),
      headerHeight: 255,
      cardOverlap: 18,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Daftar Penghuni",
              style: GoogleFonts.sora(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: AuthPalette.primaryDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Isi data dasar dulu, sisanya bisa dilengkapi setelah masuk.",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AuthPalette.muted,
              ),
            ),
            const SizedBox(height: 20),
            AuthSectionCard(
              title: "Foto Profil",
              subtitle: "Opsional, tapi bikin akunmu lebih rapi dikenali.",
              child: AuthImagePickerPreview(
                title: _profilePhotoBytes == null
                    ? "Pilih foto profil"
                    : "Ubah foto profil",
                subtitle: _profilePhotoBytes == null
                    ? "Tambahkan foto dari kamera atau galeri"
                    : "Foto sudah dipilih dan siap diunggah",
                onTap: _pickProfilePhoto,
                imageProvider: _profilePhotoBytes != null
                    ? MemoryImage(_profilePhotoBytes!)
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            AuthSectionCard(
              title: "Informasi Akun",
              subtitle: "Data ini dipakai untuk login dan profil penghuni.",
              child: Column(
                children: [
                  _buildField(
                    controller: nameController,
                    hint: "Nama Pengguna",
                    icon: Icons.person_outline_rounded,
                  ),
                  const SizedBox(height: 14),
                  _buildField(
                    controller: phoneController,
                    hint: "Nomor Pengguna",
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 14),
                  _buildField(
                    controller: emailController,
                    hint: "Email",
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 14),
                  _buildField(
                    controller: passwordController,
                    hint: "Password",
                    icon: Icons.lock_outline_rounded,
                    obscureText: _obscurePassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: AuthPalette.muted,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            ElevatedButton(
              onPressed: isLoading ? null : registerUser,
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
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  "Sudah punya akun? Login di sini",
                  style: GoogleFonts.plusJakartaSans(
                    color: AuthPalette.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        color: AuthPalette.primaryDark,
      ),
      decoration: authInputDecoration(
        hint: hint,
        icon: icon,
        suffixIcon: suffixIcon,
      ),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (text.isEmpty) return "$hint tidak boleh kosong";
        if (hint == "Nama Pengguna" && text.length < 3) {
          return "Nama pengguna minimal 3 karakter";
        }
        if (hint == "Nomor Pengguna") {
          final cleaned = text.replaceAll(RegExp(r'[^0-9]'), '');
          if (cleaned.length < 10 || cleaned.length > 15) {
            return "Nomor pengguna tidak valid";
          }
        }
        if (hint == "Email" &&
            !RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(text)) {
          return "Format email tidak valid";
        }
        if (hint == "Password" && text.length < 6) {
          return "Minimal 6 karakter";
        }
        return null;
      },
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}
