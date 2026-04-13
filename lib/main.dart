import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://ufcxaepptzixuucsfyne.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVmY3hhZXBwdHppeHV1Y3NmeW5lIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU3MjE0MjgsImV4cCI6MjA5MTI5NzQyOH0.CrC2WDh_0YJe3kgzpNsAzGDraVdQFnfn63Y09r0QIyY',
  );

  runApp(MyApp());
}