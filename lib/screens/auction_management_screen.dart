import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/supabase_provider.dart';
import '../providers/player_provider.dart';
import '../providers/auction_provider.dart';
import '../models/player_model.dart';
import '../models/team_model.dart';
import '../models/auction_model.dart';
import 'auction_screen.dart';


class AuctionManagementScreen extends ConsumerWidget {
  const AuctionManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playersAsync = ref.watch(playersProvider);
    final auctionsStream = ref.watch(auctionsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Auction Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.gavel),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (ctx) => const AuctionScreen())),
            tooltip: 'Go to Live Auction View',
          )
        ],
      ),
      body: playersAsync.when(
        data: (players) => FutureBuilder<List<TeamModel>>(
          future: ref.read(supabaseServiceProvider).getTeams(),
          builder: (context, teamSnapshot) {
            final teams = teamSnapshot.data ?? [];
            
            return auctionsStream.when(
              data: (auctions) {
                final liveAuction = auctions.firstWhere((a) => a.status == 'live', orElse: () => AuctionModel(id: '', playerId: '', status: 'none'));
                
                // Filter players who are NOT in any auction yet (upcoming)
                final auctionedPlayerIds = auctions.map((a) => a.playerId).toSet();
                final upcomingPlayers = players.where((p) => !auctionedPlayerIds.contains(p.id)).toList();
                final soldPlayers = players.where((p) => auctions.any((a) => a.playerId == p.id && a.status == 'sold')).toList();
                final unsoldPlayers = players.where((p) => auctions.any((a) => a.playerId == p.id && a.status == 'unsold')).toList();

                return DefaultTabController(
                  length: 3,
                  child: Column(
                    children: [
                      TabBar(
                        labelColor: Colors.orange,
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: Colors.orange,
                        tabs: [
                          Tab(icon: Icon(Icons.hourglass_empty, color: upcomingPlayers.isNotEmpty ? Colors.orange : Colors.grey), text: 'Upcoming (${upcomingPlayers.length})'),
                          Tab(icon: Icon(Icons.check_circle, color: soldPlayers.isNotEmpty ? Colors.green : Colors.grey), text: 'Sold (${soldPlayers.length})'),
                          Tab(icon: Icon(Icons.cancel, color: unsoldPlayers.isNotEmpty ? Colors.red : Colors.grey), text: 'Unsold (${unsoldPlayers.length})'),
                        ],
                      ),
                      if (liveAuction.status == 'live')
                        Container(
                          margin: const EdgeInsets.all(12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [Colors.orange.withValues(alpha: 0.2), Colors.orange.withValues(alpha: 0.05)]),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 12, height: 12,
                                    decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('LIVE AUCTION', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, letterSpacing: 1)),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Icons.open_in_new, color: Colors.orange),
                                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (ctx) => const AuctionScreen())),
                                    tooltip: 'Open Live Auction View',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Builder(
                                builder: (ctx) {
                                  final service = ref.read(supabaseServiceProvider);
                                  return FutureBuilder<Map<String, dynamic>?>(
                                    future: service.client.from('players').select().eq('id', liveAuction.playerId).maybeSingle(),
                                    builder: (ctx, snap) {
                                      final playerName = snap.data?['name'] ?? 'Loading...';
                                      return Column(
                                        children: [
                                          Text(playerName.toString().toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                                          Text('₹${liveAuction.currentBid}', style: const TextStyle(color: Colors.greenAccent, fontSize: 32, fontWeight: FontWeight.w900)),
                                        ],
                                      );
                                    },
                                  );
                                },
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.check_circle, size: 20),
                                      label: const Text('SOLD'),
                                      onPressed: () async {
                                        await ref.read(supabaseServiceProvider).sellPlayer(
                                          liveAuction.id,
                                          liveAuction.playerId,
                                          liveAuction.currentBidTeamId,
                                          liveAuction.currentBid,
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green[700],
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.cancel, size: 20),
                                      label: const Text('UNSOLD'),
                                      onPressed: () async {
                                        await ref.read(supabaseServiceProvider).sellPlayer(
                                          liveAuction.id,
                                          liveAuction.playerId,
                                          null,
                                          0,
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red[700],
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _buildPlayerList(context, ref, upcomingPlayers, 'upcoming', liveAuction.status == 'live', auctions, teams),
                            _buildPlayerList(context, ref, soldPlayers, 'sold', false, auctions, teams),
                            _buildPlayerList(context, ref, unsoldPlayers, 'unsold', false, auctions, teams),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
            );
          }
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildPlayerList(BuildContext context, WidgetRef ref, List<PlayerModel> players, String type, bool isLiveSession, List<AuctionModel> auctions, List<TeamModel> teams) {
    if (players.isEmpty) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('No $type players.', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
        ],
      ));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: players.length,
      itemBuilder: (ctx, i) {
        final player = players[i];
        final auction = auctions.firstWhere((a) => a.playerId == player.id, orElse: () => AuctionModel(id: '', playerId: '', status: 'none'));
        String subtitle = '${player.role.toUpperCase()} | Base: ₹${player.basePrice}';
        String? teamName;
        if (type == 'sold') {
          final winningTeam = teams.firstWhere((t) => t.id == auction.teamId, orElse: () => TeamModel(id: '', name: 'Unknown', purse: 0));
          teamName = winningTeam.name;
          subtitle = 'SOLD: ₹${auction.soldPrice ?? 0} to ${winningTeam.name}';
        } else if (type == 'unsold') {
          subtitle = 'UNSOLD';
        }

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: type == 'sold' ? Colors.green.withValues(alpha: 0.1) : (type == 'unsold' ? Colors.red.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.1)),
              child: Icon(
                type == 'sold' ? Icons.check_circle : (type == 'unsold' ? Icons.cancel : Icons.person),
                color: type == 'sold' ? Colors.green : (type == 'unsold' ? Colors.red : Colors.blue),
              ),
            ),
            title: Text(player.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(subtitle),
                if (teamName != null) 
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(teamName, style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.w500)),
                  ),
              ],
            ),
            isThreeLine: teamName != null,
            trailing: type == 'upcoming' 
              ? ElevatedButton(
                  onPressed: isLiveSession ? null : () async {
                    await ref.read(supabaseServiceProvider).client.from('auctions').insert({
                      'player_id': player.id,
                      'status': 'live',
                      'current_bid': player.basePrice,
                      'ends_at': DateTime.now().add(const Duration(seconds: 10)).toIso8601String(),
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isLiveSession ? Colors.grey : Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: Text(isLiveSession ? 'BUSY' : 'START'),
                )
              : null,
          ),
        );
      },
    );
  }
}


