import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
  final _formKey = GlobalKey<FormState>(); // Kunci untuk validasi form

  bool isLoading = false;

  // Fungsi snackbar biar tampilannya cantik dan informatif
  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF9C5A1A),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> registerUser() async {
    // 1. Cek validasi form dulu
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      final res = await supabase.auth.signUp(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final user = res.user;
      if (user == null) throw "Gagal membuat akun, silahkan coba lagi.";

      // 2. Masukkan ke table profiles
      await supabase.from('profiles').insert({
        'id': user.id,
        'full_name': nameController.text.trim(),
        'phone_number': phoneController.text.trim(),
        'email': emailController.text.trim(),
        'role': 'user',
        'is_approved': true,
      });

      _showSnackBar("Registrasi Berhasil! Silahkan Login.");
      if (mounted) Navigator.pop(context); // Balik ke halaman login

    } catch (e) {
      // 3. Error handling biar user nggak bingung
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
    // Pakai .width biar error maxWidth hilang

    return Scaffold(
      backgroundColor: const Color(0xFFF2E8DA), // Background Cream
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            // Card tetap proporsional di HP maupun Web
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)
              ],
            ),
            child: Form(
              key: _formKey, // Pasang form key di sini
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person_add_alt_1_rounded, size: 60, color: Color(0xFF9C5A1A)),
                  const SizedBox(height: 16),
                  Text(
                    "Daftar Penghuni",
                    style: GoogleFonts.sora(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF4A2C0A),
                    ),
                  ),
                  Text(
                    "Lengkapi data untuk membuat akun",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 32),

                  TextFormField(
                    controller: nameController,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      color: const Color(0xFF4A2C0A),
                    ),
                    decoration: _inputDecoration("Nama Pengguna"),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return "Nama pengguna tidak boleh kosong";
                      if (value.trim().length < 3) return "Nama pengguna minimal 3 karakter";
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      color: const Color(0xFF4A2C0A),
                    ),
                    decoration: _inputDecoration("Nomor Pengguna"),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return "Nomor pengguna tidak boleh kosong";
                      final cleaned = value.replaceAll(RegExp(r'[^0-9]'), '');
                      if (cleaned.length < 10 || cleaned.length > 15) return "Nomor pengguna tidak valid";
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Input Email dengan Validasi Karakter
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      color: const Color(0xFF4A2C0A),
                    ),
                    decoration: _inputDecoration("Email"),
                    validator: (value) {
                      if (value == null || value.isEmpty) return "Email tidak boleh kosong";
                      // Cek format email pake RegExp
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                        return "Format email tidak valid";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Input Password
                  TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      color: const Color(0xFF4A2C0A),
                    ),
                    decoration: _inputDecoration("Password"),
                    validator: (value) {
                      if (value == null || value.isEmpty) return "Password tidak boleh kosong";
                      if (value.length < 6) return "Minimal 6 karakter";
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Tombol Daftar
                  ElevatedButton(
                    onPressed: isLoading ? null : registerUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9C5A1A),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(
                            "Daftar Sekarang",
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),

                  const SizedBox(height: 16),

                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      "Sudah punya akun? Login di sini",
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF9C5A1A),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper untuk style input biar nggak ngetik ulang
  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.plusJakartaSans(
        color: const Color(0xFF9C5A1A),
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      filled: true,
      fillColor: const Color(0xFFEDE3D5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
