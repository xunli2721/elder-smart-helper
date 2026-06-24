class User {
  final int id;
  final String phone;
  final String name;
  final String userType;
  final String fontSize;

  User({
    required this.id,
    required this.phone,
    required this.name,
    required this.userType,
    this.fontSize = 'large',
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      phone: json['phone']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      userType: json['user_type']?.toString() ?? 'elderly',
      fontSize: json['font_size']?.toString() ?? 'large',
    );
  }
}
