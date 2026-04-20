import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _isVisible = false;
  double _scale = 0.8;

  @override
  void initState() {
    super.initState();
    
    // 1. Memulai animasi logo setelah delay kecil
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _isVisible = true;
          _scale = 1.0;
        });
      }
    });

    // 2. Navigasi otomatis ke LoginPage setelah 4 detik
    // Pastikan '/login' sudah terdaftar di routes pada file app.dart atau main.dart
    Timer(const Duration(seconds: 4), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2E8DA),
      body: Stack(
        // Perbaikan: Menggunakan Alignment.center (bukan Center)
        alignment: Alignment.center, 
        children: [
          // Latar belakang dengan aksen lingkaran artistik
          _buildBackgroundDecor(),
          
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animasi Logo (Fade & Scale)
              AnimatedScale(
                scale: _scale,
                duration: const Duration(milliseconds: 1500),
                curve: Curves.easeOutBack,
                child: AnimatedOpacity(
                  opacity: _isVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 1200),
                  child: _buildLogoSection(),
                ),
              ),
              const SizedBox(height: 30),
              
              // Nama Aplikasi
              AnimatedOpacity(
                opacity: _isVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 1500),
                child: Text(
                  "KOSTLY",
                  style: GoogleFonts.sora(
                    fontSize: 45,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF4A2C0A),
                    letterSpacing: 8,
                  ),
                ),
              ),
            ],
          ),

          // Loading bar minimalis di bagian bawah
          Positioned(
            bottom: 60,
            child: Column(
              children: [
                const SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    color: Color(0xFF9C5A1A),
                    strokeWidth: 2,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Smart Living • Easy Managing",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: const Color(0xFF9C5A1A).withOpacity(0.6),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoSection() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9C5A1A).withOpacity(0.2),
            blurRadius: 40,
            spreadRadius: 5,
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(60),
        child: Image.asset(
          'assets\\images\\login_logo_kostly.jpeg',
          width: 120,
          height: 120,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // Backup jika path gambar salah atau tidak ditemukan
            return Container(
              width: 120,
              height: 120,
              color: const Color(0xFF9C5A1A),
              child: const Icon(Icons.home_rounded, color: Colors.white, size: 50),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBackgroundDecor() {
    return Stack(
      children: [
        Positioned(
          top: -100,
          left: -50,
          child: CircleAvatar(
            radius: 120,
            backgroundColor: const Color(0xFF9C5A1A).withOpacity(0.04),
          ),
        ),
        Positioned(
          bottom: -80,
          right: -80,
          child: CircleAvatar(
            radius: 150,
            backgroundColor: const Color(0xFF9C5A1A).withOpacity(0.04),
          ),
        ),
      ],
    );
  }
}