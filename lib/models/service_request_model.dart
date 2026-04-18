import 'service_model.dart';

enum RequestStatus {
  requested,
  matched,
  enRoute,
  arrived,
  completed,
  cancelled,
}

class RequestServiceItem {
  final String id;
  final String name;

  const RequestServiceItem({required this.id, required this.name});

  factory RequestServiceItem.fromService(ServiceModel service) {
    return RequestServiceItem(id: service.id, name: service.name);
  }

  factory RequestServiceItem.fromJson(Map<String, dynamic> json) {
    return RequestServiceItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name};
  }
}

class ServiceRequestModel {
  final String id;
  final String username;
  final List<RequestServiceItem> services;
  final DateTime scheduledAt;
  final String address;
  final String notes;
  final RequestStatus status;
  final DateTime createdAt;
  final bool synced;
  final String? helperName;
  final double? volunteerLat;
  final double? volunteerLng;
  final DateTime? volunteerLocationUpdatedAt;

  const ServiceRequestModel({
    required this.id,
    required this.username,
    required this.services,
    required this.scheduledAt,
    required this.address,
    required this.notes,
    required this.status,
    required this.createdAt,
    required this.synced,
    this.helperName,
    this.volunteerLat,
    this.volunteerLng,
    this.volunteerLocationUpdatedAt,
  });

  String get statusLabel {
    switch (status) {
      case RequestStatus.requested:
        return 'Requested';
      case RequestStatus.matched:
        return 'Helper Matched';
      case RequestStatus.enRoute:
        return 'Helper En Route';
      case RequestStatus.arrived:
        return 'Helper Arrived';
      case RequestStatus.completed:
        return 'Completed';
      case RequestStatus.cancelled:
        return 'Expired (No Volunteer Accepted)';
    }
  }

  ServiceRequestModel copyWith({
    String? id,
    String? username,
    List<RequestServiceItem>? services,
    DateTime? scheduledAt,
    String? address,
    String? notes,
    RequestStatus? status,
    DateTime? createdAt,
    bool? synced,
    String? helperName,
    double? volunteerLat,
    double? volunteerLng,
    DateTime? volunteerLocationUpdatedAt,
  }) {
    return ServiceRequestModel(
      id: id ?? this.id,
      username: username ?? this.username,
      services: services ?? this.services,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      synced: synced ?? this.synced,
      helperName: helperName ?? this.helperName,
      volunteerLat: volunteerLat ?? this.volunteerLat,
      volunteerLng: volunteerLng ?? this.volunteerLng,
      volunteerLocationUpdatedAt:
          volunteerLocationUpdatedAt ?? this.volunteerLocationUpdatedAt,
    );
  }

  factory ServiceRequestModel.fromJson(Map<String, dynamic> json) {
    final rawServices = (json['services'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();

    return ServiceRequestModel(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      services: rawServices.map(RequestServiceItem.fromJson).toList(),
      scheduledAt:
          DateTime.tryParse(json['scheduled_at']?.toString() ?? '') ??
          DateTime.now(),
      address: json['address']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      status: _parseStatus(json['status']?.toString()),
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      synced: json['synced'] as bool? ?? true,
      helperName: json['helper_name']?.toString(),
      volunteerLat: (json['volunteer_lat'] as num?)?.toDouble(),
      volunteerLng: (json['volunteer_lng'] as num?)?.toDouble(),
      volunteerLocationUpdatedAt: DateTime.tryParse(
        json['volunteer_location_updated_at']?.toString() ?? '',
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'services': services.map((s) => s.toJson()).toList(),
      'scheduled_at': scheduledAt.toIso8601String(),
      'address': address,
      'notes': notes,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'synced': synced,
      'helper_name': helperName,
      'volunteer_lat': volunteerLat,
      'volunteer_lng': volunteerLng,
      'volunteer_location_updated_at': volunteerLocationUpdatedAt
          ?.toIso8601String(),
    };
  }

  static RequestStatus _parseStatus(String? raw) {
    switch ((raw ?? '').toLowerCase()) {
      case 'matched':
        return RequestStatus.matched;
      case 'enroute':
      case 'en_route':
      case 'en route':
        return RequestStatus.enRoute;
      case 'arrived':
        return RequestStatus.arrived;
      case 'completed':
        return RequestStatus.completed;
      case 'cancelled':
      case 'canceled':
        return RequestStatus.cancelled;
      case 'requested':
      default:
        return RequestStatus.requested;
    }
  }
}
