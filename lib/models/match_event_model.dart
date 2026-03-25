class MatchEventModel {
  final String id;
  final String matchId;
  final int innings;
  final int overNumber;
  final int ballNumber;
  final int runs;
  final int extraRuns;
  final String? extraType; // 'wide', 'no-ball', 'bye', 'leg-bye'
  final String? wicketType; // 'bowled', 'caught', 'run-out', 'lbw', 'stumped', 'hit-wicket'
  final String? batsmanId;
  final String? bowlerId;
  final bool isUndo;

  MatchEventModel({
    required this.id,
    required this.matchId,
    required this.innings,
    required this.overNumber,
    required this.ballNumber,
    this.runs = 0,
    this.extraRuns = 0,
    this.extraType,
    this.wicketType,
    this.batsmanId,
    this.bowlerId,
    this.isUndo = false,
  });

  factory MatchEventModel.fromJson(Map<String, dynamic> json) {
    return MatchEventModel(
      id: json['id'],
      matchId: json['match_id'],
      innings: json['innings'],
      overNumber: json['over_number'],
      ballNumber: json['ball_number'],
      runs: json['runs'] ?? 0,
      extraRuns: json['extra_runs'] ?? 0,
      extraType: json['extra_type'],
      wicketType: json['wicket_type'],
      batsmanId: json['batsman_id'],
      bowlerId: json['bowler_id'],
      isUndo: json['is_undo'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'match_id': matchId,
      'innings': innings,
      'over_number': overNumber,
      'ball_number': ballNumber,
      'runs': runs,
      'extra_runs': extraRuns,
      if (extraType != null) 'extra_type': extraType,
      if (wicketType != null) 'wicket_type': wicketType,
      if (batsmanId != null) 'batsman_id': batsmanId,
      if (bowlerId != null) 'bowler_id': bowlerId,
      'is_undo': isUndo,
    };
  }
}
