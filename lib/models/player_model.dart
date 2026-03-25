class PlayerModel {
  final String id;
  final String name;
  final String role; // 'batsman', 'bowler', 'all-rounder', 'wicketkeeper'
  final int basePrice;
  final String? teamId;

  PlayerModel({
    required this.id,
    required this.name,
    required this.role,
    required this.basePrice,
    this.teamId,
  });

  factory PlayerModel.fromJson(Map<String, dynamic> json) {
    return PlayerModel(
      id: json['id'],
      name: json['name'],
      role: json['role'],
      basePrice: json['base_price'] ?? 0,
      teamId: json['team_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'role': role,
      'base_price': basePrice,
      if (teamId != null) 'team_id': teamId,
    };
  }
}
