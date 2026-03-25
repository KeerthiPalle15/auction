class TeamModel {
  final String id;
  final String name;
  final int purse;

  TeamModel({
    required this.id,
    required this.name,
    this.purse = 0,
  });

  factory TeamModel.fromJson(Map<String, dynamic> json) {
    return TeamModel(
      id: json['id'],
      name: json['name'],
      purse: json['purse'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'purse': purse,
    };
  }
}
