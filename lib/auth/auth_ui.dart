import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AuthPalette {
  static const background = Color(0xFFF2E8DA);
  static const primary = Color(0xFF9C5A1A);
  static const primaryDark = Color(0xFF4A2C0A);
  static const surface = Colors.white;
  static const inputFill = Color(0xFFF8F1E7);
  static const softAccent = Color(0xFFF3E3CF);
  static const border = Color(0xFFE8D8C4);
  static const muted = Color(0xFF8C7D6E);
}

class AuthScreenShell extends StatelessWidget {
  const AuthScreenShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.backLabel,
    this.onBack,
    this.maxWidth = 430,
    this.headerHeight = 230,
    this.cardOverlap = 34,
    this.showLogo = true,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final String? backLabel;
  final VoidCallback? onBack;
  final double maxWidth;
  final double headerHeight;
  final double cardOverlap;
  final bool showLogo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthPalette.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                children: [
                  _AuthHero(
                    title: title,
                    subtitle: subtitle,
                    backLabel: backLabel,
                    onBack: onBack,
                    height: headerHeight,
                    showLogo: showLogo,
                  ),
                  Transform.translate(
                    offset: Offset(0, -cardOverlap),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
                      decoration: BoxDecoration(
                        color: AuthPalette.surface,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 28,
                            offset: const Offset(0, 18),
                          ),
                        ],
                      ),
                      child: child,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthHero extends StatelessWidget {
  const _AuthHero({
    required this.title,
    required this.subtitle,
    required this.height,
    required this.showLogo,
    this.backLabel,
    this.onBack,
  });

  final String title;
  final String subtitle;
  final String? backLabel;
  final VoidCallback? onBack;
  final double height;
  final bool showLogo;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFB26A25),
            AuthPalette.primary,
            Color(0xFF7B4313),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -20,
            left: -18,
            child: Container(
              width: 124,
              height: 124,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.14),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 26,
            left: 18,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.10),
                borderRadius: BorderRadius.circular(32),
              ),
            ),
          ),
          Positioned(
            right: 6,
            top: 8,
            child: Transform.rotate(
              angle: 0.26,
              child: Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white.withOpacity(0.14),
                    width: 8,
                  ),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          Positioned(
            right: 22,
            top: 26,
            child: Transform.rotate(
              angle: 0.32,
              child: Container(
                width: 12,
                height: 74,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (backLabel != null && onBack != null)
                TextButton.icon(
                  onPressed: onBack,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: Text(
                    backLabel!,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const Spacer(),
              if (showLogo)
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.white.withOpacity(0.16)),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'assets/images/login_logo_kostly.jpeg',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              const SizedBox(height: 18),
              Text(
                title,
                style: GoogleFonts.sora(
                  fontSize: 32,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.88),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

InputDecoration authInputDecoration({
  required String hint,
  required IconData icon,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: GoogleFonts.plusJakartaSans(
      color: AuthPalette.muted,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    ),
    prefixIcon: Icon(icon, color: AuthPalette.primary, size: 20),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: AuthPalette.inputFill,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: AuthPalette.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: AuthPalette.primary, width: 1.2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: Colors.redAccent),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: Colors.redAccent),
    ),
  );
}

ButtonStyle authPrimaryButtonStyle() {
  return ElevatedButton.styleFrom(
    backgroundColor: AuthPalette.primary,
    foregroundColor: Colors.white,
    minimumSize: const Size(double.infinity, 54),
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    textStyle: GoogleFonts.plusJakartaSans(
      fontWeight: FontWeight.w700,
      fontSize: 15,
    ),
  );
}

class AuthSectionCard extends StatelessWidget {
  const AuthSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AuthPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AuthPalette.primaryDark,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: AuthPalette.muted,
              ),
            ),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class AuthImagePickerPreview extends StatelessWidget {
  const AuthImagePickerPreview({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.imageProvider,
    this.radius = 38,
    this.icon = Icons.camera_alt_rounded,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final ImageProvider<Object>? imageProvider;
  final double radius;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AuthPalette.inputFill,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AuthPalette.border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: radius,
              backgroundColor: AuthPalette.softAccent,
              backgroundImage: imageProvider,
              child: imageProvider == null
                  ? Icon(icon, color: AuthPalette.primary, size: 28)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      color: AuthPalette.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AuthPalette.muted,
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
}
