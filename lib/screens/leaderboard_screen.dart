import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/match_provider.dart';
import '../providers/player_provider.dart';
import '../providers/supabase_provider.dart';
import '../models/match_model.dart';
import '../models/team_model.dart';
import '../models/player_model.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allEventsAsync = ref.watch(allMatchEventsStreamProvider);
    final playersAsync = ref.watch(playersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tournament Leaderboard'),
        backgroundColor: Colors.purple[900],
      ),
      body: allEventsAsync.when(
        data: (events) => playersAsync.when(
          data: (players) {
            // Aggregate stats
            Map<String, int> batsmenRuns = {};
            Map<String, int> bowlerWickets = {};

            for (var ev in events) {
              final player = players.firstWhere((p) => p.id == ev.batsmanId, orElse: () => PlayerModel(id: '', name: 'Unknown', role: '', basePrice: 0));
              batsmenRuns[player.name] = (batsmenRuns[player.name] ?? 0) + ev.runs;

              if (ev.wicketType != null && ev.wicketType != 'run-out') {
                final bowler = players.firstWhere((p) => p.id == ev.bowlerId, orElse: () => PlayerModel(id: '', name: 'Unknown', role: '', basePrice: 0));
                bowlerWickets[bowler.name] = (bowlerWickets[bowler.name] ?? 0) + 1;
              }
            }

            final topBatsmen = batsmenRuns.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
            final topBowlers = bowlerWickets.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

            return DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(icon: Icon(Icons.sports_cricket), text: 'Batsmen'),
                      Tab(icon: Icon(Icons.sports), text: 'Bowlers'),
                      Tab(icon: Icon(Icons.table_chart), text: 'Points Table'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildDynamicList('Most Runs', topBatsmen, 'Runs'),
                        _buildDynamicList('Most Wickets', topBowlers, 'Wickets'),
                        _buildPointsTable(ref),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error: $err')),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildDynamicList(String subtitle, List<MapEntry<String, int>> data, String unit) {
    if (data.isEmpty) return const Center(child: Text('No data yet.'));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: data.length,
      itemBuilder: (context, index) {
        final entry = data[index];
        if (entry.key == 'Unknown') return const SizedBox.shrink();
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: index == 0 ? Colors.amber : (index == 1 ? Colors.grey : Colors.brown),
              child: Text('#${index + 1}'),
            ),
            title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
            trailing: Text('${entry.value} $unit', style: const TextStyle(fontSize: 16, color: Colors.greenAccent)),
          ),
        );
      },
    );
  }

  Widget _buildPointsTable(WidgetRef ref) {
    return FutureBuilder(
      future: Future.wait([
        ref.read(supabaseServiceProvider).getTeams(),
        ref.read(supabaseServiceProvider).getMatches(),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final teams = snapshot.data?[0] as List<TeamModel>? ?? [];
        final matches = snapshot.data?[1] as List<MatchModel>? ?? [];

        // Simple calculation for demo - normally more complex with NRR
        Map<String, int> points = { for (var t in teams) t.id : 0 };
        for (var m in matches) {
           if (m.status == 'completed') {
             // Logic to determine winner would go here based on scoreData
             // For now, let's assume team1 win for even IDs and team2 for odd for demo if no logic exists
             // Ideally we'd calculate score here too
             points[m.team1Id] = (points[m.team1Id] ?? 0) + 2; 
           }
        }

        final sortedTeams = teams..sort((a, b) => (points[b.id] ?? 0).compareTo(points[a.id] ?? 0));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sortedTeams.length,
          itemBuilder: (ctx, i) {
            final t = sortedTeams[i];
            return Card(
              child: ListTile(
                title: Text(t.name),
                subtitle: Text('Games Played: ${matches.where((m) => m.team1Id == t.id || m.team2Id == t.id).length}'),
                trailing: Text('${points[t.id]} PTS', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
              ),
            );
          },
        );
      },
    );
  }
}
