import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class AuthApiService {
  const AuthApiService();

  Uri _buildUri(String path) {
    return Uri.parse('${AppConfig.apiBaseUrl}/$path');
  }

  Future<(bool, String)> register({
    required String fullName,
    required String username,
    required String email,
    required String password,
    required String phoneNumber,
    String address = '',
  }) async {
    try {
      final response = await http.post(
        _buildUri(AppConfig.registerPath),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'full_name': fullName,
          'username': username,
          'email': email,
          'password': password,
          'phone_number': phoneNumber,
          'address': address,
        }),
      );

      final decoded = _tryDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return (true, 'Account created successfully.');
      }

      if (decoded is Map<String, dynamic> && decoded['message'] is String) {
        return (false, decoded['message'] as String);
      }

      return (false, 'Registration failed.');
    } catch (_) {
      return (false, 'Unable to connect to server.');
    }
  }

  Future<(bool, String)> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await http.post(
        _buildUri(AppConfig.loginPath),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      final decoded = _tryDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return (true, username);
      }

      if (decoded is Map<String, dynamic> && decoded['message'] is String) {
        return (false, decoded['message'] as String);
      }

      return (false, 'Login failed.');
    } catch (_) {
      return (false, 'Unable to connect to server.');
    }
  }

  dynamic _tryDecode(String raw) {
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }
}
