import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

    // 🔥 VALIDASI MANUAL (ANTI TEMBUS)
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

    // ✅ OPTIONAL: tetap pakai form validation
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
    } catch (e) {
      _showSnackBar("Email atau Password salah", isError: true);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2E8DA), // Background Cream
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              children: [
                Image.asset(
                  'assets/images/login_logo_kostly.jpeg',
                  width: 130,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 5),
                Text(
                  "KOSTLY",
                  style: GoogleFonts.sora(
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF4A2C0A),
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  "Lupa bayar kost? Kostly aja",
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.brown,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 35),

                // Card Form
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildTextField(
                          controller: emailController,
                          hint: "Email",
                          icon: Icons.email_outlined,
                          isEmail: true,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: passwordController,
                          hint: "Password",
                          icon: Icons.lock_outline,
                          isPassword: true,
                        ),
                        const SizedBox(height: 24),

                        ElevatedButton(
                          onPressed: isLoading ? null : login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF9C5A1A),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  "MASUK",
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // REGISTER SECTION (Ini yang tadi kureng)
                Text(
                  "Belum punya akun? Register sebagai",
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF4A2C0A),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    // Tombol Daftar Penghuni
                    Expanded(
                      child: _buildRegisterButton(
                        label: "Penghuni",
                        onPressed: () =>
                            Navigator.pushNamed(context, '/register-user'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Tombol Daftar Owner
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper Button Register biar rapi
  Widget _buildRegisterButton({
    required String label,
    required VoidCallback onPressed,
    bool isPrimary = false,
  }) {
    return isPrimary
        ? ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9C5A1A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              elevation: 0,
            ),
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
            ),
          )
        : OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF9C5A1A)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF9C5A1A),
                fontWeight: FontWeight.w600,
              ),
            ),
          );
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
        color: const Color(0xFF4A2C0A),
        fontSize: 15,
        fontWeight: FontWeight.w400,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.plusJakartaSans(
          color: const Color(0xFF8C7D6E),
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
        prefixIcon: Icon(icon, color: const Color(0xFF9C5A1A), size: 20),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _isObscure ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey,
                  size: 20,
                ),
                onPressed: () => setState(() => _isObscure = !_isObscure),
              )
            : null,
        filled: true,
        fillColor: const Color(0xFFFDF8F2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),

      // 🔥 VALIDATOR BARU
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
