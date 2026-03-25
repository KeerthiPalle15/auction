import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../models/team_model.dart';
import '../models/player_model.dart';
import '../models/auction_model.dart';
import '../models/match_model.dart';
import '../models/match_event_model.dart';

class SupabaseService {
  final SupabaseClient client = Supabase.instance.client;

  // --- Auth ---
  Future<AuthResponse> signInEmail(String email, String password) async {
    return await client.auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> signUpEmail(String email, String password, String role) async {
    return await client.auth.signUp(
      email: email,
      password: password,
      data: {'role': role},
    );
  }

  Future<void> signOut() async {
    await client.auth.signOut();
  }

  User? get currentUser => client.auth.currentUser;

  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  // --- Users ---
  Future<UserModel> getUserProfile(String userId) async {
    final data = await client.from('users').select().eq('id', userId).single();
    return UserModel.fromJson(data);
  }

  // --- Teams ---
  Future<List<TeamModel>> getTeams() async {
    final response = await client.from('teams').select();
    return (response as List).map((e) => TeamModel.fromJson(e)).toList();
  }

  // --- Players ---
  Future<List<PlayerModel>> getPlayers() async {
    final response = await client.from('players').select();
    return (response as List).map((e) => PlayerModel.fromJson(e)).toList();
  }

  Future<void> updatePlayer(String playerId, Map<String, dynamic> data) async {
    await client.from('players').update(data).eq('id', playerId);
  }

  Future<void> deletePlayer(String playerId) async {
    await client.from('players').delete().eq('id', playerId);
  }

  // --- Auctions ---
  Stream<List<AuctionModel>> streamAuctions() {
    return client.from('auctions').stream(primaryKey: ['id']).map((list) {
      return list.map((e) => AuctionModel.fromJson(e)).toList();
    });
  }

  Future<void> placeBid(String auctionId, String teamId, int amount) async {
    await client.from('auctions').update({
      'current_bid_team_id': teamId,
      'current_bid': amount,
    }).eq('id', auctionId);
  }

  Future<void> updateTeamPurse(String teamId, int newPurse) async {
    await client.from('teams').update({'purse': newPurse}).eq('id', teamId);
  }

  Future<void> sellPlayer(String auctionId, String playerId, String? teamId, int finalPrice) async {
    try {
      if (teamId != null) {
        final teamRes = await client.from('teams').select('purse').eq('id', teamId).single();
        final currentPurse = teamRes['purse'] as int;
        
        if (finalPrice > currentPurse) {
          throw Exception('Insufficient team purse. Required: ₹$finalPrice, Available: ₹$currentPurse');
        }

        final newPurse = currentPurse - finalPrice;
        await client.from('teams').update({'purse': newPurse}).eq('id', teamId);
      }

      await client.from('auctions').update({
        'status': teamId != null ? 'sold' : 'unsold',
        'team_id': teamId,
        'sold_price': finalPrice,
      }).eq('id', auctionId);
    } catch (e) {
      rethrow;
    }
  }

  // --- Matches ---
  Future<void> createMatch(String team1Id, String team2Id, {String? venue, DateTime? scheduledAt, int totalOvers = 20}) async {
    await client.from('matches').insert({
      'team1_id': team1Id,
      'team2_id': team2Id,
      'status': 'upcoming',
      'venue': venue,
      'scheduled_at': scheduledAt?.toIso8601String(),
      'total_overs': totalOvers,
    });
  }

  Future<void> updateMatch(String matchId, Map<String, dynamic> data) async {
    await client.from('matches').update(data).eq('id', matchId);
  }

  Future<void> updateMatchStatus(String matchId, String status) async {
    await client.from('matches').update({'status': status}).eq('id', matchId);
  }

  Future<void> deleteMatch(String matchId) async {
    await client.from('matches').delete().eq('id', matchId);
  }

  Future<List<PlayerModel>> getTeamPlayers(String teamId) async {
    // Get auction records where this team won
    final response = await client.from('auctions').select('player_id').eq('team_id', teamId).eq('status', 'sold');
    final playerIds = (response as List).map((e) => e['player_id'] as String).toList();
    
    if (playerIds.isEmpty) return [];

    final playersResponse = await client.from('players').select().filter('id', 'in', playerIds);
    return (playersResponse as List).map((e) {
      final p = PlayerModel.fromJson(e);
      return PlayerModel(
        id: p.id,
        name: p.name,
        role: p.role,
        basePrice: p.basePrice,
        teamId: teamId,
      );
    }).toList();
  }

  Future<List<MatchModel>> getMatches() async {
    final response = await client.from('matches').select();
    return (response as List).map((e) => MatchModel.fromJson(e)).toList();
  }

  Stream<List<MatchModel>> streamLiveMatches() {
    return client.from('matches').stream(primaryKey: ['id']).map((list) {
      return list.map((e) => MatchModel.fromJson(e)).toList();
    });
  }

  Stream<List<MatchEventModel>> streamMatchEvents(String matchId) {
    return client.from('match_events').stream(primaryKey: ['id']).eq('match_id', matchId).order('created_at').map((list) {
      final events = list.map((e) => MatchEventModel.fromJson(e)).toList();
      events.sort((a, b) {
        if (a.overNumber != b.overNumber) {
          return a.overNumber.compareTo(b.overNumber);
        }
        return a.ballNumber.compareTo(b.ballNumber);
      });
      return events;
    });
  }

  Future<void> addMatchEvent(MatchEventModel event) async {
    await client.from('match_events').insert(event.toJson()..remove('id')); // Let supabase auto-gen ID
  }

  Future<void> undoLastEvent(String matchId) async {
    final response = await client.from('match_events')
      .select()
      .eq('match_id', matchId)
      .order('created_at', ascending: false)
      .limit(1);
      
    if ((response as List).isNotEmpty) {
      final String id = response[0]['id'];
      await client.from('match_events').delete().eq('id', id);
    }
  }
}
