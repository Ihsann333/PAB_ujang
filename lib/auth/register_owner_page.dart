import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:google_fonts/google_fonts.dart';
import '../services/supabase_service.dart';
import 'dart:math';

class RegisterOwnerPage extends StatefulWidget {
  const RegisterOwnerPage({super.key});

  @override
  State<RegisterOwnerPage> createState() => _RegisterOwnerPageState();
}

class _RegisterOwnerPageState extends State<RegisterOwnerPage> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  
  final namaKosController = TextEditingController();
  final addressController = TextEditingController(); // Controller Alamat Baru
  final hargaController = TextEditingController();
  final rulesController = TextEditingController();
  final slotController = TextEditingController();

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

      // 1. Insert ke tabel Profiles
      await supabase.from('profiles').insert({
        'id': user.id,
        'full_name': nameController.text.trim(),
        'phone_number': phoneController.text.trim(),
        'email': emailController.text.trim(),
        'role': 'owner',
        'is_approved': false,
      });

      // 2. Insert ke tabel Kosts (Termasuk Alamat)
      await supabase.from('kosts').insert({
        'owner_id': user.id,
        'name': namaKosController.text.trim(),
        'address': addressController.text.trim(), // Data alamat masuk ke sini
        'price': int.tryParse(hargaController.text.trim()) ?? 0,
        'include_electricity': listrik,
        'include_water': air,
        'include_wifi': wifi,
        'rules': rulesController.text.trim(),
        'slots': int.tryParse(slotController.text.trim()) ?? 0,
        'join_code': generateCode(),
        'is_approved': false,
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
        title: Text(
          "Daftar Owner",
          style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700),
        ),
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
                  _inputField("Nama Pengguna", nameController, Icons.person, isName: true),
                  _inputField("Nomor Pengguna (08...)", phoneController, Icons.phone, isPhone: true),
                  _inputField("Email", emailController, Icons.email, isEmail: true),
                  _inputField("Password", passwordController, Icons.lock, isPassword: true),
                  
                  const Divider(height: 40),
                  
                  _sectionTitle("Detail Kost"),
                  _inputField("Nama Kost", namaKosController, Icons.home_work),
                  
                  // INPUT ALAMAT
                  _inputField("Alamat Lengkap Kost", addressController, Icons.location_on, maxLines: 2),

                  Row(
                    children: [
                      Expanded(child: _inputField("Harga (Rp)", hargaController, Icons.money, isNumber: true)),
                      const SizedBox(width: 12),
                      Expanded(child: _inputField("Jumlah Kamar", slotController, Icons.meeting_room, isNumber: true)),
                    ],
                  ),
                  _inputField("Peraturan Kost", rulesController, Icons.rule, maxLines: 3),

                  const SizedBox(height: 10),
                  Text(
                    "Fasilitas Tambahan:",
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  
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
                        : Text("Daftar Sekarang", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCheckbox(String title, bool value, Function(bool?) onChanged) {
    return SizedBox(
      width: 180,
      child: CheckboxListTile(
        title: Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w500)),
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
      child: Text(
        title,
        style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF9C5A1A)),
      ),
    );
  }

  Widget _inputField(String label, TextEditingController controller, IconData icon, 
      {bool isPassword = false, bool isEmail = false, bool isNumber = false, bool isPhone = false, bool isName = false, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        maxLines: maxLines,
        style: GoogleFonts.plusJakartaSans(fontSize: 15, color: const Color(0xFF4A2C0A)),
        inputFormatters: [
          if (isName) FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')), 
          if (isPhone || isNumber) FilteringTextInputFormatter.digitsOnly, 
          if (isPassword || isEmail) FilteringTextInputFormatter.deny(RegExp(r'\s')), 
        ],
        keyboardType: isNumber
            ? TextInputType.number
            : (isPhone ? TextInputType.phone : (isEmail ? TextInputType.emailAddress : TextInputType.text)),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF6A5C4F), fontSize: 13, fontWeight: FontWeight.w500),
          prefixIcon: Icon(icon, size: 20, color: const Color(0xFF9C5A1A)),
          filled: true,
          fillColor: const Color(0xFFFDF8F2),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) return "$label wajib diisi";
          if (isName && value.length < 3) return "Nama minimal 3 karakter";
          if (isEmail && !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) return "Format email tidak sesuai";
          if (isPassword && value.length < 6) return "Password minimal 6 karakter";
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