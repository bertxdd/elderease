import 'package:flutter/material.dart';
import '../models/service_request_model.dart';
import '../models/service_model.dart';
import '../services/request_repository.dart';
import '../widgets/bottom_nav.dart';
import 'home_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _requestsFuture = _repository.getRequestsForUser(widget.username);
  }

  Future<void> _reload() async {
    final refreshed = _repository.getRequestsForUser(widget.username);
    setState(() => _requestsFuture = refreshed);
    await refreshed;
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

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              final subtitle =
                  '${request.statusLabel} • ${request.scheduledAt.toLocal().toString().split('.').first}';
              return _NotificationTile(
                title: request.services.isEmpty
                    ? 'Service Request'
                    : request.services.first.name,
                subtitle: subtitle,
                synced: request.synced,
                status: request.status,
              );
            },
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
  final String title;
  final String subtitle;
  final bool synced;
  final RequestStatus status;

  const _NotificationTile({
    required this.title,
    required this.subtitle,
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
        leading: Icon(Icons.notifications_none, color: _statusColor()),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(synced ? subtitle : '$subtitle • Waiting for sync'),
      ),
    );
  }
}
