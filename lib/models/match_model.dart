class MatchModel {
  final String id;
  final String team1Id;
  final String team2Id;
  final String status; // 'upcoming', 'live', 'completed'
  final String? tossWinnerId;
  final String? tossDecision; // 'bat', 'bowl'

  final int? innings; // 1 or 2
  final int? target; // only for 2nd innings
  final String? venue;
  final DateTime? scheduledAt;
  final int totalOvers;

  MatchModel({
    required this.id,
    required this.team1Id,
    required this.team2Id,
    required this.status,
    this.tossWinnerId,
    this.tossDecision,
    this.venue,
    this.scheduledAt,
    this.innings,
    this.target,
    this.totalOvers = 20,
  });

  factory MatchModel.fromJson(Map<String, dynamic> json) {
    return MatchModel(
      id: json['id'],
      team1Id: json['team1_id'],
      team2Id: json['team2_id'],
      status: json['status'] ?? 'upcoming',
      tossWinnerId: json['toss_winner_id'],
      tossDecision: json['toss_decision'],
      venue: json['venue'],
      scheduledAt: json['scheduled_at'] != null ? DateTime.parse(json['scheduled_at']) : null,
      innings: json['innings'],
      target: json['target'],
      totalOvers: json['total_overs'] ?? 20,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'team1_id': team1Id,
      'team2_id': team2Id,
      'status': status,
      'total_overs': totalOvers,
      if (tossWinnerId != null) 'toss_winner_id': tossWinnerId,
      if (tossDecision != null) 'toss_decision': tossDecision,
      if (venue != null) 'venue': venue,
      if (scheduledAt != null) 'scheduled_at': scheduledAt!.toIso8601String(),
      if (innings != null) 'innings': innings,
      if (target != null) 'target': target,
    };
  }
}
