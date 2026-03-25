class AuctionModel {
  final String id;
  final String playerId;
  final String? teamId;
  final int? soldPrice;
  final String status; // 'upcoming', 'live', 'sold', 'unsold'
  final int currentBid;
  final String? currentBidTeamId;
  final String? endsAt;

  AuctionModel({
    required this.id,
    required this.playerId,
    this.teamId,
    this.soldPrice,
    required this.status,
    this.currentBid = 0,
    this.currentBidTeamId,
    this.endsAt,
  });

  factory AuctionModel.fromJson(Map<String, dynamic> json) {
    return AuctionModel(
      id: json['id'],
      playerId: json['player_id'],
      teamId: json['team_id'],
      soldPrice: json['sold_price'],
      status: json['status'] ?? 'upcoming',
      currentBid: json['current_bid'] ?? 0,
      currentBidTeamId: json['current_bid_team_id'],
      endsAt: json['ends_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'player_id': playerId,
      if (teamId != null) 'team_id': teamId,
      if (soldPrice != null) 'sold_price': soldPrice,
      'status': status,
      'current_bid': currentBid,
      if (currentBidTeamId != null) 'current_bid_team_id': currentBidTeamId,
      if (endsAt != null) 'ends_at': endsAt,
    };
  }
}
