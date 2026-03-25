class UserModel {
  final String id;
  final String email;
  final String role; // 'admin', 'captain', 'viewer'
  final String? teamId;

  UserModel({
    required this.id,
    required this.email,
    required this.role,
    this.teamId,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      email: json['email'],
      role: json['role'] ?? 'viewer',
      teamId: json['team_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'role': role,
      'team_id': teamId,
    };
  }

  bool get isAdmin => role == 'admin';
  bool get isCaptain => role == 'captain';
  bool get isViewer => role == 'viewer';
}
