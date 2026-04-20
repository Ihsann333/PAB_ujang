import 'package:flutter/material.dart';
import 'package:kostly_pa/auth/register_owner_page.dart';
import 'package:kostly_pa/auth/register_user_page.dart';
import 'package:kostly_pa/pages/login_page.dart';
import 'package:kostly_pa/pages/user_page/dashboard.dart';
import 'package:kostly_pa/pages/admin_page/dashboard.dart';
import 'package:kostly_pa/pages/owner_page/dashboard.dart'; 

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
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginPage(),
        '/admin': (context) => const AdminDashboard(),
        '/owner': (context) => const OwnerDashboard(),
        '/user': (context) => const UserDashboard(),
        '/register-user': (context) => const RegisterUserPage(),
        '/register-owner': (context) => const RegisterOwnerPage(),
      },
    );
  }
}