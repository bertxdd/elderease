import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../config/maps_config.dart';
import '../models/service_request_model.dart';

class VolunteerRequestMapScreen extends StatefulWidget {
  final ServiceRequestModel request;

  const VolunteerRequestMapScreen({
    super.key,
    required this.request,
  });

  @override
  State<VolunteerRequestMapScreen> createState() =>
      _VolunteerRequestMapScreenState();
}

class _VolunteerRequestMapScreenState extends State<VolunteerRequestMapScreen> {
  static const int _refreshIntervalSeconds = 10;

  LatLng? _destination;
  LatLng? _volunteerPoint;
  List<LatLng> _routePolyline = [];
  List<String> _directionSteps = [];
  String _distanceLabel = '-';
  bool _isLoading = true;
  int _secondsUntilRefresh = _refreshIntervalSeconds;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
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

      await _refreshVolunteerLocationAndRoute();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _isLoading = true;
    });

    final destination = await _geocodeAddress(widget.request.address);
    final volunteer = await _getVolunteerLocation();

    if (destination == null || volunteer == null) {
      if (!mounted) {
        return;
      }

      setState(() {
        _destination = destination;
        _volunteerPoint = volunteer;
        _routePolyline = [];
        _directionSteps = [];
        _distanceLabel = '-';
        _isLoading = false;
      });
      return;
    }

    final routeData = await _loadRoute(origin: volunteer, destination: destination);

    if (!mounted) {
      return;
    }

    setState(() {
      _destination = destination;
      _volunteerPoint = volunteer;
      _routePolyline = routeData.polyline;
      _directionSteps = routeData.steps;
      _distanceLabel = routeData.distanceLabel;
      _isLoading = false;
    });
  }

  Future<void> _refreshVolunteerLocationAndRoute() async {
    final destination = _destination ?? await _geocodeAddress(widget.request.address);
    final volunteer = await _getVolunteerLocation();

    if (!mounted) {
      return;
    }

    if (destination == null || volunteer == null) {
      setState(() {
        _destination = destination;
        _volunteerPoint = volunteer;
        _routePolyline = [];
        _directionSteps = [];
        _distanceLabel = '-';
      });
      return;
    }

    final routeData = await _loadRoute(origin: volunteer, destination: destination);
    if (!mounted) {
      return;
    }

    setState(() {
      _destination = destination;
      _volunteerPoint = volunteer;
      _routePolyline = routeData.polyline;
      _directionSteps = routeData.steps;
      _distanceLabel = routeData.distanceLabel;
    });
  }

  Future<LatLng?> _getVolunteerLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    final position = await Geolocator.getCurrentPosition();
    return LatLng(position.latitude, position.longitude);
  }

  Future<LatLng?> _geocodeAddress(String address) async {
    final cleanAddress = address.trim();
    if (cleanAddress.isEmpty) {
      return null;
    }

    try {
      final uri = Uri.parse(
        'https://api.geoapify.com/v1/geocode/search?text=${Uri.encodeQueryComponent(cleanAddress)}&limit=1&apiKey=$geoapifyApiKey',
      );

      final response = await http.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final features = decoded['features'];
      if (features is! List || features.isEmpty) {
        return null;
      }

      final first = features.first;
      if (first is! Map<String, dynamic>) {
        return null;
      }

      final props = first['properties'];
      if (props is! Map<String, dynamic>) {
        return null;
      }

      final lat = (props['lat'] as num?)?.toDouble();
      final lng = (props['lon'] as num?)?.toDouble();
      if (lat == null || lng == null) {
        return null;
      }

      return LatLng(lat, lng);
    } catch (_) {
      return null;
    }
  }

  Future<_RouteData> _loadRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final fallbackDistanceKm =
        Geolocator.distanceBetween(
          origin.latitude,
          origin.longitude,
          destination.latitude,
          destination.longitude,
        ) /
        1000;
    final fallback = _RouteData(
      polyline: [origin, destination],
      steps: const ['Proceed toward the pinned user location.'],
      distanceLabel: '${fallbackDistanceKm.toStringAsFixed(1)} km',
    );

    try {
      final uri = Uri.parse(
        'https://api.geoapify.com/v1/routing?waypoints=${origin.latitude},${origin.longitude}|${destination.latitude},${destination.longitude}&mode=drive&details=instruction_details&apiKey=$geoapifyApiKey',
      );

      final response = await http.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return fallback;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return fallback;
      }

      final features = decoded['features'];
      if (features is! List || features.isEmpty) {
        return fallback;
      }

      final feature = features.first;
      if (feature is! Map<String, dynamic>) {
        return fallback;
      }

      final geometry = feature['geometry'];
      if (geometry is! Map<String, dynamic>) {
        return fallback;
      }

      final coordinates = geometry['coordinates'];
      if (coordinates is! List) {
        return fallback;
      }

      final polyline = <LatLng>[];
      for (final point in coordinates) {
        if (point is! List || point.length < 2) {
          continue;
        }

        if (point[0] is List) {
          for (final nested in point) {
            if (nested is! List || nested.length < 2) {
              continue;
            }

            final nestedLon = (nested[0] as num?)?.toDouble();
            final nestedLat = (nested[1] as num?)?.toDouble();
            if (nestedLat == null || nestedLon == null) {
              continue;
            }
            polyline.add(LatLng(nestedLat, nestedLon));
          }
          continue;
        }

        final lon = (point[0] as num?)?.toDouble();
        final lat = (point[1] as num?)?.toDouble();
        if (lat == null || lon == null) {
          continue;
        }
        polyline.add(LatLng(lat, lon));
      }

      if (polyline.isEmpty) {
        polyline.addAll(fallback.polyline);
      }

      final properties = feature['properties'];
      if (properties is! Map<String, dynamic>) {
        return _RouteData(
          polyline: polyline,
          steps: fallback.steps,
          distanceLabel: fallback.distanceLabel,
        );
      }

      final distanceMeters = (properties['distance'] as num?)?.toDouble();
      final distanceText = distanceMeters == null
          ? fallback.distanceLabel
          : '${(distanceMeters / 1000).toStringAsFixed(1)} km';

      final steps = <String>[];
      final legs = properties['legs'];
      if (legs is List && legs.isNotEmpty) {
        final firstLeg = legs.first;
        if (firstLeg is Map<String, dynamic>) {
          final stepsRaw = firstLeg['steps'];
          if (stepsRaw is List) {
            for (final step in stepsRaw) {
              if (step is! Map<String, dynamic>) {
                continue;
              }

              final instruction = step['instruction'];
              if (instruction is Map<String, dynamic>) {
                final text = instruction['text'] as String?;
                if (text != null && text.trim().isNotEmpty) {
                  steps.add(text.trim());
                }
              }
            }
          }
        }
      }

      if (steps.isEmpty) {
        steps.addAll(fallback.steps);
      }

      return _RouteData(
        polyline: polyline,
        steps: steps,
        distanceLabel: distanceText,
      );
    } catch (_) {
      return fallback;
    }
  }

  @override
  Widget build(BuildContext context) {
    final center = _volunteerPoint ?? _destination ?? const LatLng(14.5995, 120.9842);

    final markers = <Marker>[
      if (_destination != null)
        Marker(
          point: _destination!,
          width: 40,
          height: 40,
          child: const Icon(
            Icons.home,
            color: Color(0xFFD32F2F),
            size: 34,
          ),
        ),
      if (_volunteerPoint != null)
        Marker(
          point: _volunteerPoint!,
          width: 40,
          height: 40,
          child: const Icon(
            Icons.my_location,
            color: Color(0xFF1976D2),
            size: 30,
          ),
        ),
    ];

    final isMapReady = _destination != null && _volunteerPoint != null;

    return Scaffold(
      backgroundColor: const Color(0xFFE8F0EE),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE8F0EE),
        elevation: 0,
        title: const Text(
          'User Location Map',
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
                  Text('Requested by: ${widget.request.username}'),
                  const SizedBox(height: 4),
                  Text('Destination: ${widget.request.address}'),
                  const SizedBox(height: 4),
                  Text('Distance: $_distanceLabel'),
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
                    : !isMapReady
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Unable to load route. Make sure location permission is granted and the user address is valid.',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton.icon(
                                onPressed: _bootstrap,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE8922A),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
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
            const SizedBox(height: 12),
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
                  const Text(
                    'Directions',
                    style: TextStyle(
                      color: Color(0xFFE8922A),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (_directionSteps.isEmpty)
                    const Text('Directions will appear when route data is available.')
                  else
                    ..._directionSteps.take(4).toList().asMap().entries.map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text('${entry.key + 1}. ${entry.value}'),
                          ),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteData {
  final List<LatLng> polyline;
  final List<String> steps;
  final String distanceLabel;

  const _RouteData({
    this.polyline = const [],
    this.steps = const [],
    this.distanceLabel = '-',
  });
}
