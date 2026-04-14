import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'dart:math';

class RegisterOwnerPage extends StatefulWidget {
  const RegisterOwnerPage({super.key});

  @override
  State<RegisterOwnerPage> createState() => _RegisterOwnerPageState();
}

class _RegisterOwnerPageState extends State<RegisterOwnerPage> {
  final _formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final namaKosController = TextEditingController();
  final hargaController = TextEditingController();
  final rulesController = TextEditingController();
  final slotController = TextEditingController();

  bool listrik = false;
  bool air = false;
  bool isLoading = false;

  final supabase = SupabaseService.client;

  String generateCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random rnd = Random();
    return String.fromCharCodes(
      Iterable.generate(6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
    );
  }

  void _showNotice(String message, {bool isError = false}) {
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

  Future<void> registerOwner() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      // 1. Auth SignUp
      final res = await supabase.auth.signUp(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final user = res.user;
      if (user == null) throw "Gagal mendaftarkan akun.";

      // 2. Insert Profile
      await supabase.from('profiles').insert({
        'id': user.id,
        'email': emailController.text.trim(),
        'role': 'owner',
        'is_approved': false,
      });

      // 3. Insert Data Kos
      await supabase.from('kosts').insert({
        'owner_id': user.id,
        'name': namaKosController.text.trim(),
        'price': int.tryParse(hargaController.text.trim()) ?? 0,
        'include_electricity': listrik,
        'include_water': air,
        'rules': rulesController.text.trim(),
        'slots': int.tryParse(slotController.text.trim()) ?? 0,
        'join_code': generateCode(),
      });

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
    return Scaffold(
      backgroundColor: const Color(0xFFF2E8DA),
      appBar: AppBar(
        title: const Text("Daftar Owner", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF4A2C0A),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15)],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle("Informasi Akun"),
                  _inputField("Email", emailController, Icons.email, isEmail: true),
                  _inputField("Password", passwordController, Icons.lock, isPassword: true),
                  
                  const Divider(height: 40),
                  
                  _sectionTitle("Detail Kost"),
                  _inputField("Nama Kost", namaKosController, Icons.home_work),
                  Row(
                    children: [
                      Expanded(child: _inputField("Harga (Rp)", hargaController, Icons.money, isNumber: true)),
                      const SizedBox(width: 12),
                      Expanded(child: _inputField("Jumlah Kamar", slotController, Icons.meeting_room, isNumber: true)),
                    ],
                  ),
                  _inputField("Peraturan Kost", rulesController, Icons.rule, maxLines: 3),

                  const SizedBox(height: 10),
                  const Text("Fasilitas Tambahan:", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  CheckboxListTile(
                    title: const Text("Listrik Include", style: TextStyle(fontSize: 13)),
                    value: listrik,
                    onChanged: (v) => setState(() => listrik = v!),
                    activeColor: const Color(0xFF9C5A1A),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  CheckboxListTile(
                    title: const Text("Air Include", style: TextStyle(fontSize: 13)),
                    value: air,
                    onChanged: (v) => setState(() => air = v!),
                    activeColor: const Color(0xFF9C5A1A),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),

                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: isLoading ? null : registerOwner,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9C5A1A),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text("Daftar Sekarang", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF9C5A1A))),
    );
  }

  Widget _inputField(String label, TextEditingController controller, IconData icon, 
      {bool isPassword = false, bool isEmail = false, bool isNumber = false, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        maxLines: maxLines,
        keyboardType: isNumber ? TextInputType.number : (isEmail ? TextInputType.emailAddress : TextInputType.text),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20, color: const Color(0xFF9C5A1A)),
          filled: true,
          fillColor: const Color(0xFFFDF8F2),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) return "Wajib diisi";
          if (isEmail && !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) return "Email tidak valid";
          if (isNumber && int.tryParse(value) == null) return "Harus berupa angka";
          return null;
        },
      ),
    );
  }
}