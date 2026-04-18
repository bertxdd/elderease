import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/service_request_model.dart';
import 'request_api_service.dart';

class RequestRepository {
  static const String _cacheKey = 'elderease_request_cache';
  final RequestApiService _apiService;

  const RequestRepository({RequestApiService? apiService})
    : _apiService = apiService ?? const RequestApiService();

  Future<List<ServiceRequestModel>> getRequestsForUser(String username) async {
    final local = await _loadLocal();
    final localForUser = local.where((r) => r.username == username).toList();

    try {
      final remote = await _apiService.fetchRequests(username);
      final activeRemote = _withoutCompleted(remote);
      await _mergeAndPersist(localForUser, activeRemote);
      return _sortByNewest(activeRemote);
    } catch (_) {
      return _sortByNewest(_withoutCompleted(localForUser));
    }
  }

  Future<ServiceRequestModel> createRequest(ServiceRequestModel request) async {
    final localDraft = request.copyWith(synced: false);
    final all = await _loadLocal();
    all.add(localDraft);
    await _saveLocal(all);

    try {
      final created = await _apiService.createRequest(request);
      if (!created) {
        return localDraft;
      }

      final refreshed = localDraft.copyWith(synced: true);
      final updated = all.map((r) {
        if (r.id == localDraft.id) {
          return refreshed;
        }
        return r;
      }).toList();
      await _saveLocal(updated);
      return refreshed;
    } catch (_) {
      return localDraft;
    }
  }

  Future<void> _mergeAndPersist(
    List<ServiceRequestModel> local,
    List<ServiceRequestModel> remote,
  ) async {
    final all = await _loadLocal();
    final others = all.where((r) => !local.any((l) => l.id == r.id)).toList();

    final unsyncedLocal = local
        .where((l) => !l.synced && !remote.any((r) => r.id == l.id))
        .toList();

    final merged = [...others, ...remote, ...unsyncedLocal];
    await _saveLocal(merged);
  }

  List<ServiceRequestModel> _withoutCompleted(List<ServiceRequestModel> items) {
    return items
        .where((item) => item.status != RequestStatus.completed)
        .toList();
  }

  Future<List<ServiceRequestModel>> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List<dynamic>) {
      return [];
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(ServiceRequestModel.fromJson)
        .toList();
  }

  Future<void> _saveLocal(List<ServiceRequestModel> items) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(items.map((e) => e.toJson()).toList());
    await prefs.setString(_cacheKey, payload);
  }

  List<ServiceRequestModel> _sortByNewest(List<ServiceRequestModel> items) {
    final sorted = [...items];
    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }
}
