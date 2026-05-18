import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kostly_pa/auth/auth_ui.dart';
import 'package:kostly_pa/services/supabase_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final supabase = SupabaseService.client;
  final _formKey = GlobalKey<FormState>();

  bool isLoading = false;
  bool _isObscure = true;

  Future<void> login() async {
    FocusScope.of(context).unfocus();

    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar("Semua field wajib diisi", isError: true);
      return;
    }

    if (!email.contains('@')) {
      _showSnackBar("Email harus mengandung tanda @", isError: true);
      return;
    }

    if (password.length < 6) {
      _showSnackBar("Password minimal 6 karakter", isError: true);
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      final res = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = res.user;

      if (user != null) {
        final profile = await supabase
            .from('profiles')
            .select()
            .eq('id', user.id)
            .single();

        if (profile['role'] == 'owner' && profile['is_approved'] == false) {
          await supabase.auth.signOut();
          _showSnackBar("Akun Owner menunggu approval admin", isError: true);
          return;
        }

        if (mounted) {
          String route = '/user';
          if (profile['role'] == 'admin') route = '/admin';
          if (profile['role'] == 'owner') route = '/owner';

          Navigator.pushReplacementNamed(context, route);
        }
      }
    } catch (_) {
      _showSnackBar("Email atau Password salah", isError: true);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

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

  @override
  Widget build(BuildContext context) {
    return AuthScreenShell(
      title: "Hello!",
      subtitle: "Selamat datang kembali di Kostly",
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Login",
              style: GoogleFonts.sora(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AuthPalette.primaryDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Masuk untuk lanjut kelola kost dan tagihanmu.",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AuthPalette.muted,
              ),
            ),
            const SizedBox(height: 24),
            AuthSectionCard(
              title: "Masuk ke Akun",
              subtitle: "Gunakan email dan password yang sudah terdaftar.",
              child: Column(
                children: [
                  _buildTextField(
                    controller: emailController,
                    hint: "Email",
                    icon: Icons.email_outlined,
                    isEmail: true,
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller: passwordController,
                    hint: "Password",
                    icon: Icons.lock_outline_rounded,
                    isPassword: true,
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      "Lupa password? Hubungi admin.",
                      style: GoogleFonts.plusJakartaSans(
                        color: AuthPalette.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            ElevatedButton(
              onPressed: isLoading ? null : login,
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
                  : const Text("Masuk"),
            ),
            const SizedBox(height: 24),
            AuthSectionCard(
              title: "Buat Akun Baru",
              subtitle: "Pilih jenis akun yang ingin Anda daftarkan.",
              child: Row(
                children: [
                  Expanded(
                    child: _buildRegisterButton(
                      label: "Penghuni",
                      onPressed: () =>
                          Navigator.pushNamed(context, '/register-user'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildRegisterButton(
                      label: "Owner",
                      onPressed: () =>
                          Navigator.pushNamed(context, '/register-owner'),
                      isPrimary: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                "Belum punya akun? Pilih tipe registrasi di atas.",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: AuthPalette.muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterButton({
    required String label,
    required VoidCallback onPressed,
    bool isPrimary = false,
  }) {
    final style = isPrimary
        ? ElevatedButton.styleFrom(
            backgroundColor: AuthPalette.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
          )
        : OutlinedButton.styleFrom(
            foregroundColor: AuthPalette.primary,
            side: const BorderSide(color: AuthPalette.primary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
          );

    final child = Text(
      label,
      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
    );

    return isPrimary
        ? ElevatedButton(onPressed: onPressed, style: style, child: child)
        : OutlinedButton(onPressed: onPressed, style: style, child: child);
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool isEmail = false,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword ? _isObscure : false,
      style: GoogleFonts.plusJakartaSans(
        color: AuthPalette.primaryDark,
        fontSize: 14,
      ),
      decoration: authInputDecoration(
        hint: hint,
        icon: icon,
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _isObscure ? Icons.visibility_off : Icons.visibility,
                  color: AuthPalette.muted,
                  size: 20,
                ),
                onPressed: () => setState(() => _isObscure = !_isObscure),
              )
            : null,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return "Wajib diisi";
        }

        if (isEmail && !value.contains('@')) {
          return "Email harus mengandung tanda @";
        }

        if (isPassword && value.length < 6) {
          return "Password minimal 6 karakter";
        }

        return null;
      },
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}
