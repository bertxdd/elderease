import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/service_request_model.dart';

class RequestApiService {
  const RequestApiService();

  Uri _buildUri(String path) {
    return Uri.parse('${AppConfig.apiBaseUrl}/$path');
  }

  Future<bool> createRequest(ServiceRequestModel request) async {
    final response = await http.post(
      _buildUri(AppConfig.createRequestPath),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return false;
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded['success'] == true || decoded['status'] == 'ok';
    }

    return false;
  }

  Future<List<ServiceRequestModel>> fetchRequests(String username) async {
    final response = await http.get(
      _buildUri(
        '${AppConfig.listRequestsPath}?username=${Uri.encodeQueryComponent(username)}',
      ),
      headers: {'Accept': 'application/json'},
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to fetch requests');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic> && decoded['data'] is List<dynamic>) {
      return (decoded['data'] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(ServiceRequestModel.fromJson)
          .toList();
    }

    if (decoded is List<dynamic>) {
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(ServiceRequestModel.fromJson)
          .toList();
    }

    return const [];
  }

  Future<List<ServiceRequestModel>> fetchVolunteerRequests({
    required String username,
    required bool assigned,
  }) async {
    final scope = assigned ? 'assigned' : 'open';
    final response = await http.get(
      _buildUri(
        '${AppConfig.listVolunteerRequestsPath}?username=${Uri.encodeQueryComponent(username)}&scope=$scope',
      ),
      headers: {'Accept': 'application/json'},
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to fetch volunteer requests');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic> && decoded['data'] is List<dynamic>) {
      return (decoded['data'] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(ServiceRequestModel.fromJson)
          .toList();
    }

    return const [];
  }

  Future<bool> acceptRequest({
    required String requestId,
    required String username,
  }) async {
    final response = await http.post(
      _buildUri(AppConfig.acceptRequestPath),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'request_id': requestId,
        'username': username,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return false;
    }

    final decoded = jsonDecode(response.body);
    return decoded is Map<String, dynamic> && decoded['success'] == true;
  }

  Future<bool> updateRequestStatus({
    required String requestId,
    required RequestStatus status,
    String? username,
  }) async {
    final payload = <String, dynamic>{
      'request_id': requestId,
      'status': status.name,
    };
    if (username != null && username.trim().isNotEmpty) {
      payload['username'] = username.trim();
    }

    final response = await http.post(
      _buildUri(AppConfig.updateRequestStatusPath),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return false;
    }

    final decoded = jsonDecode(response.body);
    return decoded is Map<String, dynamic> && decoded['success'] == true;
  }

  Future<bool> updateVolunteerLocation({
    required String requestId,
    required String username,
    required double lat,
    required double lng,
  }) async {
    final response = await http.post(
      _buildUri(AppConfig.updateVolunteerLocationPath),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'request_id': requestId,
        'username': username,
        'lat': lat,
        'lng': lng,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return false;
    }

    final decoded = jsonDecode(response.body);
    return decoded is Map<String, dynamic> && decoded['success'] == true;
  }
}
