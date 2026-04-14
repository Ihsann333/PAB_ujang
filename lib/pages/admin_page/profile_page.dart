import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircleAvatar(radius: 50, backgroundColor: Color(0xFF9C5A1A), child: Icon(Icons.person, size: 50, color: Colors.white)),
          const SizedBox(height: 16),
          const Text("Admin Kostly", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 30),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9C5A1A), foregroundColor: Colors.white),
            onPressed: () => Navigator.pushReplacementNamed(context, '/'),
            child: const Text("Logout"),
          ),
        ],
      ),
    );
  }
}