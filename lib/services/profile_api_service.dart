import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/user_profile_model.dart';

class ProfileApiService {
  const ProfileApiService();

  Uri _buildUri(String path) {
    return Uri.parse('${AppConfig.apiBaseUrl}/$path');
  }

  Future<UserProfileModel> fetchProfile(String username) async {
    final response = await http.get(
      _buildUri('${AppConfig.getProfilePath}?username=${Uri.encodeQueryComponent(username)}'),
      headers: {'Accept': 'application/json'},
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load profile');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic> && decoded['user'] is Map<String, dynamic>) {
      return UserProfileModel.fromJson(decoded['user'] as Map<String, dynamic>);
    }

    throw Exception('Invalid profile response');
  }

  Future<String?> updateProfile(UserProfileModel profile) async {
    final response = await http.post(
      _buildUri(AppConfig.updateProfilePath),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(profile.toUpdateJson()),
    );

    final decoded = _tryDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return null;
    }

    if (decoded is Map<String, dynamic> && decoded['message'] is String) {
      return decoded['message'] as String;
    }

    return 'Failed to update profile';
  }

  dynamic _tryDecode(String raw) {
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }
}
