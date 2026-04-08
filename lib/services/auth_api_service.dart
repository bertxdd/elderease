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
    String role = 'user',
    String birthday = '',
    String address = '',
  }) async {
    try {
      final response = await http.post(
        _buildUri(AppConfig.registerPath),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'full_name': fullName,
          'username': username,
          'role': role,
          'email': email,
          'password': password,
          'phone_number': phoneNumber,
          'birthday': birthday,
          'address': address,
        }),
      );

      final decoded = _tryDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (decoded is Map<String, dynamic> && decoded['message'] is String) {
          return (true, decoded['message'] as String);
        }
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

  Future<(bool, String, String, String?)> login({
    required String identifier,
    required String password,
    String role = 'user',
  }) async {
    try {
      final response = await http.post(
        _buildUri(AppConfig.loginPath),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'identifier': identifier,
          'password': password,
          'role': role,
        }),
      );

      final decoded = _tryDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        var resolvedUsername = identifier;
        var resolvedRole = role;
        if (decoded is Map<String, dynamic>) {
          final user = decoded['user'];
          if (user is Map<String, dynamic>) {
            if (user['username'] is String) {
              resolvedUsername = (user['username'] as String).trim();
            }
            if (user['role'] is String) {
              resolvedRole = (user['role'] as String).toLowerCase();
            }
          }
        }
        return (true, resolvedUsername, resolvedRole, null);
      }

      if (decoded is Map<String, dynamic> && decoded['message'] is String) {
        final code = decoded['code'] as String?;
        return (false, decoded['message'] as String, '', code);
      }

      return (false, 'Login failed.', '', null);
    } catch (_) {
      return (false, 'Unable to connect to server.', '', null);
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
