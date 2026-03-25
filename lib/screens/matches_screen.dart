import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/match_provider.dart';
import '../providers/auth_provider.dart';
import '../models/team_model.dart';
import '../models/match_model.dart';
import '../providers/supabase_provider.dart';
import 'match_control_screen.dart';

class MatchesScreen extends ConsumerWidget {
  const MatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(liveMatchesStreamProvider);
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Fixtures')),
      body: FutureBuilder<List<TeamModel>>(
        future: ref.read(supabaseServiceProvider).getTeams(),
        builder: (context, teamSnapshot) {
          final teams = teamSnapshot.data ?? [];
          
          return matchesAsync.when(
            data: (matches) {
              if (matches.isEmpty) {
                return const Center(child: Text('No matches found.'));
              }
              final sortedMatches = matches..sort((a, b) => (b.scheduledAt ?? DateTime.now()).compareTo(a.scheduledAt ?? DateTime.now()));
              
              return ListView.builder(
                itemCount: sortedMatches.length,
                itemBuilder: (context, index) {
                  final match = sortedMatches[index];
                  final isAdmin = userAsync.value?.isAdmin ?? false;

                  final t1 = teams.firstWhere((t) => t.id == match.team1Id, orElse: () => TeamModel(id: '', name: '...', purse: 0));
                  final t2 = teams.firstWhere((t) => t.id == match.team2Id, orElse: () => TeamModel(id: '', name: '...', purse: 0));

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      children: [
                        ListTile(
                          title: Text('${t1.name} vs ${t2.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Status: ${match.status.toUpperCase()} | ${match.venue ?? "TBD"}'),
                              if (match.status == 'completed')
                                FutureBuilder<Map<String, dynamic>>(
                                  future: _getMatchResult(ref, match.id),
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData) return const SizedBox();
                                    final result = snapshot.data!;
                                    if (result['winner'] != null) {
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          '${result['winner']} wins!',
                                          style: TextStyle(
                                            color: Colors.green[700],
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      );
                                    }
                                    return const SizedBox();
                                  },
                                ),
                            ],
                          ),
                          onTap: () => context.push('/scorecard/${match.id}'),
                        ),
                        if (isAdmin)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (ctx) => MatchControlScreen(matchId: match.id))),
                                  icon: const Icon(Icons.settings),
                                  label: const Text('CONTROL'),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: () => context.push('/live_score/${match.id}'),
                                  icon: const Icon(Icons.sports_cricket),
                                  label: const Text('SCORE'),
                                ),
                              ],
                            ),
                          )
                      ],
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error: $err')),
          );
        },
      ),
    );
  }

  Future<Map<String, dynamic>> _getMatchResult(WidgetRef ref, String matchId) async {
    final events = await ref.read(supabaseServiceProvider).client.from('match_events').select().eq('match_id', matchId);
    int team1Score = 0;
    int team2Score = 0;
    
    for (var e in events) {
      if (e['is_undo'] == true) continue;
      final innings = e['innings'] as int? ?? 1;
      final int runs = (e['runs'] ?? 0) as int;
      final int extraRuns = (e['extra_runs'] ?? 0) as int;
      final totalRuns = runs + extraRuns;
      if (innings == 1) {
        team1Score += totalRuns;
      } else {
        team2Score += totalRuns;
      }
    }
    
    if (team1Score > team2Score) {
      return {'winner': 'Team 1', 'score': '$team1Score-$team2Score'};
    } else if (team2Score > team1Score) {
      return {'winner': 'Team 2', 'score': '$team2Score-$team1Score'};
    }
    return {'winner': null, 'score': '$team1Score-$team2Score'};
  }
}
