import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/maps_config.dart';
import '../models/service_model.dart';
import '../widgets/bottom_nav.dart';
import 'home_screen.dart';
import 'notification_screen.dart';
import 'profile_screen.dart';
import 'your_service_screen.dart';

class VolunteerScreen extends StatefulWidget {
  final String username;
  final List<ServiceModel> services;
  const VolunteerScreen({
    super.key,
    required this.username,
    required this.services,
  });

  @override
  State<VolunteerScreen> createState() => _VolunteerScreenState();
}

class _VolunteerScreenState extends State<VolunteerScreen> {
  LatLng? _seniorLocation;
  LatLng? _volunteerLocation;
  List<LatLng> _routePolyline = [];
  List<String> _directionSteps = [];
  String _distanceLabel = '-';
  String _mapUnavailableMessage =
      'Map unavailable. Please save a valid address in profile and allow location permission.';
  bool _isLoadingMap = true;

  @override
  void initState() {
    super.initState();
    _loadMapAndDirections();
  }

  Future<void> _loadMapAndDirections() async {
    setState(() => _isLoadingMap = true);

    final savedHome = await _loadSeniorHomeLocation();
    final volunteer = await _getVolunteerLocation();

    String? unavailableReason;
    if (savedHome == null && volunteer == null) {
      unavailableReason =
          'Map unavailable. Please save a valid address in profile and enable location services and permission.';
    } else if (savedHome == null) {
      unavailableReason =
          'Map unavailable. Please save a valid address in profile first.';
    } else if (volunteer == null) {
      unavailableReason =
          'Map unavailable. Please enable location services and allow location permission first.';
    }

    if (savedHome == null || volunteer == null) {
      if (mounted) {
        setState(() {
          _isLoadingMap = false;
          _seniorLocation = savedHome;
          _volunteerLocation = volunteer;
          _routePolyline = [];
          _directionSteps = [];
          _distanceLabel = '-';
          if (unavailableReason != null) {
            _mapUnavailableMessage = unavailableReason;
          }
        });
      }
      return;
    }

    await _loadDirections(origin: volunteer, destination: savedHome);

    if (!mounted) {
      return;
    }

    setState(() {
      _seniorLocation = savedHome;
      _volunteerLocation = volunteer;
      _isLoadingMap = false;
      _mapUnavailableMessage = '';
    });
  }

  Future<LatLng?> _loadSeniorHomeLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('home_lat');
    final lng = prefs.getDouble('home_lng');

    if (lat == null || lng == null) {
      return null;
    }
    return LatLng(lat, lng);
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

  Future<void> _loadDirections({
    required LatLng origin,
    required LatLng destination,
  }) async {
    try {
      final uri = Uri.parse(
        'https://api.geoapify.com/v1/routing?waypoints=${origin.latitude},${origin.longitude}|${destination.latitude},${destination.longitude}&mode=drive&details=instruction_details&apiKey=$geoapifyApiKey',
      );

      final response = await http.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return;
      }

      final features = decoded['features'];
      if (features is! List || features.isEmpty) {
        return;
      }

      final feature = features.first;
      if (feature is! Map<String, dynamic>) {
        return;
      }

      final geometry = feature['geometry'];
      if (geometry is! Map<String, dynamic>) {
        return;
      }

      final coordinates = geometry['coordinates'];
      if (coordinates is! List) {
        return;
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

      final properties = feature['properties'];
      if (properties is! Map<String, dynamic>) {
        return;
      }

      final distanceMeters = (properties['distance'] as num?)?.toDouble();
      final distanceText = distanceMeters == null
          ? null
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
        steps.add('Follow the highlighted route to the destination.');
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _distanceLabel = distanceText ?? '-';
        _directionSteps = steps;
        _routePolyline = polyline;
      });
    } catch (_) {
      // Keep the screen usable even if directions fail.
    }
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[
      if (_seniorLocation != null)
        Marker(
          point: _seniorLocation!,
          width: 40,
          height: 40,
          child: const Icon(
            Icons.location_on,
            color: Color(0xFFD32F2F),
            size: 36,
          ),
        ),
      if (_volunteerLocation != null)
        Marker(
          point: _volunteerLocation!,
          width: 40,
          height: 40,
          child: const Icon(
            Icons.my_location,
            color: Color(0xFF1976D2),
            size: 30,
          ),
        ),
    ];

    final cameraTarget =
        _seniorLocation ??
        _volunteerLocation ??
        const LatLng(14.5995, 120.9842);

    return Scaffold(
      backgroundColor: const Color(0xFFE8F0EE),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE8F0EE),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => HomeScreen(
                  username: widget.username,
                  initialServices: widget.services,
                ),
              ),
            );
          },
        ),
        title: const Text(
          'Your Service',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const Text(
                'VOLUNTEER',
                style: TextStyle(
                  color: Color(0xFFE8922A),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    CircleAvatar(radius: 30, backgroundColor: Colors.grey[300]),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Robert',
                          style: TextStyle(
                            color: Color(0xFFE8922A),
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const Text(
                          'Robert@gmail.com',
                          style: TextStyle(fontSize: 14),
                        ),
                        const Text(
                          '09086149697',
                          style: TextStyle(fontSize: 14),
                        ),
                        Text(
                          '$_distanceLabel away',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFFE8922A),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                height: 260,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: _isLoadingMap
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFE8922A),
                        ),
                      )
                    : (_seniorLocation == null || _volunteerLocation == null)
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _mapUnavailableMessage,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: _loadMapAndDirections,
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
                          initialCenter: cameraTarget,
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
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Driving Directions',
                      style: TextStyle(
                        color: Color(0xFFE8922A),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_directionSteps.isEmpty)
                      const Text(
                        'Directions will appear here once route data is available.',
                      )
                    else
                      ..._directionSteps.asMap().entries.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text('${entry.key + 1}. ${entry.value}'),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ...widget.services.map(
                (service) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey[300],
                    ),
                    title: Text(
                      service.name,
                      style: const TextStyle(
                        color: Color(0xFFE8922A),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.delete_outline,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Service confirmed! Volunteer is on the way.',
                        ),
                        backgroundColor: Color(0xFFE8922A),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE8922A),
                  ),
                  child: const Text(
                    'Confirm Service',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNav(
        currentIndex: 1,
        onTap: (i) {
          if (i == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => HomeScreen(
                  username: widget.username,
                  initialServices: widget.services,
                ),
              ),
            );
          } else if (i == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => NotificationScreen(
                  username: widget.username,
                  services: widget.services,
                ),
              ),
            );
          } else if (i == 3) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => ProfileScreen(
                  username: widget.username,
                  services: widget.services,
                ),
              ),
            );
          } else if (i == 4) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => YourServiceScreen(
                  username: widget.username,
                  services: widget.services,
                ),
              ),
            );
          }
        },
      ),
    );
  }
}
