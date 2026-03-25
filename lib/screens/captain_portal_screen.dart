import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/supabase_provider.dart';
import '../models/team_model.dart';
import '../models/player_model.dart';
import '../models/match_model.dart';

class CaptainPortalScreen extends ConsumerWidget {
  const CaptainPortalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Captain\'s Portal')),
      body: userAsync.when(
        data: (user) {
          if (user == null || user.teamId == null) {
            return const Center(child: Text('No team assigned. Contact Admin.'));
          }
          return _buildPortalContent(context, ref, user.teamId!);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildPortalContent(BuildContext context, WidgetRef ref, String teamId) {
    return FutureBuilder(
      future: Future.wait<dynamic>([
        ref.read(supabaseServiceProvider).client.from('teams').select().eq('id', teamId).single(),
        ref.read(supabaseServiceProvider).getMatches(),
        ref.read(supabaseServiceProvider).getTeamPlayers(teamId),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
        }
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));

        final data = snapshot.data as List<dynamic>;
        final team = TeamModel.fromJson(data[0]);
        final allMatches = data[1] as List<MatchModel>;
        final myPlayers = data[2] as List<PlayerModel>;

        final myMatchesFiltered = allMatches.where((m) => m.team1Id == teamId || m.team2Id == teamId).toList();

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          children: [
            _buildTeamHeader(team, myPlayers.length),
            const SizedBox(height: 32),
            _buildSectionHeader('YOUR SQUAD', Icons.people_alt, Colors.blueAccent),
            const SizedBox(height: 12),
            if (myPlayers.isEmpty)
              _buildEmptyState('No players signed yet. Head to Live Auction!')
            else
              ...myPlayers.map((p) => _buildPlayerCard(p)),
            
            const SizedBox(height: 32),
            _buildSectionHeader('UPCOMING FIXTURES', Icons.event_note, Colors.orangeAccent),
            const SizedBox(height: 12),
            if (myMatchesFiltered.isEmpty)
              _buildEmptyState('No matches scheduled for your team.')
            else
              ...myMatchesFiltered.map((m) => _buildMatchCard(m, teamId)),
            
            const SizedBox(height: 40),
          ],
        );
      },
    );
  }

  Widget _buildTeamHeader(TeamModel team, int squadSize) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[900]!, Colors.blue[700]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        children: [
          Text(
            team.name.toUpperCase(),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _headerStat('REMAINING PURSE', '₹${team.purse}', Colors.greenAccent)),
              Container(width: 1, height: 40, color: Colors.white24),
              Expanded(child: _headerStat('SQUAD SIZE', '$squadSize / 15', Colors.orangeAccent)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.bold, letterSpacing: 1)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          title, 
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white.withOpacity(0.8), letterSpacing: 1.5)
        ),
      ],
    );
  }

  Widget _buildPlayerCard(PlayerModel p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.blueAccent.withOpacity(0.1),
            child: const Icon(Icons.person, color: Colors.blueAccent),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                Text(p.role.toUpperCase(), style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchCard(MatchModel m, String teamId) {
    final opponent = m.team1Id == teamId ? m.team2Id : m.team1Id;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('UPCOMING', style: TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold)),
              Text(m.venue ?? 'Venue TBD', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          Text('vs $opponent', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          Text(m.status.toUpperCase(), style: const TextStyle(fontSize: 12, color: Colors.greenAccent, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(msg, style: const TextStyle(color: Colors.white24, fontStyle: FontStyle.italic)),
      ),
    );
  }
}
