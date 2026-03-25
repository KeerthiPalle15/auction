import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/supabase_provider.dart';
import '../providers/player_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/auction_provider.dart';
import '../models/player_model.dart';
import '../models/team_model.dart';
import '../models/auction_model.dart';
import 'dart:async';

class AuctionScreen extends ConsumerWidget {
  const AuctionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auctionsAsync = ref.watch(auctionsStreamProvider);
    final playersAsync = ref.watch(playersProvider);
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: auctionsAsync.when(
        data: (auctions) {
          final liveAuctions = auctions.where((a) => a.status == 'live').toList();
          if (liveAuctions.isEmpty) {
            return const Center(child: Text('No active auction.', style: TextStyle(color: Colors.white70)));
          }
          final liveAuction = liveAuctions.first;

          return playersAsync.when(
            data: (players) {
              final playerIdx = players.indexWhere((p) => p.id == liveAuction.playerId);
              if (playerIdx == -1) {
                return const Center(child: Text('Player not found', style: TextStyle(color: Colors.white70)));
              }
              final player = players[playerIdx];
              return userAsync.when(
                data: (user) {
                  final isAdmin = user?.isAdmin ?? false;
                  final isCaptain = user?.role == 'captain';
                  final teamId = user?.teamId;

                  return FutureBuilder<List<TeamModel>>(
                    future: ref.read(supabaseServiceProvider).getTeams(),
                    builder: (context, teamSnapshot) {
                      final teams = teamSnapshot.data ?? [];
                      final myTeam = teams.firstWhere((t) => t.id == teamId, orElse: () => TeamModel(id: '', name: '', purse: 0));
                      
                      return _buildAuctionView(context, ref, liveAuction, player, isCaptain, teamId, isAdmin, teams, myTeam.purse);
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error: $err')),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error: $err')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildAuctionView(
    BuildContext context, 
    WidgetRef ref, 
    AuctionModel liveAuction, 
    PlayerModel player, 
    bool isCaptain, 
    String? teamId, 
    bool isAdmin, 
    List<TeamModel> teams,
    int myPurse,
  ) {
    return Column(
      children: [
        _buildHeader(context),
        Expanded(
          child: _buildAuctionContent(context, ref, liveAuction, player, isCaptain, teamId, isAdmin, teams, myPurse),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 60, left: 24, right: 24, bottom: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.orangeAccent.withOpacity(0.2), Colors.transparent],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const Text(
            'LIVE AUCTION',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 2,
            ),
          ),
          const Icon(Icons.gavel, color: Colors.orangeAccent),
        ],
      ),
    );
  }

  Widget _buildAuctionContent(
    BuildContext context, 
    WidgetRef ref, 
    AuctionModel liveAuction, 
    PlayerModel player, 
    bool isCaptain, 
    String? teamId,
    bool isAdmin,
    List<TeamModel> teams,
    int myPurse,
  ) {
    final biddingTeam = teams.firstWhere((t) => t.id == liveAuction.currentBidTeamId, orElse: () => TeamModel(id: '', name: 'No Bids Yet', purse: 0));

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Player Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.orangeAccent.withOpacity(0.2),
                  child: const Icon(Icons.person, size: 80, color: Colors.orangeAccent),
                ).animate().scale(delay: 200.ms),
                const SizedBox(height: 16),
                Text(
                  player.name.toUpperCase(),
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  player.role.toUpperCase(),
                  style: const TextStyle(fontSize: 16, color: Colors.orangeAccent, letterSpacing: 1.2),
                ),
                const SizedBox(height: 8),
                Text('Base Price: \u20b9${player.basePrice}', style: const TextStyle(color: Colors.white54)),
              ],
            ),
          ),
          
          const SizedBox(height: 40),
          
          // Current Bid Section
          Column(
            children: [
              const Text('CURRENT BID', style: TextStyle(color: Colors.white54, letterSpacing: 1.5)),
              const SizedBox(height: 8),
              Text(
                '\u20b9${liveAuction.currentBid}',
                style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w900, color: Colors.greenAccent),
              ).animate(key: ValueKey(liveAuction.currentBid)).shimmer().scale(begin: const Offset(0.9, 0.9)),
              if (liveAuction.currentBidTeamId != null)
                Text(
                  'Bidden by ${biddingTeam.name}',
                  style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.w500),
                ),
              const SizedBox(height: 24),
              // Timer removed per user request
            ],
          ),

          const SizedBox(height: 48),

          // Captain Controls
          if (isCaptain && teamId != null)
             _buildBidPanel(ref, liveAuction, teamId, myPurse),

          // Admin Controls
          if (isAdmin)
             _buildAdminPanel(context, ref, liveAuction, player),

          if (!isCaptain && !isAdmin)
            const Text(
              'Watching as Viewer. Only captains with budget can place bids.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white30, fontStyle: FontStyle.italic),
            ),

          if (isCaptain && teamId == null)
            const Text(
              'Captain access detected, but no team assigned. Contact Admin to assign your team.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.orangeAccent, fontStyle: FontStyle.italic),
            ),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildBidPanel(WidgetRef ref, AuctionModel liveAuction, String teamId, int myPurse) {
    return Column(
      children: [
        Text('YOUR BUDGET: \u20b9$myPurse', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 16),
        const Text('PLACE YOUR BID', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _bidBtn(ref, liveAuction.id, 10, liveAuction.currentBid, teamId, myPurse),
            _bidBtn(ref, liveAuction.id, 50, liveAuction.currentBid, teamId, myPurse),
            _bidBtn(ref, liveAuction.id, 100, liveAuction.currentBid, teamId, myPurse),
          ],
        ),
      ],
    );
  }

  Widget _bidBtn(WidgetRef ref, String auctionId, int increment, int current, String teamId, int myPurse) {
    bool canAfford = (current + increment) <= myPurse;
    return ElevatedButton(
      onPressed: canAfford ? () {
        ref.read(supabaseServiceProvider).placeBid(auctionId, teamId, current + increment);
      } : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: canAfford ? Colors.white10 : Colors.red.withOpacity(0.1),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white24)),
      ),
      child: Text('+\u20b9$increment'),
    );
  }

  Widget _buildAdminPanel(BuildContext context, WidgetRef ref, AuctionModel liveAuction, PlayerModel player) {
    final teamsFuture = ref.read(supabaseServiceProvider).getTeams();
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        children: [
          const Divider(color: Colors.white24),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('ADMIN ACTIONS', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              TextButton.icon(
                onPressed: () => _showUpdatePurseDialog(context, ref),
                icon: const Icon(Icons.account_balance_wallet, color: Colors.greenAccent, size: 16),
                label: const Text('ADJUST BUDGETS', style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () async {
                  if (liveAuction.currentBidTeamId == null || liveAuction.currentBid == 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No bids placed yet!'), backgroundColor: Colors.orange),
                    );
                    return;
                  }
                  final teams = await teamsFuture;
                  final winningTeam = teams.firstWhere((t) => t.id == liveAuction.currentBidTeamId, orElse: () => TeamModel(id: '', name: 'Unknown', purse: 0));
                  await ref.read(supabaseServiceProvider).sellPlayer(
                    liveAuction.id,
                    player.id,
                    liveAuction.currentBidTeamId,
                    liveAuction.currentBid,
                  );
                  if (context.mounted) {
                    _showCongratulationDialog(context, player.name, winningTeam.name, liveAuction.currentBid);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700], 
                  foregroundColor: Colors.white,
                ),
                child: const Text('SOLD'),
              ),
              const SizedBox(width: 16),
               ElevatedButton(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Mark as Unsold?'),
                      content: Text('Are you sure you want to mark ${player.name} as unsold?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          child: const Text('CONFIRM UNSOLD'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await ref.read(supabaseServiceProvider).sellPlayer(
                      liveAuction.id,
                      player.id,
                      null,
                      0,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${player.name} marked as UNSOLD'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700], foregroundColor: Colors.white),
                child: const Text('UNSOLD'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showUpdatePurseDialog(BuildContext context, WidgetRef ref) async {
    final teams = await ref.read(supabaseServiceProvider).getTeams();
    if (!context.mounted) return;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Adjust Team Budgets'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: teams.length,
            itemBuilder: (c, i) {
              final team = teams[i];
              final controller = TextEditingController(text: team.purse.toString());
              return ListTile(
                title: Text(team.name),
                trailing: SizedBox(
                  width: 100,
                  child: TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(prefixText: '\u20b9'),
                    onSubmitted: (val) async {
                      final n = int.tryParse(val);
                      if (n != null) {
                        await ref.read(supabaseServiceProvider).updateTeamPurse(team.id, n);
                        if (ctx.mounted) Navigator.pop(ctx);
                      }
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showCongratulationDialog(BuildContext context, String playerName, String teamName, int price) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.green[900],
        title: const Row(
          children: [
            Icon(Icons.celebration, color: Colors.amber, size: 32),
            SizedBox(width: 8),
            Text('SOLD!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events, color: Colors.amber, size: 64),
            const SizedBox(height: 16),
            Text(
              'Congratulations!',
              style: TextStyle(color: Colors.amber[200], fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              playerName,
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Sold to $teamName',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              '₹$price',
              style: const TextStyle(color: Colors.greenAccent, fontSize: 28, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: const Text('AWESOME!', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}


