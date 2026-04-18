import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const ElderEaseApp());
}

class ElderEaseApp extends StatelessWidget {
  const ElderEaseApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ElderEase',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Main orange color used throughout the app
        primaryColor: const Color(0xFFE8922A),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE8922A)),
        // Large fonts for senior accessibility
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontSize: 18),
          bodyMedium: TextStyle(fontSize: 16),
        ),
        scaffoldBackgroundColor: const Color(0xFFE8F0EE),
      ),
      home: const SplashScreen(),
    );
  }
}
