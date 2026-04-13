import 'package:flutter/material.dart';
import 'package:kostly_pa/pages/admin_dashboard.dart';
import 'package:kostly_pa/pages/login_page.dart';
import 'package:kostly_pa/pages/owner_dashboard.dart';
import 'package:kostly_pa/pages/user_dashboard.dart';
import 'auth/register_user_page.dart';
import 'auth/register_owner_page.dart';

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kostly',
      initialRoute: '/',
      routes: {
        '/': (context) => LoginPage(),
        '/admin': (context) => AdminDashboard(),
        '/owner': (context) => OwnerDashboard(),
        '/user': (context) => UserDashboard(),
        '/register-user': (context) => RegisterUserPage(),
        '/register-owner': (context) => RegisterOwnerPage(),
      },
    );
  }
}