import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:kostly_pa/pages/login_page.dart';
import 'package:kostly_pa/pages/user_page/user_ui.dart';
import 'package:kostly_pa/services/kost_location_service.dart';
import 'package:kostly_pa/services/media_service.dart';
import 'package:kostly_pa/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final supabase = SupabaseService.client;
  final TextEditingController _passwordCtrl = TextEditingController();

  Map<String, dynamic>? profileData;
  Map<String, dynamic>? kostData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => isLoading = false);
        return;
      }

      final profile = await supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();
      final profileWithImage = await MediaService.attachProfileImage(
        Map<String, dynamic>.from(profile),
      );

      Map<String, dynamic>? kost;
      if (profileWithImage['kost_id'] != null) {
        final kostResult = await supabase
            .from('kosts')
            .select()
            .eq('id', profileWithImage['kost_id'].toString())
            .maybeSingle();
        if (kostResult != null) {
          kost = await MediaService.attachKostImage(
            Map<String, dynamic>.from(kostResult),
          );
        }
      }

      if (mounted) {
        setState(() {
          profileData = profileWithImage;
          kostData = kost;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat profil: $e')),
      );
    }
  }

  Future<void> _updateProfilePhoto() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final photoUrl = await MediaService.pickAndUploadProfilePhoto(
        context,
        userId: user.id,
        filePrefix: 'user',
      );
      if (photoUrl == null) return;

      await _fetchData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto profil berhasil diperbarui.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memperbarui foto profil: $e')),
        );
      }
    }
  }

  Future<void> _updatePassword() async {
    if (_passwordCtrl.text.trim().length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password minimal 6 karakter'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      await supabase.auth.updateUser(
        UserAttributes(password: _passwordCtrl.text.trim()),
      );

      if (!mounted) return;
      _passwordCtrl.clear();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password berhasil diperbarui!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memperbarui password: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showChangePasswordDialog() {
    _passwordCtrl.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFFFBF7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Ubah Password',
          style: GoogleFonts.sora(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF9C5A1A),
          ),
        ),
        content: TextField(
          controller: _passwordCtrl,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Password Baru',
            filled: true,
            fillColor: const Color(0xFFF5F0EA),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: _updatePassword,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9C5A1A),
            ),
            child: const Text(
              'Simpan',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmation() {
    final pageContext = context;

    showDialog(
      context: pageContext,
      builder: (dialogContext) => Dialog(
        backgroundColor: const Color(0xFFFFFBF7),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE24D56).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: Color(0xFFE24D56),
                    size: 26,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Keluar Akun Penghuni',
                  style: GoogleFonts.sora(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: const Color(0xFF2D241A),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(
                          dialogContext,
                          rootNavigator: true,
                        ).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF9C5A1A),
                          side: const BorderSide(color: Color(0xFFE6D4BE)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Batal'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.of(dialogContext, rootNavigator: true).pop();
                          await supabase.auth.signOut();
                          if (pageContext.mounted) {
                            Navigator.pushAndRemoveUntil(
                              pageContext,
                              MaterialPageRoute(
                                builder: (_) => const LoginPage(),
                              ),
                              (route) => false,
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE24D56),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Logout'),
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

  String _resolveProfileValue(String key, {String fallback = '-'}) {
    final value = profileData?[key];
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  String _resolveUserRoleLabel() {
    final role = _resolveProfileValue('role').toLowerCase();
    switch (role) {
      case 'admin':
        return 'Admin';
      case 'owner':
        return 'Owner';
      case 'user':
        return 'User';
      default:
        return role == '-' ? '-' : role;
    }
  }

  String _resolveApprovalLabel() {
    final approved = profileData?['is_approved'];
    if (approved == true) return 'Aktif';
    if (approved == false) return 'Menunggu Persetujuan';
    return '-';
  }

  String _resolveJoinDate() {
    for (final key in const ['kost_joined_at', 'entry_date', 'join_date']) {
      final raw = profileData?[key];
      if (raw == null) continue;
      final parsed = DateTime.tryParse(raw.toString());
      if (parsed != null) {
        return DateFormat('dd MMMM yyyy', 'id_ID').format(parsed.toLocal());
      }
    }
    return '-';
  }

  Future<void> _openKostLocation() async {
    try {
      await KostLocationService.openMap(kostData);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
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
        border: Border.all(color: UserPalette.border),
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
                      color: const Color(0xFF9C5A1A),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UserPalette.background,
      body: SafeArea(
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: UserPalette.primary),
              )
            : RefreshIndicator(
                onRefresh: _fetchData,
                color: UserPalette.primary,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      UserPageHeader(
                        title: 'Profil Saya',
                        subtitle:
                            'Kelola data akun, foto profil, dan detail kost yang sedang ditempati.',
                        trailing: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.person_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      UserSurfaceCard(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 42,
                              backgroundColor: const Color(0xFFF3E3CF),
                              backgroundImage:
                                  profileData?['profile_photo_url'] != null
                                  ? NetworkImage(
                                      profileData!['profile_photo_url']
                                          .toString(),
                                    )
                                  : null,
                              child: profileData?['profile_photo_url'] == null
                                  ? const Icon(
                                      Icons.person,
                                      size: 42,
                                      color: Color(0xFF9C5A1A),
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              _resolveProfileValue(
                                'full_name',
                                fallback: 'User',
                              ),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.sora(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF2D241A),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              supabase.auth.currentUser?.email ??
                                  _resolveProfileValue('email'),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                color: const Color(0xFF6B6257),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextButton.icon(
                              onPressed: _updateProfilePhoto,
                              icon: const Icon(
                                Icons.camera_alt_rounded,
                                color: Color(0xFF9C5A1A),
                                size: 18,
                              ),
                              label: Text(
                                'Ubah Foto Profil',
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFF9C5A1A),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const UserSectionHeader(
                        title: 'Informasi Akun',
                        subtitle: 'Detail dasar akun penghuni.',
                      ),
                      const SizedBox(height: 14),
                      _buildProfileField(
                        'Nama Pengguna',
                        _resolveProfileValue('full_name'),
                      ),
                      _buildProfileField(
                        'Nomor Telepon',
                        _resolveProfileValue('phone_number'),
                      ),
                      _buildProfileField(
                        'Email',
                        supabase.auth.currentUser?.email ??
                            _resolveProfileValue('email'),
                      ),
                      _buildProfileField(
                        'Status Akun',
                        _resolveApprovalLabel(),
                      ),
                      const SizedBox(height: 8),
                      const UserSectionHeader(
                        title: 'Informasi Kost',
                        subtitle:
                            'Data kost yang saat ini terhubung ke akunmu.',
                      ),
                      const SizedBox(height: 14),
                      _buildProfileField(
                        'Kost Ditempati',
                        kostData?['name']?.toString() ?? '-',
                      ),
                      _buildProfileField(
                        'Alamat Kost',
                        kostData?['address']?.toString() ?? '-',
                      ),
                      _buildProfileField(
                        'Titik Lokasi Kost',
                        KostLocationService.hasLocation(kostData)
                            ? KostLocationService.coordinateLabelFromMap(
                                kostData,
                              )
                            : 'Belum tersedia',
                        actionLabel: KostLocationService.hasLocation(kostData)
                            ? 'Lihat'
                            : null,
                        onAction: KostLocationService.hasLocation(kostData)
                            ? _openKostLocation
                            : null,
                      ),
                      _buildProfileField(
                        'Tanggal Masuk Kost',
                        _resolveJoinDate(),
                      ),
                      _buildProfileField(
                        'Password',
                        '••••••••',
                        actionLabel: 'Ubah',
                        onAction: _showChangePasswordDialog,
                      ),
                      const SizedBox(height: 8),
                      _buildRoleActionButton(
                        title: 'Keluar Akun Penghuni',
                        subtitle:
                            'Data login akan tetap tersimpan',
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
