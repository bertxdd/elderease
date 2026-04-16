import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../models/service_model.dart';
import '../services/auth_api_service.dart';
import 'home_screen.dart';
import 'register_screen.dart';
import 'volunteer_home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _rolePrefKey = 'login_selected_role';

  // Controllers read what the user types
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = const AuthApiService();
  String _selectedRole = 'User';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedRole();
  }

  Future<void> _loadSavedRole() async {
    final prefs = await SharedPreferences.getInstance();
    final savedRole = prefs.getString(_rolePrefKey);
    if (!mounted || savedRole == null) {
      return;
    }

    if (savedRole == 'User' || savedRole == 'Volunteer') {
      setState(() => _selectedRole = savedRole);
    }
  }

  Future<void> _updateSelectedRole(String role) async {
    setState(() => _selectedRole = role);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_rolePrefKey, role);
  }

  Future<void> _login() async {
    String identifier = _identifierController.text.trim();
    String password = _passwordController.text.trim();
    // Basic validation - check fields are not empty
    if (identifier.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final (
      success,
      accountUsername,
      confirmedRole,
      errorCode,
    ) = await _authService.login(
      identifier: identifier,
      password: password,
      role: _selectedRole.toLowerCase(),
    );

    if (!mounted) {
      return;
    }

    setState(() => _isLoading = false);

    if (!success) {
      if (errorCode == 'volunteer_registration_pending') {
        await _showVolunteerPendingDialog();
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(accountUsername)));
      return;
    }

    if (confirmedRole == 'volunteer') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => VolunteerHomeScreen(
            username: accountUsername,
            services: const <ServiceModel>[],
          ),
        ),
      );
      return;
    }

    // Default to user home UI.
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => HomeScreen(username: accountUsername)),
    );
  }

  Future<void> _showVolunteerPendingDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Registration Ongoing'),
          content: const Text(
            'Your volunteer registration is still under review. Please wait for admin approval before logging in.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openAdminPortal() async {
    final uri = Uri.parse(AppConfig.adminWebUrl);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) {
      return;
    }

    if (!launched) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open admin portal.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F0EE),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                32,
                16,
                32,
                16 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 32,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo icon placeholder
                    const Icon(
                      Icons.elderly,
                      size: 80,
                      color: Color(0xFFE8922A),
                    ),
                    const SizedBox(height: 16),
                    // App title
                    const Text(
                      'Welcome to\nElderEase',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE8922A),
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Username or Email Field
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Username or Email',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _identifierController,
                      decoration: InputDecoration(
                        hintText: 'Enter username or email',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Login As',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedRole,
                          items: const [
                            DropdownMenuItem(
                              value: 'User',
                              child: Text('User'),
                            ),
                            DropdownMenuItem(
                              value: 'Volunteer',
                              child: Text('Volunteer'),
                            ),
                          ],
                          onChanged: _isLoading
                              ? null
                              : (value) {
                                  if (value == null) {
                                    return;
                                  }
                                  _updateSelectedRole(value);
                                },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Password Field
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Password',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _passwordController,
                      obscureText: true, // Hides password characters
                      decoration: InputDecoration(
                        hintText: 'Enter your password',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    // Login Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE8922A),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Log In',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : _openAdminPortal,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFE8922A),
                          side: const BorderSide(color: Color(0xFFE8922A)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Open Admin Portal (Web)',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Register Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Don't have an account? "),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RegisterScreen(),
                            ),
                          ),
                          child: const Text(
                            'Register Now',
                            style: TextStyle(
                              color: Color(0xFFE8922A),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
