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
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final namaKosController = TextEditingController();
  final hargaController = TextEditingController();
  final rulesController = TextEditingController();
  final slotController = TextEditingController();

  // Tambahkan state untuk wifi
  bool listrik = false;
  bool air = false;
  bool wifi = false; 
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
      final res = await supabase.auth.signUp(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final user = res.user;
      if (user == null) throw "Gagal mendaftarkan akun.";

      await supabase.from('profiles').insert({
        'id': user.id,
        'full_name': nameController.text.trim(),
        'phone_number': phoneController.text.trim(),
        'email': emailController.text.trim(),
        'role': 'owner',
        'is_approved': false,
      });

      // Menambahkan include_wifi ke insert query
      await supabase.from('kosts').insert({
        'owner_id': user.id,
        'name': namaKosController.text.trim(),
        'price': int.tryParse(hargaController.text.trim()) ?? 0,
        'include_electricity': listrik,
        'include_water': air,
        'include_wifi': wifi, // Masuk ke kolom database
        'rules': rulesController.text.trim(),
        'slots': int.tryParse(slotController.text.trim()) ?? 0,
        'join_code': generateCode(),
        'is_approved': false, // Pastikan default false agar diverifikasi admin
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
                  _inputField("Nama Pengguna", nameController, Icons.person),
                  _inputField("Nomor Pengguna", phoneController, Icons.phone, isPhone: true),
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
                  
                  // Mengatur checkbox dalam Wrap agar lebih rapi
                  Wrap(
                    children: [
                      _buildCheckbox("Listrik Include", listrik, (v) => setState(() => listrik = v!)),
                      _buildCheckbox("Air Include", air, (v) => setState(() => air = v!)),
                      _buildCheckbox("WiFi Include", wifi, (v) => setState(() => wifi = v!)),
                    ],
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

  // Widget pembantu untuk Checkbox agar tidak berulang kodenya
  Widget _buildCheckbox(String title, bool value, Function(bool?) onChanged) {
    return SizedBox(
      width: 180, // Ukuran lebar agar bisa berjejer jika layar cukup luas
      child: CheckboxListTile(
        title: Text(title, style: const TextStyle(fontSize: 13)),
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF9C5A1A),
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        dense: true,
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
      {bool isPassword = false, bool isEmail = false, bool isNumber = false, bool isPhone = false, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        maxLines: maxLines,
        keyboardType: isNumber
            ? TextInputType.number
            : (isPhone ? TextInputType.phone : (isEmail ? TextInputType.emailAddress : TextInputType.text)),
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
          if (isPhone) {
            final cleaned = value.replaceAll(RegExp(r'[^0-9]'), '');
            if (cleaned.length < 10 || cleaned.length > 15) return "Nomor tidak valid";
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
    hargaController.dispose();
    rulesController.dispose();
    slotController.dispose();
    super.dispose();
  }
}