import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
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
  List<String> _directionSteps = [];
  String _distanceLabel = '-';
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

    if (savedHome == null || volunteer == null) {
      if (mounted) {
        setState(() => _isLoadingMap = false);
      }
      return;
    }

    await _loadDirections(
      origin: volunteer,
      destination: savedHome,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _seniorLocation = savedHome;
      _volunteerLocation = volunteer;
      _isLoadingMap = false;
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
        'https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&mode=driving&key=$googleMapsApiKey',
      );

      final response = await http.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return;
      }

      final routes = decoded['routes'];
      if (routes is! List || routes.isEmpty) {
        return;
      }

      final route = routes.first;
      if (route is! Map<String, dynamic>) {
        return;
      }

      final legs = route['legs'];
      if (legs is! List || legs.isEmpty) {
        return;
      }

      final leg = legs.first;
      if (leg is! Map<String, dynamic>) {
        return;
      }

      final distance = leg['distance'];
      final distanceText = distance is Map<String, dynamic>
          ? (distance['text'] as String?)
          : null;

      final stepsRaw = leg['steps'];
      final steps = <String>[];
      if (stepsRaw is List) {
        for (final step in stepsRaw) {
          if (step is! Map<String, dynamic>) {
            continue;
          }
          final instruction = step['html_instructions'] as String?;
          final cleanInstruction = _stripHtml(instruction ?? '');
          if (cleanInstruction.isNotEmpty) {
            steps.add(cleanInstruction);
          }
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _distanceLabel = distanceText ?? '-';
        _directionSteps = steps;
      });
    } catch (_) {
      // Keep the screen usable even if directions fail.
    }
  }

  String _stripHtml(String html) {
    return html.replaceAll(RegExp('<[^>]*>'), '').replaceAll('&nbsp;', ' ').trim();
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>{
      if (_seniorLocation != null)
        Marker(
          markerId: const MarkerId('senior_home'),
          position: _seniorLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Senior Home'),
        ),
      if (_volunteerLocation != null)
        Marker(
          markerId: const MarkerId('volunteer_location'),
          position: _volunteerLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'Volunteer Location'),
        ),
    };

    final cameraTarget = _seniorLocation ?? _volunteerLocation ?? const LatLng(14.5995, 120.9842);

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
            // Volunteer Card
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
                  // Profile picture circle
                  CircleAvatar(radius: 30, backgroundColor: Colors.grey[300]),
                  const SizedBox(width: 16),
                  // Volunteer info
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
                      const Text('Robert@gmail.com', style: TextStyle(fontSize: 14)),
                      const Text('09086149697', style: TextStyle(fontSize: 14)),
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
            // Google Map section
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
                      child: CircularProgressIndicator(color: Color(0xFFE8922A)),
                    )
                  : (_seniorLocation == null || _volunteerLocation == null)
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'Map unavailable. Please save a valid address in profile and allow location permission.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: cameraTarget,
                            zoom: 14,
                          ),
                          markers: markers,
                          myLocationEnabled: true,
                          myLocationButtonEnabled: true,
                        ),
            ),
            const SizedBox(height: 16),
            // Directions section
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
                    const Text('Directions will appear here once route data is available.')
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
            // Services list
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
            // Confirm button
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
          } else if (i == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => YourServiceScreen(
                  username: widget.username,
                  services: widget.services,
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
          }
        },
      ),
    );
  }
}
