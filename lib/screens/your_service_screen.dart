import 'package:flutter/material.dart';
import '../config/service_image_config.dart';
import '../models/service_model.dart';
import '../models/service_request_model.dart';
import '../services/request_repository.dart';
import '../widgets/bottom_nav.dart';
import 'home_screen.dart';
import 'notification_screen.dart';
import 'profile_screen.dart';
import 'request_checkout_screen.dart';
import 'volunteer_screen.dart';

class YourServiceScreen extends StatefulWidget {
  final String username;
  final List<ServiceModel> services;
  const YourServiceScreen({
    super.key,
    required this.username,
    required this.services,
  });
  @override
  State<YourServiceScreen> createState() => _YourServiceScreenState();
}

class _YourServiceScreenState extends State<YourServiceScreen> {
  final _repository = const RequestRepository();
  List<ServiceRequestModel> _requests = [];
  bool _isLoadingRequests = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoadingRequests = true);
    final requests = await _repository.getRequestsForUser(widget.username);

    if (!mounted) {
      return;
    }

    setState(() {
      _requests = requests;
      _isLoadingRequests = false;
    });
  }

  RequestStatus? _latestStatusForService(ServiceModel service) {
    for (final request in _requests) {
      final containsService = request.services.any((s) => s.id == service.id);
      if (containsService) {
        return request.status;
      }
    }
    return null;
  }

  Future<void> _trackService(ServiceModel service) async {
    final status = _latestStatusForService(service);

    if (status == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please confirm this service request first.'),
          backgroundColor: Color(0xFFE8922A),
        ),
      );
      return;
    }

    if (status == RequestStatus.completed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This service is already finished.'),
          backgroundColor: Color(0xFFE8922A),
        ),
      );
      return;
    }

    if (status == RequestStatus.cancelled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This request expired because no volunteer accepted. Please confirm the service again.',
          ),
          backgroundColor: Color(0xFFE8922A),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            VolunteerScreen(username: widget.username, services: [service]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = _searchQuery.trim().toLowerCase();
    final filteredServices = widget.services.where((service) {
      if (normalizedQuery.isEmpty) {
        return true;
      }

      return service.name.toLowerCase().contains(normalizedQuery) ||
          service.description.toLowerCase().contains(normalizedQuery) ||
          service.category.toLowerCase().contains(normalizedQuery);
    }).toList();

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
        child: Column(
          children: [
            // Search bar
            TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search...',
                filled: true,
                fillColor: const Color(0xFFFFF3E0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 16),
            // List of added services
            Expanded(
              child: widget.services.isEmpty
                  ? const Center(
                      child: Text(
                        'No services added yet.',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    )
                  : filteredServices.isEmpty
                  ? const Center(
                      child: Text(
                        'No matching services found.',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredServices.length,
                      itemBuilder: (context, index) {
                        final service = filteredServices[index];
                        final status = _latestStatusForService(service);
                        final isCompleted = status == RequestStatus.completed;
                        final isExpired = status == RequestStatus.cancelled;
                        final isInactive = isCompleted || isExpired;
                        final statusLabel = status?.name ?? 'not_requested';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            onTap: () => _trackService(service),
                            leading: buildMappedImage(
                              serviceImagePath(service.name),
                              height: 60,
                              width: 60,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            title: Text(
                              service.name,
                              style: const TextStyle(
                                color: Color(0xFFE8922A),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                isCompleted
                                    ? 'Status: Completed (tracking disabled)'
                                    : isExpired
                                    ? 'Status: Expired (no volunteer accepted)'
                                    : status == null
                                    ? 'Status: Not requested yet'
                                    : 'Status: $statusLabel (tap to track)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isInactive
                                      ? Colors.redAccent
                                      : Colors.grey,
                                ),
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.place,
                                  color: isInactive
                                      ? Colors.grey
                                      : const Color(0xFFE8922A),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () {
                                    setState(
                                      () => widget.services.remove(service),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (_isLoadingRequests)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(color: Color(0xFFE8922A)),
              ),
            // Confirm button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: widget.services.isEmpty
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RequestCheckoutScreen(
                              username: widget.username,
                              services: widget.services,
                            ),
                          ),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE8922A),
                  disabledBackgroundColor: Colors.grey,
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
          }
        },
      ),
    );
  }
}
