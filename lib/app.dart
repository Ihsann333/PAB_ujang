import 'package:flutter/material.dart';
import 'package:kostly_pa/auth/register_owner_page.dart';
import 'package:kostly_pa/auth/register_user_page.dart';
import 'package:kostly_pa/pages/login_page.dart';
import 'package:kostly_pa/pages/user_page/dashboard.dart';
import 'package:kostly_pa/pages/admin_page/dashboard.dart';
import 'package:kostly_pa/pages/owner_page/dashboard.dart';
// 1. IMPORT SPLASH SCREEN KAMU
import 'package:kostly_pa/pages/splash_screen.dart'; 

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kostly',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF1E6D9),
      ),
      // 2. GANTI initialRoute menjadi '/' (yang nanti kita isi SplashScreen)
      initialRoute: '/', 
      routes: {
        // 3. JADIKAN SplashScreen sebagai halaman pertama ('/')
        '/': (context) => const SplashScreen(),
        
        // 4. PINDAHKAN route login ke '/login'
        '/login': (context) => const LoginPage(), 
        
        '/admin': (context) => const AdminDashboard(),
        '/owner': (context) => const OwnerDashboard(),
        '/user': (context) => const UserDashboard(),
        '/register-user': (context) => const RegisterUserPage(),
        '/register-owner': (context) => const RegisterOwnerPage(),
      },
    );
  }
}