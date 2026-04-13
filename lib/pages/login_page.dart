import 'package:flutter/material.dart';
import '../core/supabase_service.dart';

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
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);
    try {
      final res = await supabase.auth.signInWithPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final user = res.user;

      if (user != null) {
        final profile = await supabase
            .from('profiles')
            .select()
            .eq('id', user.id)
            .single();

        if (profile['role'] == 'owner' && profile['is_approved'] == false) {
          _showSnackBar("Akun Owner menunggu approval admin", isError: true);
          return;
        }

        if (mounted) {
          // Navigasi berdasarkan role
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
                // Icon Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9C5A1A),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF9C5A1A).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))
                    ],
                  ),
                  child: const Icon(Icons.home_work_rounded, color: Colors.white, size: 50),
                ),
                const SizedBox(height: 20),
                const Text(
                  "KOSTLY",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF4A2C0A), letterSpacing: 1.5),
                ),
                const Text("Lupa bayar kos? Kostly aja", style: TextStyle(color: Colors.brown, fontSize: 13)),
                const SizedBox(height: 35),

                // Card Form
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildTextField(controller: emailController, hint: "Email", icon: Icons.email_outlined),
                        const SizedBox(height: 16),
                        _buildTextField(controller: passwordController, hint: "Password", icon: Icons.lock_outline, isPassword: true),
                        const SizedBox(height: 24),
                        
                        ElevatedButton(
                          onPressed: isLoading ? null : login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF9C5A1A),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 52),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: isLoading
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text("MASUK", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // REGISTER SECTION (Ini yang tadi kureng)
                const Text("Belum punya akun? Register sebagai", style: TextStyle(color: Color(0xFF4A2C0A), fontSize: 13)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    // Tombol Daftar Penghuni
                    Expanded(
                      child: _buildRegisterButton(
                        label: "Penghuni",
                        onPressed: () => Navigator.pushNamed(context, '/register-user'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Tombol Daftar Owner
                    Expanded(
                      child: _buildRegisterButton(
                        label: "Owner",
                        onPressed: () => Navigator.pushNamed(context, '/register-owner'),
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
  Widget _buildRegisterButton({required String label, required VoidCallback onPressed, bool isPrimary = false}) {
    return isPrimary 
      ? ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF9C5A1A),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 12),
            elevation: 0,
          ),
          child: Text(label),
        )
      : OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFF9C5A1A)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: Text(label, style: const TextStyle(color: Color(0xFF9C5A1A))),
        );
  }

  Widget _buildTextField({required TextEditingController controller, required String hint, required IconData icon, bool isPassword = false}) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword ? _isObscure : false,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF9C5A1A), size: 20),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(_isObscure ? Icons.visibility_off : Icons.visibility, color: Colors.grey, size: 20),
                onPressed: () => setState(() => _isObscure = !_isObscure),
              )
            : null,
        filled: true,
        fillColor: const Color(0xFFFDF8F2),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
      validator: (value) => (value == null || value.isEmpty) ? "Wajib diisi" : null,
    );
  }
}