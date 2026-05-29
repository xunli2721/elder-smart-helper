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
      id: json['id'],
      phone: json['phone'],
      name: json['name'],
      userType: json['user_type'],
      fontSize: json['font_size'] ?? 'large',
    );
  }
}
