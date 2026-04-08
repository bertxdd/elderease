import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'package:latlong2/latlong.dart';

import '../config/maps_config.dart';
import '../models/service_model.dart';
import '../models/service_request_model.dart';
import '../services/request_api_service.dart';
import 'profile_screen.dart';
import 'volunteer_request_map_screen.dart';

class VolunteerHomeScreen extends StatefulWidget {
  final String username;
  final List<ServiceModel> services;
  final int initialTab;

  const VolunteerHomeScreen({
    super.key,
    required this.username,
    required this.services,
    this.initialTab = 0,
  });

  @override
  State<VolunteerHomeScreen> createState() => _VolunteerHomeScreenState();
}

class _VolunteerHomeScreenState extends State<VolunteerHomeScreen> {
  final RequestApiService _api = const RequestApiService();

  late int _currentTab;
  List<ServiceRequestModel> _openRequests = const [];
  List<ServiceRequestModel> _assignedRequests = const [];
  bool _isLoading = true;
  Timer? _pollTimer;

  bool get _hasActiveAssignment => _assignedRequests.any(
        (r) => r.status == RequestStatus.matched ||
            r.status == RequestStatus.enRoute ||
            r.status == RequestStatus.arrived,
      );

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;
    _refresh();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _refresh(silent: true);
      _pushVolunteerLocationForAssigned(silent: true);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadRequests({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    final openFuture = _api.fetchVolunteerRequests(
      username: widget.username,
      assigned: false,
    );
    final assignedFuture = _api.fetchVolunteerRequests(
      username: widget.username,
      assigned: true,
    );

    final results = await Future.wait([openFuture, assignedFuture]);
    if (!mounted) {
      return;
    }

    setState(() {
      _openRequests = results[0];
      _assignedRequests = results[1];
      _isLoading = false;
    });
  }

  Future<void> _refresh({bool silent = false}) async {
    await _loadRequests(silent: silent);
  }

  Future<void> _pushVolunteerLocationForAssigned({bool silent = false}) async {
    final active = _assignedRequests
        .where(
          (r) => r.status == RequestStatus.matched ||
              r.status == RequestStatus.enRoute ||
              r.status == RequestStatus.arrived,
        )
        .toList();

    if (active.isEmpty) {
      return;
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    final position = await Geolocator.getCurrentPosition();

    for (final request in active) {
      await _api.updateVolunteerLocation(
        requestId: request.id,
        username: widget.username,
        lat: position.latitude,
        lng: position.longitude,
      );
    }

    if (!silent) {
      await _refresh(silent: true);
    }
  }

  Future<void> _acceptRequest(ServiceRequestModel request) async {
    if (_hasActiveAssignment) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You can only handle one assigned request at a time. Complete your current request first.',
          ),
          backgroundColor: Color(0xFFE8922A),
        ),
      );
      return;
    }

    final ok = await _api.acceptRequest(
      requestId: request.id,
      username: widget.username,
    );

    if (!mounted) {
      return;
    }

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to accept request. It may already be taken.'),
          backgroundColor: Color(0xFFE8922A),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Request accepted. User will now see your assignment.'),
        backgroundColor: Color(0xFFE8922A),
      ),
    );

    await _pushVolunteerLocationForAssigned();
    await _refresh();
  }

  RequestStatus? _nextStatus(RequestStatus current) {
    switch (current) {
      case RequestStatus.matched:
        return RequestStatus.enRoute;
      case RequestStatus.enRoute:
        return RequestStatus.arrived;
      case RequestStatus.arrived:
        return RequestStatus.completed;
      case RequestStatus.requested:
      case RequestStatus.completed:
        return null;
    }
  }

  String _nextStatusLabel(RequestStatus current) {
    switch (current) {
      case RequestStatus.matched:
        return 'Mark On The Way';
      case RequestStatus.enRoute:
        return 'Mark Arrived';
      case RequestStatus.arrived:
        return 'Mark Completed';
      case RequestStatus.requested:
      case RequestStatus.completed:
        return 'Update';
    }
  }

  Future<void> _updateStatus(ServiceRequestModel request) async {
    final next = _nextStatus(request.status);
    if (next == null) {
      return;
    }

    final ok = await _api.updateRequestStatus(
      requestId: request.id,
      status: next,
      username: widget.username,
    );

    if (!mounted) {
      return;
    }

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update request status.'),
          backgroundColor: Color(0xFFE8922A),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Status updated to ${next.name}.'),
        backgroundColor: const Color(0xFFE8922A),
      ),
    );

    await _pushVolunteerLocationForAssigned();
    await _refresh();
  }

  Future<LatLng?> _getVolunteerPoint() async {
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

  Future<void> _openMiniMapPopup() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.62,
          child: _VolunteerMiniMapSheet(
            onLoadLocation: _getVolunteerPoint,
          ),
        );
      },
    );
  }

  void _openAssignedRequestMap(ServiceRequestModel request) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VolunteerRequestMapScreen(request: request),
      ),
    );
  }

  String _serviceSummary(ServiceRequestModel request) {
    if (request.services.isEmpty) {
      return 'General assistance';
    }

    return request.services.map((e) => e.name).join(', ');
  }

  Widget _buildRequestCard({
    required ServiceRequestModel request,
    required bool assigned,
  }) {
    final canUpdate = assigned && _nextStatus(request.status) != null;
    final canAccept = !assigned && !_hasActiveAssignment;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _serviceSummary(request),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFFE8922A),
            ),
          ),
          const SizedBox(height: 8),
          Text('Requested by: ${request.username}'),
          Text('Address: ${request.address}'),
          Text(
            'Schedule: ${request.scheduledAt.toLocal().toString().split('.').first}',
          ),
          Text('Status: ${request.statusLabel}'),
          if (request.notes.trim().isNotEmpty)
            Text('Notes: ${request.notes.trim()}'),
          const SizedBox(height: 12),
          Row(
            children: [
              if (!assigned)
                Expanded(
                  child: ElevatedButton(
                    onPressed: canAccept ? () => _acceptRequest(request) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE8922A),
                      disabledBackgroundColor: Colors.grey,
                    ),
                    child: Text(
                      canAccept ? 'Accept Request' : 'Finish Current Request',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              if (assigned)
                Expanded(
                  child: ElevatedButton(
                    onPressed: canUpdate ? () => _updateStatus(request) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE8922A),
                      disabledBackgroundColor: Colors.grey,
                    ),
                    child: Text(
                      _nextStatusLabel(request.status),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              if (assigned) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 48,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => _openAssignedRequestMap(request),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE8922A)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Icon(
                      Icons.map_outlined,
                      color: Color(0xFFE8922A),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFE8922A)),
      );
    }

    final assigned = _currentTab == 1;
    final data = assigned ? _assignedRequests : _openRequests;

    if (data.isEmpty) {
      return Center(
        child: Text(
          assigned
              ? 'No assigned requests yet.'
              : 'No open service requests right now.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          if (!assigned && _hasActiveAssignment)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE8922A)),
              ),
              child: const Text(
                'You already have an active assigned request. Complete it before accepting another one.',
                style: TextStyle(
                  color: Color(0xFFE8922A),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ...data.map(
            (request) => _buildRequestCard(request: request, assigned: assigned),
          ),
        ],
      ),
    );
  }

  void _onBottomTap(int index) {
    if (index == 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ProfileScreen(
            username: widget.username,
            services: widget.services,
            isVolunteer: true,
          ),
        ),
      );
      return;
    }

    setState(() {
      _currentTab = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = _currentTab == 0 ? 'Open Requests' : 'Assigned Requests';

    return Scaffold(
      backgroundColor: const Color(0xFFE8F0EE),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE8F0EE),
        elevation: 0,
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _openMiniMapPopup,
            icon: const Icon(Icons.map, color: Colors.black),
            tooltip: 'Mini Map',
          ),
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh, color: Colors.black),
          ),
        ],
      ),
      body: _buildTabBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTab,
        onTap: _onBottomTap,
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
      ),
    );
  }
}

class _VolunteerMiniMapSheet extends StatefulWidget {
  final Future<LatLng?> Function() onLoadLocation;

  const _VolunteerMiniMapSheet({
    required this.onLoadLocation,
  });

  @override
  State<_VolunteerMiniMapSheet> createState() => _VolunteerMiniMapSheetState();
}

class _VolunteerMiniMapSheetState extends State<_VolunteerMiniMapSheet> {
  LatLng? _location;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    setState(() {
      _isLoading = true;
    });

    final point = await widget.onLoadLocation();
    if (!mounted) {
      return;
    }

    setState(() {
      _location = point;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final center = _location ?? const LatLng(14.5995, 120.9842);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFE8F0EE),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Volunteer Mini Map',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFE8922A),
                          ),
                        )
                      : _location == null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Unable to load your location. Enable location services and permission, then retry.',
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: _loadLocation,
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
                            initialZoom: 15,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: geoapifyTileUrlTemplate,
                              userAgentPackageName: 'com.example.elderease',
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: _location!,
                                  width: 44,
                                  height: 44,
                                  child: const Icon(
                                    Icons.my_location,
                                    color: Color(0xFF1976D2),
                                    size: 30,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
