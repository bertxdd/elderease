import 'package:flutter/material.dart';

import '../models/service_model.dart';
import '../models/service_request_model.dart';
import '../services/profile_api_service.dart';
import '../services/request_repository.dart';
import 'notification_screen.dart';
import 'profile_screen.dart';

class RequestCheckoutScreen extends StatefulWidget {
  final String username;
  final List<ServiceModel> services;

  const RequestCheckoutScreen({
    super.key,
    required this.username,
    required this.services,
  });

  @override
  State<RequestCheckoutScreen> createState() => _RequestCheckoutScreenState();
}

class _RequestCheckoutScreenState extends State<RequestCheckoutScreen> {
  final _notesController = TextEditingController();
  final _repository = const RequestRepository();
  final _profileService = const ProfileApiService();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isSubmitting = false;
  bool _isLoadingProfile = true;
  String _profileAddress = '';

  @override
  void initState() {
    super.initState();
    _loadProfileAddress();
  }

  Future<void> _loadProfileAddress() async {
    try {
      final profile = await _profileService.fetchProfile(widget.username);
      if (!mounted) {
        return;
      }
      setState(() {
        _profileAddress = profile.address.trim();
        _isLoadingProfile = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _profileAddress = '';
        _isLoadingProfile = false;
      });
      _showMessage('Unable to load profile address. Please try again.');
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDate: _selectedDate ?? now,
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _submitRequest() async {
    if (_selectedDate == null || _selectedTime == null) {
      _showMessage('Please choose schedule date and time.');
      return;
    }

    if (_profileAddress.isEmpty) {
      _showMessage('Please set your address in Profile first.');
      return;
    }

    setState(() => _isSubmitting = true);

    final scheduled = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    final request = ServiceRequestModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      username: widget.username,
      services: widget.services.map(RequestServiceItem.fromService).toList(),
      scheduledAt: scheduled,
        address: _profileAddress,
      notes: _notesController.text.trim(),
      status: RequestStatus.requested,
      createdAt: DateTime.now(),
      synced: false,
    );

    final created = await _repository.createRequest(request);

    if (!mounted) {
      return;
    }

    setState(() => _isSubmitting = false);

    if (created.synced) {
      _showMessage('Request submitted successfully.');
    } else {
      _showMessage('Saved locally. Will sync when backend is reachable.');
    }

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

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFE8922A),
      ),
    );
  }

  Future<void> _goToProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          username: widget.username,
          services: widget.services,
        ),
      ),
    );

    if (!mounted) {
      return;
    }
    await _loadProfileAddress();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F0EE),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE8F0EE),
        elevation: 0,
        title: const Text(
          'Request Details',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Selected Services',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            ...widget.services.map(
              (service) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(service.name)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Schedule',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _pickDate,
                    child: Text(
                      _selectedDate == null
                          ? 'Choose Date'
                          : '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _pickTime,
                    child: Text(
                      _selectedTime == null
                          ? 'Choose Time'
                          : _selectedTime!.format(context),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Address',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            if (_isLoadingProfile)
              const LinearProgressIndicator(color: Color(0xFFE8922A))
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _profileAddress.isEmpty
                      ? 'No profile address found.'
                      : _profileAddress,
                  style: TextStyle(
                    color: _profileAddress.isEmpty ? Colors.redAccent : Colors.black87,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            if (!_isLoadingProfile && _profileAddress.isEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _goToProfile,
                  icon: const Icon(Icons.person_outline),
                  label: const Text('Set Address in Profile'),
                ),
              )
            else
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _goToProfile,
                  icon: const Icon(Icons.edit_location_alt_outlined),
                  label: const Text('Update Address in Profile'),
                ),
              ),
            const SizedBox(height: 20),
            const SizedBox(height: 20),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting || _isLoadingProfile || _profileAddress.isEmpty
                    ? null
                    : _submitRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE8922A),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Submit Request',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
