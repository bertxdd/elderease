import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

import '../models/service_model.dart';
import '../models/service_request_model.dart';
import '../services/request_api_service.dart';
import 'profile_screen.dart';

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
                    onPressed: () => _acceptRequest(request),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE8922A),
                    ),
                    child: const Text(
                      'Accept Request',
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
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        itemCount: data.length,
        itemBuilder: (context, index) {
          return _buildRequestCard(request: data[index], assigned: assigned);
        },
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
