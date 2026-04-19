import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/service_history_model.dart';

class ServiceHistoryApiService {
  const ServiceHistoryApiService();

  Uri _buildUri(String path, Map<String, String> queryParams) {
    return Uri.parse('${AppConfig.apiBaseUrl}/$path')
        .replace(queryParameters: queryParams);
  }

  Future<(bool, List<ServiceHistoryItem>, String)> getServiceHistory({
    required String username,
    required String role,
  }) async {
    try {
      final response = await http.get(
        _buildUri('get_service_history.php', {
          'username': username,
          'role': role,
        }),
      );

      final decoded = _tryDecode(response.body);

      if (response.statusCode == 200 &&
          decoded is Map<String, dynamic> &&
          (decoded['success'] == true)) {
        final List<ServiceHistoryItem> items = <ServiceHistoryItem>[];

        final data = decoded['data'];
        if (data is List) {
          for (final item in data) {
            if (item is Map<String, dynamic>) {
              items.add(ServiceHistoryItem.fromJson(item));
            }
          }
        }

        return (true, items, 'History retrieved successfully');
      }

      final errorMsg = decoded is Map<String, dynamic>
          ? (decoded['message']?.toString() ?? 'Failed to fetch history')
          : 'Failed to fetch history';

      return (false, <ServiceHistoryItem>[], errorMsg);
    } catch (e) {
      return (false, <ServiceHistoryItem>[], 'Network error: $e');
    }
  }

  dynamic _tryDecode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }
}
