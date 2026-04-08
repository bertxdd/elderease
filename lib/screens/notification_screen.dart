import 'package:flutter/material.dart';
import 'dart:async';
import '../models/service_request_model.dart';
import '../models/service_model.dart';
import '../services/request_repository.dart';
import '../widgets/bottom_nav.dart';
import 'home_screen.dart';
import 'notification_request_map_screen.dart';
import 'profile_screen.dart';
import 'your_service_screen.dart';

class NotificationScreen extends StatefulWidget {
  final String username;
  final List<ServiceModel> services;

  const NotificationScreen({
    super.key,
    required this.username,
    required this.services,
  });

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final RequestRepository _repository = const RequestRepository();
  late Future<List<ServiceRequestModel>> _requestsFuture;
  Timer? _pollTimer;
  final Map<RequestStatus, String?> _selectedDateByStatus = {};

  @override
  void initState() {
    super.initState();
    _requestsFuture = _repository.getRequestsForUser(widget.username);
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) {
        return;
      }
      final refreshed = _repository.getRequestsForUser(widget.username);
      setState(() {
        _requestsFuture = refreshed;
      });
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _reload() async {
    final refreshed = _repository.getRequestsForUser(widget.username);
    setState(() {
      _requestsFuture = refreshed;
    });
    await refreshed;
  }

  String _dateKey(DateTime dateTime) {
    final local = dateTime.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _dateLabel(String key) {
    final parsed = DateTime.tryParse(key);
    if (parsed == null) {
      return key;
    }
    final local = parsed.toLocal();
    final month = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ][local.month - 1];
    return '$month ${local.day}, ${local.year}';
  }

  Widget _buildCategorySection(
    BuildContext context,
    RequestStatus status,
    List<ServiceRequestModel> requests,
  ) {
    final dateKeys = requests
        .map((r) => _dateKey(r.scheduledAt))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    final selected = _selectedDateByStatus[status];
    final effectiveSelected = dateKeys.contains(selected) ? selected : null;

    final filtered = effectiveSelected == null
        ? requests
        : requests
              .where((r) => _dateKey(r.scheduledAt) == effectiveSelected)
              .toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  status.name.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFE8922A),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.black12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: effectiveSelected,
                    hint: const Text('All dates'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All dates'),
                      ),
                      ...dateKeys.map(
                        (k) => DropdownMenuItem<String?>(
                          value: k,
                          child: Text(_dateLabel(k)),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedDateByStatus[status] = value;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No requests for selected date.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ...filtered.map(
              (request) {
                final subtitle =
                    '${request.statusLabel} • ${request.scheduledAt.toLocal().toString().split('.').first}';
                return _NotificationTile(
                  request: request,
                  title: request.services.isEmpty
                      ? 'Service Request'
                      : request.services.first.name,
                  subtitle: subtitle,
                  address: request.address,
                  helperName: request.helperName,
                  volunteerLat: request.volunteerLat,
                  volunteerLng: request.volunteerLng,
                  volunteerLocationUpdatedAt: request.volunteerLocationUpdatedAt,
                  synced: request.synced,
                  status: request.status,
                );
              },
            ),
        ],
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
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh, color: Colors.black),
          ),
        ],
      ),
      body: FutureBuilder<List<ServiceRequestModel>>(
        future: _requestsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final requests = snapshot.data ?? const [];
          if (requests.isEmpty) {
            return const Center(
              child: Text(
                'No notifications yet.\nSubmit a request to see updates.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            );
          }

          final grouped = <RequestStatus, List<ServiceRequestModel>>{};
          for (final request in requests) {
            grouped.putIfAbsent(request.status, () => []).add(request);
          }

          final orderedStatuses = RequestStatus.values
              .where((s) => grouped.containsKey(s))
              .toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: orderedStatuses
                .map(
                  (status) => _buildCategorySection(
                    context,
                    status,
                    grouped[status]!,
                  ),
                )
                .toList(),
          );
        },
      ),
      bottomNavigationBar: BottomNav(
        currentIndex: 2,
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

class _NotificationTile extends StatelessWidget {
  final ServiceRequestModel request;
  final String title;
  final String subtitle;
  final String address;
  final String? helperName;
  final double? volunteerLat;
  final double? volunteerLng;
  final DateTime? volunteerLocationUpdatedAt;
  final bool synced;
  final RequestStatus status;

  const _NotificationTile({
    required this.request,
    required this.title,
    required this.subtitle,
    required this.address,
    required this.helperName,
    required this.volunteerLat,
    required this.volunteerLng,
    required this.volunteerLocationUpdatedAt,
    required this.synced,
    required this.status,
  });

  Color _statusColor() {
    switch (status) {
      case RequestStatus.requested:
        return const Color(0xFFE8922A);
      case RequestStatus.matched:
        return Colors.blue;
      case RequestStatus.enRoute:
        return Colors.deepPurple;
      case RequestStatus.arrived:
        return Colors.teal;
      case RequestStatus.completed:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NotificationRequestMapScreen(request: request),
            ),
          );
        },
        leading: Icon(Icons.notifications_none, color: _statusColor()),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          synced
              ? [
                  subtitle,
                  if (helperName != null && helperName!.trim().isNotEmpty)
                    'Volunteer: ${helperName!.trim()}',
                  if (address.trim().isNotEmpty) 'Location: ${address.trim()}',
                  if (volunteerLat != null && volunteerLng != null)
                    'Volunteer Position: ${volunteerLat!.toStringAsFixed(5)}, ${volunteerLng!.toStringAsFixed(5)}',
                  if (volunteerLocationUpdatedAt != null)
                    'Live Updated: ${volunteerLocationUpdatedAt!.toLocal().toString().split('.').first}',
                ].join('\n')
              : '$subtitle • Waiting for sync',
        ),
        trailing: const Icon(Icons.map_outlined, color: Color(0xFFE8922A)),
      ),
    );
  }
}
