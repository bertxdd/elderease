class ServiceHistoryItem {
  final String id;
  final String username;
  final List<HistoryService> services;
  final DateTime scheduledAt;
  final String address;
  final String notes;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? rating;
  final String? feedback;
  final String? volunteerName;
  final double? volunteerRating;
  final String? userName;

  const ServiceHistoryItem({
    required this.id,
    required this.username,
    required this.services,
    required this.scheduledAt,
    required this.address,
    required this.notes,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.rating,
    this.feedback,
    this.volunteerName,
    this.volunteerRating,
    this.userName,
  });

  factory ServiceHistoryItem.fromJson(Map<String, dynamic> json) {
    final servicesList = (json['services'] as List<dynamic>?)
            ?.map((s) => HistoryService.fromJson(s as Map<String, dynamic>))
            .toList() ??
        [];

    return ServiceHistoryItem(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      services: servicesList,
      scheduledAt: DateTime.tryParse(json['scheduled_at']?.toString() ?? '') ??
          DateTime.now(),
      address: json['address']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.now(),
      rating: json['rating'] is int ? json['rating'] : null,
      feedback: json['feedback']?.toString(),
      volunteerName: json['volunteer_name']?.toString(),
      volunteerRating: json['volunteer_rating'] is num
          ? (json['volunteer_rating'] as num).toDouble()
          : null,
      userName: json['user_name']?.toString(),
    );
  }
}

class HistoryService {
  final String id;
  final String name;
  final int quantity;

  const HistoryService({
    required this.id,
    required this.name,
    required this.quantity,
  });

  factory HistoryService.fromJson(Map<String, dynamic> json) {
    return HistoryService(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      quantity: json['quantity'] is int ? json['quantity'] : 1,
    );
  }
}
