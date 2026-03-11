class UserProfileModel {
  final String username;
  final String fullName;
  final String email;
  final String phoneNumber;
  final String birthday;
  final String address;
  final DateTime? createdAt;

  const UserProfileModel({
    required this.username,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.birthday,
    required this.address,
    this.createdAt,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      username: json['username']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phoneNumber: json['phone_number']?.toString() ?? '',
      birthday: json['birthday']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'username': username,
      'full_name': fullName,
      'email': email,
      'phone_number': phoneNumber,
      'birthday': birthday,
      'address': address,
    };
  }
}
