import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/supabase_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/auction_provider.dart';
import '../providers/player_provider.dart';
import '../models/auction_model.dart';
import '../models/player_model.dart';
import '../models/team_model.dart';
import 'match_management_screen.dart';
import 'auction_management_screen.dart';
import 'player_management_screen.dart';
import 'team_management_screen.dart';
import 'user_management_screen.dart';

class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> {
  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      data: (user) {
        if (user == null || !user.isAdmin) {
          return const Scaffold(
            body: Center(
              child: Text(
                'Unauthorized Access',
                style: TextStyle(color: Colors.red, fontSize: 18),
              ),
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: const Text('Admin Console'),
            centerTitle: true,
            elevation: 0,
            backgroundColor: Colors.transparent,
          ),
          extendBodyBehindAppBar: true,
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.red[900]!.withOpacity(0.8), Colors.black],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tournament Management',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Text(
                      'Manage matches, auctions, and players below.',
                      style: TextStyle(fontSize: 16, color: Colors.white70),
                    ),
                    const SizedBox(height: 20),

                    // ── Live Auction Controls ──
                    _LiveAuctionControlPanel(),

                    const SizedBox(height: 20),
                    Expanded(
                      child: GridView.count(
                        crossAxisCount: 3,
                        crossAxisSpacing: 15,
                        mainAxisSpacing: 15,
                        childAspectRatio: 1.2,
                        children: [
                          _buildAdminCard(
                            'Matches',
                            'Schedule and manage matches',
                            Icons.sports_cricket,
                            Colors.purpleAccent,
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (ctx) => const MatchManagementScreen(),
                              ),
                            ),
                          ),
                          _buildAdminCard(
                            'Auctions',
                            'Live settings and player queue',
                            Icons.gavel,
                            Colors.orangeAccent,
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (ctx) =>
                                    const AuctionManagementScreen(),
                              ),
                            ),
                          ),
                          _buildAdminCard(
                            'Players',
                            'Add and edit player profiles',
                            Icons.person_add,
                            Colors.blueAccent,
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (ctx) =>
                                    const PlayerManagementScreen(),
                              ),
                            ),
                          ),
                          _buildAdminCard(
                            'Teams',
                            'Manage team names and budgets',
                            Icons.group,
                            Colors.greenAccent,
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (ctx) => const TeamManagementScreen(),
                              ),
                            ),
                          ),
                          _buildAdminCard(
                            'User Roles',
                            'Promote captains and admins',
                            Icons.admin_panel_settings,
                            Colors.amberAccent,
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (ctx) => const UserManagementScreen(),
                              ),
                            ),
                          ),
                          _buildAdminCard(
                            'Set Global Purse',
                            'Update budget for all teams',
                            Icons.account_balance_wallet,
                            Colors.tealAccent,
                            () => _showGlobalPurseDialog(context, ref),
                          ),
                          _buildAdminCard(
                            'Direct Team Assign',
                            'Assign players to teams directly',
                            Icons.person_pin,
                            Colors.cyanAccent,
                            () => _showDirectTeamAssignmentDialog(context, ref),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Text('Error: $err', style: const TextStyle(color: Colors.red)),
      ),
    );
  }

  void _showGlobalPurseDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(text: '1000000');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Global Purse'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter amount to apply to ALL teams:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                prefixText: '₹',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () async {
              final val = int.tryParse(controller.text);
              if (val != null) {
                final teams = await ref
                    .read(supabaseServiceProvider)
                    .getTeams();
                for (final team in teams) {
                  await ref
                      .read(supabaseServiceProvider)
                      .updateTeamPurse(team.id, val);
                }
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Updated purse for ${teams.length} teams!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
            child: const Text('APPLY TO ALL'),
          ),
        ],
      ),
    );
  }

  void _showDirectTeamAssignmentDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => _DirectTeamAssignmentDialog(),
    );
  }

  Widget _buildAdminCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: Colors.white54),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _DirectTeamAssignmentDialog extends ConsumerStatefulWidget {
  @override
  ConsumerState<_DirectTeamAssignmentDialog> createState() =>
      _DirectTeamAssignmentDialogState();
}

class _DirectTeamAssignmentDialogState
    extends ConsumerState<_DirectTeamAssignmentDialog> {
  String? _selectedTeamId;
  String? _selectedPlayerId;
  final _priceController = TextEditingController(text: '0');

  @override
  Widget build(BuildContext context) {
    final teamsFuture = ref.read(supabaseServiceProvider).getTeams();
    final playersAsync = ref.watch(playersProvider);

    return AlertDialog(
      title: const Text('Direct Team Assignment'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FutureBuilder<List<TeamModel>>(
              future: teamsFuture,
              builder: (context, snapshot) {
                final teams = snapshot.data ?? [];
                return DropdownButtonFormField<String>(
                  initialValue: _selectedTeamId,
                  decoration: const InputDecoration(labelText: 'Select Team'),
                  items: teams
                      .map(
                        (t) =>
                            DropdownMenuItem(value: t.id, child: Text(t.name)),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _selectedTeamId = v),
                );
              },
            ),
            const SizedBox(height: 16),
            playersAsync.when(
              data: (players) {
                final availablePlayers = players
                    .where((p) => p.teamId == null)
                    .toList();
                return DropdownButtonFormField<String>(
                  initialValue: _selectedPlayerId,
                  decoration: const InputDecoration(labelText: 'Select Player'),
                  items: availablePlayers
                      .map(
                        (p) =>
                            DropdownMenuItem(value: p.id, child: Text(p.name)),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _selectedPlayerId = v),
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (_, _) => const Text('Error loading players'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Assign Price (₹)',
                prefixText: '₹',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        ElevatedButton(
          onPressed: _selectedTeamId == null || _selectedPlayerId == null
              ? null
              : () async {
                  final price = int.tryParse(_priceController.text) ?? 0;
                  final playerId = _selectedPlayerId!;
                  final teamId = _selectedTeamId!;

                  final service = ref.read(supabaseServiceProvider);
                  final teams = await service.getTeams();
                  final team = teams.firstWhere((t) => t.id == teamId);

                  if (price > team.purse) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Price exceeds team purse!'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                    return;
                  }

                  await service.client.from('auctions').insert({
                    'player_id': playerId,
                    'team_id': teamId,
                    'status': 'sold',
                    'sold_price': price,
                    'current_bid': price,
                    'current_bid_team_id': teamId,
                  });

                  await service.updateTeamPurse(teamId, team.purse - price);

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Player assigned to team!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
          child: const Text('ASSIGN'),
        ),
      ],
    );
  }
}

/// A self-contained widget that streams the live auction and shows SOLD/UNSOLD buttons.
class _LiveAuctionControlPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auctionsAsync = ref.watch(auctionsStreamProvider);

    return auctionsAsync.when(
      data: (auctions) {
        final live = auctions.where((a) => a.status == 'live').toList();
        if (live.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: const Row(
              children: [
                Icon(Icons.gavel, color: Colors.white38, size: 20),
                SizedBox(width: 12),
                Text(
                  'No live auction running',
                  style: TextStyle(color: Colors.white38),
                ),
              ],
            ),
          );
        }
        return Column(
          children: live
              .map((auction) => _AuctionControlCard(auction: auction))
              .toList(),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _AuctionControlCard extends ConsumerWidget {
  final AuctionModel auction;
  const _AuctionControlCard({required this.auction});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        ref
            .read(supabaseServiceProvider)
            .client
            .from('players')
            .select()
            .eq('id', auction.playerId)
            .maybeSingle(),
        ref.read(supabaseServiceProvider).getTeams(),
      ]),
      builder: (context, snapshot) {
        final rawPlayer = snapshot.data?[0] as Map<String, dynamic>?;
        final teams = (snapshot.data?[1] as List<TeamModel>?) ?? [];
        final playerName = rawPlayer?['name'] ?? 'Loading...';
        final currentBid = auction.currentBid;
        final bidTeam = teams.firstWhere(
          (t) => t.id == auction.currentBidTeamId,
          orElse: () => TeamModel(id: '', name: 'No bids yet', purse: 0),
        );

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orangeAccent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.orangeAccent.withOpacity(0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.gavel, color: Colors.orangeAccent, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'LIVE AUCTION',
                    style: TextStyle(
                      color: Colors.orangeAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.greenAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                playerName.toString().toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Current Bid: ₹$currentBid  •  ${bidTeam.name}',
                style: const TextStyle(color: Colors.white60, fontSize: 13),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle, size: 18),
                      label: const Text('SOLD'),
                      onPressed: () async {
                        await ref
                            .read(supabaseServiceProvider)
                            .sellPlayer(
                              auction.id,
                              auction.playerId,
                              auction.currentBidTeamId,
                              auction.currentBid,
                            );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '$playerName sold to ${bidTeam.name} for ₹$currentBid!',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.cancel, size: 18),
                      label: const Text('UNSOLD'),
                      onPressed: () async {
                        await ref
                            .read(supabaseServiceProvider)
                            .sellPlayer(auction.id, auction.playerId, null, 0);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Player marked as unsold.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[700],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SoldUnsoldSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auctionsAsync = ref.watch(auctionsStreamProvider);
    final playersAsync = ref.watch(playersProvider);

    return auctionsAsync.when(
      data: (auctions) {
        return playersAsync.when(
          data: (players) {
            final soldAuctions = auctions
                .where((a) => a.status == 'sold')
                .toList();
            final unsoldAuctions = auctions
                .where((a) => a.status == 'unsold')
                .toList();

            if (soldAuctions.isEmpty && unsoldAuctions.isEmpty) {
              return const SizedBox.shrink();
            }

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.people, color: Colors.white70, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'SOLD & UNSOLD PLAYERS',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (soldAuctions.isNotEmpty) ...[
                    Text(
                      'SOLD (${soldAuctions.length})',
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 80,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: soldAuctions.length,
                        itemBuilder: (ctx, i) {
                          final auction = soldAuctions[i];
                          final player = players.firstWhere(
                            (p) => p.id == auction.playerId,
                            orElse: () => PlayerModel(
                              id: '',
                              name: 'Unknown',
                              role: '',
                              basePrice: 0,
                            ),
                          );
                          final team = ref
                              .read(supabaseServiceProvider)
                              .getTeams()
                              .then(
                                (teams) => teams.firstWhere(
                                  (t) => t.id == auction.teamId,
                                  orElse: () => TeamModel(
                                    id: '',
                                    name: 'Unknown',
                                    purse: 0,
                                  ),
                                ),
                              );
                          return _PlayerChip(
                            player: player,
                            auction: auction,
                            teamFuture: team,
                            isSold: true,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (unsoldAuctions.isNotEmpty) ...[
                    Text(
                      'UNSOLD (${unsoldAuctions.length})',
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 80,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: unsoldAuctions.length,
                        itemBuilder: (ctx, i) {
                          final auction = unsoldAuctions[i];
                          final player = players.firstWhere(
                            (p) => p.id == auction.playerId,
                            orElse: () => PlayerModel(
                              id: '',
                              name: 'Unknown',
                              role: '',
                              basePrice: 0,
                            ),
                          );
                          return _PlayerChip(
                            player: player,
                            auction: auction,
                            teamFuture: Future.value(
                              TeamModel(id: '', name: 'Unassigned', purse: 0),
                            ),
                            isSold: false,
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _PlayerChip extends StatelessWidget {
  final PlayerModel player;
  final AuctionModel auction;
  final Future<TeamModel> teamFuture;
  final bool isSold;

  const _PlayerChip({
    required this.player,
    required this.auction,
    required this.teamFuture,
    required this.isSold,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSold
            ? Colors.green.withOpacity(0.1)
            : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSold
              ? Colors.green.withOpacity(0.3)
              : Colors.red.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            player.name.length > 15
                ? '${player.name.substring(0, 12)}...'
                : player.name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            player.role.toUpperCase(),
            style: TextStyle(
              color: isSold ? Colors.greenAccent : Colors.redAccent,
              fontSize: 10,
            ),
          ),
          if (isSold) ...[
            const SizedBox(height: 4),
            FutureBuilder<TeamModel>(
              future: teamFuture,
              builder: (ctx, snapshot) {
                return Text(
                  '₹${auction.soldPrice ?? 0} - ${snapshot.data?.name ?? 'Loading...'}',
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
