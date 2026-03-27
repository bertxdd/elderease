import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../config/maps_config.dart';
import '../models/service_request_model.dart';
import '../services/request_api_service.dart';

class NotificationRequestMapScreen extends StatefulWidget {
  final ServiceRequestModel request;

  const NotificationRequestMapScreen({
    super.key,
    required this.request,
  });

  @override
  State<NotificationRequestMapScreen> createState() =>
      _NotificationRequestMapScreenState();
}

class _NotificationRequestMapScreenState
    extends State<NotificationRequestMapScreen> {
  static const int _refreshIntervalSeconds = 10;

  final RequestApiService _requestApi = const RequestApiService();
  late ServiceRequestModel _currentRequest;
  LatLng? _destination;
  List<LatLng> _routePolyline = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  int _secondsUntilRefresh = _refreshIntervalSeconds;
  Timer? _pollTimer;

  LatLng? get _volunteerPoint {
    if (_currentRequest.volunteerLat == null ||
        _currentRequest.volunteerLng == null) {
      return null;
    }

    return LatLng(_currentRequest.volunteerLat!, _currentRequest.volunteerLng!);
  }

  @override
  void initState() {
    super.initState();
    _currentRequest = widget.request;
    _bootstrap();
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) {
        return;
      }

      if (_secondsUntilRefresh > 1) {
        setState(() {
          _secondsUntilRefresh -= 1;
        });
        return;
      }

      setState(() {
        _secondsUntilRefresh = _refreshIntervalSeconds;
      });

      if (_isRefreshing) {
        return;
      }

      _isRefreshing = true;
      await _refreshLiveData();
      _isRefreshing = false;
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _geocodeDestination();
    await _refreshLiveData();
  }

  Future<void> _geocodeDestination() async {
    final address = _currentRequest.address.trim();
    if (address.isEmpty) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      final uri = Uri.parse(
        'https://api.geoapify.com/v1/geocode/search?text=${Uri.encodeQueryComponent(address)}&limit=1&apiKey=$geoapifyApiKey',
      );

      final response = await http.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      final features = decoded['features'];
      if (features is! List || features.isEmpty) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      final first = features.first;
      if (first is! Map<String, dynamic>) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      final props = first['properties'];
      if (props is! Map<String, dynamic>) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      final lat = (props['lat'] as num?)?.toDouble();
      final lng = (props['lon'] as num?)?.toDouble();
      if (lat == null || lng == null) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      final destination = LatLng(lat, lng);
      final route = await _loadRoute(origin: _volunteerPoint, destination: destination);

      if (!mounted) {
        return;
      }

      setState(() {
        _destination = destination;
        _routePolyline = route;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _refreshLiveData() async {
    if (!mounted) {
      return;
    }

    try {
      final requests = await _requestApi.fetchRequests(_currentRequest.username);
      final latest = requests.where((r) => r.id == _currentRequest.id).toList();
      if (latest.isEmpty) {
        return;
      }

      final updated = latest.first;
      final needsRouteReload =
          updated.volunteerLat != _currentRequest.volunteerLat ||
          updated.volunteerLng != _currentRequest.volunteerLng;

      _currentRequest = updated;

      if (_destination != null && needsRouteReload) {
        final route = await _loadRoute(
          origin: _volunteerPoint,
          destination: _destination!,
        );
        if (!mounted) {
          return;
        }

        setState(() {
          _routePolyline = route;
        });
        return;
      }

      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      // Keep the map usable even if refresh fails.
    }
  }

  Future<List<LatLng>> _loadRoute({
    required LatLng? origin,
    required LatLng destination,
  }) async {
    if (origin == null) {
      return const [];
    }

    try {
      final uri = Uri.parse(
        'https://api.geoapify.com/v1/routing?waypoints=${origin.latitude},${origin.longitude}|${destination.latitude},${destination.longitude}&mode=drive&apiKey=$geoapifyApiKey',
      );

      final response = await http.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const [];
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return const [];
      }

      final features = decoded['features'];
      if (features is! List || features.isEmpty) {
        return const [];
      }

      final feature = features.first;
      if (feature is! Map<String, dynamic>) {
        return const [];
      }

      final geometry = feature['geometry'];
      if (geometry is! Map<String, dynamic>) {
        return const [];
      }

      final coordinates = geometry['coordinates'];
      if (coordinates is! List) {
        return const [];
      }

      final polyline = <LatLng>[];
      for (final point in coordinates) {
        if (point is! List || point.length < 2) {
          continue;
        }

        final lon = (point[0] as num?)?.toDouble();
        final lat = (point[1] as num?)?.toDouble();
        if (lat == null || lon == null) {
          continue;
        }

        polyline.add(LatLng(lat, lon));
      }

      return polyline;
    } catch (_) {
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final volunteerPoint = _volunteerPoint;
    final center = volunteerPoint ?? _destination ?? const LatLng(14.5995, 120.9842);

    final markers = <Marker>[
      if (_destination != null)
        Marker(
          point: _destination!,
          width: 40,
          height: 40,
          child: const Icon(
            Icons.home,
            color: Color(0xFFE8922A),
            size: 34,
          ),
        ),
      if (volunteerPoint != null)
        Marker(
          point: volunteerPoint,
          width: 40,
          height: 40,
          child: const Icon(
            Icons.person_pin_circle,
            color: Colors.blue,
            size: 36,
          ),
        ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFE8F0EE),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE8F0EE),
        elevation: 0,
        title: const Text(
          'Request Tracking Map',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8922A),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'LIVE ${_secondsUntilRefresh}s',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_currentRequest.statusLabel),
                  const SizedBox(height: 4),
                  if (_currentRequest.helperName != null &&
                      _currentRequest.helperName!.trim().isNotEmpty)
                    Text('Volunteer: ${_currentRequest.helperName!.trim()}'),
                  Text('Destination: ${_currentRequest.address}'),
                  if (volunteerPoint != null)
                    Text(
                      'Volunteer Position: ${volunteerPoint.latitude.toStringAsFixed(5)}, ${volunteerPoint.longitude.toStringAsFixed(5)}',
                    ),
                  if (_currentRequest.volunteerLocationUpdatedAt != null)
                    Text(
                      'Live Updated: ${_currentRequest.volunteerLocationUpdatedAt!.toLocal().toString().split('.').first}',
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Color(0xFFE8922A)),
                      )
                    : FlutterMap(
                        options: MapOptions(
                          initialCenter: center,
                          initialZoom: 14,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: geoapifyTileUrlTemplate,
                            userAgentPackageName: 'com.example.elderease',
                          ),
                          if (_routePolyline.isNotEmpty)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: _routePolyline,
                                  color: const Color(0xFFE8922A),
                                  strokeWidth: 5,
                                ),
                              ],
                            ),
                          MarkerLayer(markers: markers),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
