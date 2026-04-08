import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/maps_config.dart';
import '../models/service_model.dart';
import '../models/user_profile_model.dart';
import '../services/profile_api_service.dart';
import '../widgets/bottom_nav.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'notification_screen.dart';
import 'your_service_screen.dart';
import 'volunteer_home_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String username;
  final List<ServiceModel> services;
  final bool isVolunteer;
  const ProfileScreen({
    super.key,
    required this.username,
    required this.services,
    this.isVolunteer = false,
  });
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dobController = TextEditingController();
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _zipController = TextEditingController();
  final _service = const ProfileApiService();

  bool _isLoading = true;
  bool _isSaving = false;
  String _headerName = '';
  String _headerEmail = '';
  DateTime? _memberSince;
  LatLng? _pinnedHomePoint;
  String _pinnedAddressLabel = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _zipController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);

    try {
      final profile = await _service.fetchProfile(widget.username);
      _applyProfile(profile);
      await _loadSavedPinnedLocation();
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to load profile data.'),
          backgroundColor: Color(0xFFE8922A),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadSavedPinnedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('home_lat');
    final lng = prefs.getDouble('home_lng');
    final address = prefs.getString('home_address') ?? '';

    if (!mounted) {
      return;
    }

    setState(() {
      _pinnedHomePoint = (lat != null && lng != null) ? LatLng(lat, lng) : null;
      _pinnedAddressLabel = address;
    });
  }

  void _applyProfile(UserProfileModel profile) {
    _fullNameController.text = profile.fullName;
    _emailController.text = profile.email;
    _phoneController.text = profile.phoneNumber;
    _dobController.text = profile.birthday;

    final parts = _splitAddress(profile.address);
    _streetController.text = parts.$1;
    _cityController.text = parts.$2;
    _zipController.text = parts.$3;

    setState(() {
      _headerName = profile.fullName.isNotEmpty
          ? profile.fullName
          : profile.username;
      _headerEmail = profile.email;
      _memberSince = profile.createdAt;
    });
  }

  (String, String, String) _splitAddress(String raw) {
    final chunks = raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (chunks.isEmpty) {
      return ('', '', '');
    }

    if (chunks.length == 1) {
      return (chunks[0], '', '');
    }

    if (chunks.length == 2) {
      return (chunks[0], chunks[1], '');
    }

    return (
      chunks.sublist(0, chunks.length - 2).join(', '),
      chunks[chunks.length - 2],
      chunks.last,
    );
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    DateTime initialDate = DateTime(now.year - 60, now.month, now.day);

    final parsed = DateTime.tryParse(_dobController.text.trim());
    if (parsed != null) {
      initialDate = parsed;
    }

    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: now,
      initialDate: initialDate,
    );

    if (picked != null) {
      _dobController.text =
          '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _saveProfile() async {
    if (_fullNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Full name is required.'),
          backgroundColor: Color(0xFFE8922A),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final address = [
      _streetController.text.trim(),
      _cityController.text.trim(),
      _zipController.text.trim(),
    ].where((e) => e.isNotEmpty).join(', ');

    final profile = UserProfileModel(
      username: widget.username,
      fullName: _fullNameController.text.trim(),
      email: _emailController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      birthday: _dobController.text.trim(),
      address: address,
      createdAt: _memberSince,
    );

    final error = await _service.updateProfile(profile);

    if (!mounted) {
      return;
    }

    setState(() => _isSaving = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: const Color(0xFFE8922A),
        ),
      );
      return;
    }

    // Cache a user-selected pin if available; otherwise geocode text address.
    if (_pinnedHomePoint != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('home_lat', _pinnedHomePoint!.latitude);
      await prefs.setDouble('home_lng', _pinnedHomePoint!.longitude);
      await prefs.setString('home_address', address);
    } else {
      await _geocodeAndStoreHomeLocation(address);
    }

    setState(() {
      _headerName = _fullNameController.text.trim();
      _headerEmail = _emailController.text.trim();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile updated successfully.'),
        backgroundColor: Color(0xFFE8922A),
      ),
    );
  }

  String _composeAddressFromFields() {
    return [
      _streetController.text.trim(),
      _cityController.text.trim(),
      _zipController.text.trim(),
    ].where((e) => e.isNotEmpty).join(', ');
  }

  Future<LatLng?> _geocodeAddressToLatLng(String address) async {
    final trimmed = address.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    try {
      final uri = Uri.parse(
        'https://api.geoapify.com/v1/geocode/search?text=${Uri.encodeQueryComponent(trimmed)}&limit=1&apiKey=$geoapifyApiKey',
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

      final properties = first['properties'];
      if (properties is! Map<String, dynamic>) {
        return null;
      }

      final lat = (properties['lat'] as num?)?.toDouble();
      final lng = (properties['lon'] as num?)?.toDouble();
      if (lat == null || lng == null) {
        return null;
      }

      return LatLng(lat, lng);
    } catch (_) {
      return null;
    }
  }

  Future<({String street, String city, String zip, String fullAddress})?>
      _reverseGeocode(LatLng point) async {
    try {
      final uri = Uri.parse(
        'https://api.geoapify.com/v1/geocode/reverse?lat=${point.latitude}&lon=${point.longitude}&apiKey=$geoapifyApiKey',
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

      final properties = first['properties'];
      if (properties is! Map<String, dynamic>) {
        return null;
      }

      final street = [
        properties['housenumber']?.toString() ?? '',
        properties['street']?.toString() ?? '',
      ].where((e) => e.trim().isNotEmpty).join(' ').trim();

      final city = (properties['city'] ?? properties['state'] ?? properties['county'] ?? '')
          .toString()
          .trim();
      final zip = (properties['postcode'] ?? '').toString().trim();
      final full = (properties['formatted'] ?? '').toString().trim();

      return (
        street: street,
        city: city,
        zip: zip,
        fullAddress: full,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _pinAddressOnMap() async {
    final currentAddress = _composeAddressFromFields();
    final geocoded = await _geocodeAddressToLatLng(currentAddress);

    final initialPoint =
        _pinnedHomePoint ?? geocoded ?? const LatLng(10.6765, 122.9509);

    if (!mounted) {
      return;
    }

    final picked = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => _ProfileMapPinScreen(initialPoint: initialPoint),
      ),
    );

    if (!mounted || picked == null) {
      return;
    }

    final reverse = await _reverseGeocode(picked);
    if (!mounted) {
      return;
    }

    setState(() {
      _pinnedHomePoint = picked;

      if (reverse != null) {
        if (reverse.street.isNotEmpty) {
          _streetController.text = reverse.street;
        }
        if (reverse.city.isNotEmpty) {
          _cityController.text = reverse.city;
        }
        if (reverse.zip.isNotEmpty) {
          _zipController.text = reverse.zip;
        }
        _pinnedAddressLabel = reverse.fullAddress;
      } else {
        _pinnedAddressLabel =
            'Pinned at ${picked.latitude.toStringAsFixed(5)}, ${picked.longitude.toStringAsFixed(5)}';
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Location pinned. Save changes to apply it to your profile.'),
        backgroundColor: Color(0xFFE8922A),
      ),
    );
  }

  Future<void> _geocodeAndStoreHomeLocation(String address) async {
    if (address.trim().isEmpty) {
      return;
    }

    try {
      final uri = Uri.parse(
        'https://api.geoapify.com/v1/geocode/search?text=${Uri.encodeQueryComponent(address)}&limit=1&apiKey=$geoapifyApiKey',
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

      final first = features.first;
      if (first is! Map<String, dynamic>) {
        return;
      }

      final properties = first['properties'];
      if (properties is! Map<String, dynamic>) {
        return;
      }

      final lat = (properties['lat'] as num?)?.toDouble();
      final lng = (properties['lon'] as num?)?.toDouble();

      if (lat == null || lng == null) {
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('home_lat', lat);
      await prefs.setDouble('home_lng', lng);
      await prefs.setString('home_address', address);
    } catch (_) {
      // Keep save flow friendly even if geocoding fails.
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Log Out'),
          content: const Text('Are you sure you want to log out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(
                'Log Out',
                style: TextStyle(color: Color(0xFFB00020)),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  String _memberSinceLabel() {
    if (_memberSince == null) {
      return 'Member since -';
    }

    final monthNames = const [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    final dt = _memberSince!;
    return 'Member since ${monthNames[dt.month - 1]} ${dt.year}';
  }

  // Reusable orange-outlined text field
  Widget _buildField(
    String label,
    TextEditingController controller, {
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFE8922A)),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFE8922A), width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                builder: (_) => widget.isVolunteer
                    ? VolunteerHomeScreen(
                        username: widget.username,
                        services: widget.services,
                        initialTab: 0,
                      )
                    : HomeScreen(
                        username: widget.username,
                        initialServices: widget.services,
                      ),
              ),
            );
          },
        ),
        title: const Text(
          'Profile Settings',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _isLoading
            ? const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFFE8922A)),
                ),
              )
            : Column(
                children: [
                  // Profile header card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 35,
                          backgroundColor: Colors.grey[300],
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _headerName.isNotEmpty
                                  ? _headerName
                                  : widget.username,
                              style: TextStyle(
                                color: Color(0xFFE8922A),
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              _headerEmail.isNotEmpty ? _headerEmail : '-',
                              style: const TextStyle(fontSize: 14),
                            ),
                            Text(
                              _memberSinceLabel(),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Personal Information section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Personal Information',
                          style: TextStyle(
                            color: Color(0xFFE8922A),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildField('Full Name', _fullNameController),
                        const SizedBox(height: 12),
                        _buildField('Email', _emailController),
                        const SizedBox(height: 12),
                        _buildField('Phone Number', _phoneController),
                        const SizedBox(height: 12),
                        _buildField(
                          'Date of Birth',
                          _dobController,
                          readOnly: true,
                          onTap: _pickBirthday,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Address Information section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Address Information',
                          style: TextStyle(
                            color: Color(0xFFE8922A),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildField('Street Address', _streetController),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildField('City', _cityController),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildField('Zip Code', _zipController),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _pinAddressOnMap,
                            icon: const Icon(
                              Icons.location_pin,
                              color: Color(0xFFE8922A),
                            ),
                            label: const Text(
                              'Pin Your Location on Map',
                              style: TextStyle(
                                color: Color(0xFFE8922A),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFE8922A)),
                            ),
                          ),
                        ),
                        if (_pinnedHomePoint != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _pinnedAddressLabel.isNotEmpty
                                ? 'Pinned: $_pinnedAddressLabel'
                                : 'Pinned coordinates: ${_pinnedHomePoint!.latitude.toStringAsFixed(5)}, ${_pinnedHomePoint!.longitude.toStringAsFixed(5)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE8922A),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Save Changes',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout, color: Color(0xFFB00020)),
                      label: const Text(
                        'Log Out',
                        style: TextStyle(
                          color: Color(0xFFB00020),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFB00020)),
                      ),
                    ),
                  ),
                ],
              ),
      ),
      bottomNavigationBar: widget.isVolunteer
          ? BottomNavigationBar(
              currentIndex: 2,
              onTap: (i) {
                if (i == 0) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VolunteerHomeScreen(
                        username: widget.username,
                        services: widget.services,
                        initialTab: 0,
                      ),
                    ),
                  );
                } else if (i == 1) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VolunteerHomeScreen(
                        username: widget.username,
                        services: widget.services,
                        initialTab: 1,
                      ),
                    ),
                  );
                }
              },
              selectedItemColor: const Color(0xFFE8922A),
              unselectedItemColor: Colors.grey,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.list_alt),
                  label: 'Open',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.assignment_turned_in_outlined),
                  label: 'Assigned',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  label: 'Account',
                ),
              ],
            )
          : BottomNav(
              currentIndex: 3,
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
                }
              },
            ),
    );
  }
}

class _ProfileMapPinScreen extends StatefulWidget {
  final LatLng initialPoint;

  const _ProfileMapPinScreen({required this.initialPoint});

  @override
  State<_ProfileMapPinScreen> createState() => _ProfileMapPinScreenState();
}

class _ProfileMapPinScreenState extends State<_ProfileMapPinScreen> {
  late LatLng _selectedPoint;

  @override
  void initState() {
    super.initState();
    _selectedPoint = widget.initialPoint;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F0EE),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE8F0EE),
        elevation: 0,
        title: const Text(
          'Pin Address on Map',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: _selectedPoint,
                    initialZoom: 15,
                    onTap: (_, point) {
                      setState(() {
                        _selectedPoint = point;
                      });
                    },
                  ),
                  children: [
                    TileLayer(urlTemplate: geoapifyTileUrlTemplate),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _selectedPoint,
                          width: 44,
                          height: 44,
                          child: const Icon(
                            Icons.location_pin,
                            color: Color(0xFFE8922A),
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Tap anywhere on the map to move the pin.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(_selectedPoint),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE8922A),
                ),
                child: const Text(
                  'Use This Pinned Location',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
