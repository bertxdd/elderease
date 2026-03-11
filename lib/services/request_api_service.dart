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
}
