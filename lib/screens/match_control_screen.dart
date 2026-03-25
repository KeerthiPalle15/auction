import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/supabase_provider.dart';
import '../providers/match_provider.dart';
import '../models/match_model.dart';
import '../models/team_model.dart';
import '../providers/auth_provider.dart';

class MatchControlScreen extends ConsumerStatefulWidget {
  final String matchId;
  const MatchControlScreen({super.key, required this.matchId});

  @override
  ConsumerState<MatchControlScreen> createState() => _MatchControlScreenState();
}

class _MatchControlScreenState extends ConsumerState<MatchControlScreen> {
  String? _tossWinnerId;
  String? _tossDecision;

  @override
  Widget build(BuildContext context) {
    final matchesAsync = ref.watch(liveMatchesStreamProvider);
    final userAsync = ref.watch(currentUserProvider);
    
    return userAsync.when(
      data: (user) {
        if (user == null || !user.isAdmin) {
          return const Scaffold(body: Center(child: Text('Unauthorized Access', style: TextStyle(color: Colors.red))));
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Match Control Center')),
          body: matchesAsync.when(
            data: (matches) {
              final match = matches.firstWhere((m) => m.id == widget.matchId, orElse: () => throw 'Match not found');
              return FutureBuilder<List<TeamModel>>(
                future: ref.read(supabaseServiceProvider).getTeams(),
                builder: (context, teamSnapshot) {
                  final teams = teamSnapshot.data ?? [];
                  final t1 = teams.firstWhere((t) => t.id == match.team1Id, orElse: () => TeamModel(id: '', name: '...', purse: 0));
                  final t2 = teams.firstWhere((t) => t.id == match.team2Id, orElse: () => TeamModel(id: '', name: '...', purse: 0));

                  return ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      _buildStatusHeader(match, t1, t2),
                      const SizedBox(height: 32),
                      if (match.status == 'upcoming') 
                        _buildTossSection(match, t1, t2),
                      if (match.status == 'live')
                        _buildInningsSection(match),
                      const SizedBox(height: 32),
                      if (match.status != 'completed')
                        ElevatedButton(
                          onPressed: () => _completeMatch(match),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red[900], foregroundColor: Colors.white, padding: const EdgeInsets.all(16)),
                          child: const Text('COMPLETE MATCH & RESOLVE WINNER'),
                        ),
                    ],
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error: $err')),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
    );
  }

  Widget _buildStatusHeader(MatchModel match, TeamModel t1, TeamModel t2) {
    String tossWinnerName = match.tossWinnerId == t1.id ? t1.name : (match.tossWinnerId == t2.id ? t2.name : 'Unknown');
    return Card(
      color: Colors.blueGrey[900],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('MATCH STATUS: ${match.status.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.greenAccent)),
            if (match.tossWinnerId != null)
              Text('Toss: Won by $tossWinnerName - Elected to ${match.tossDecision?.toUpperCase()}', style: const TextStyle(color: Colors.white70)),
            if (match.innings != null)
              Text('Innings ${match.innings} In Progress', style: const TextStyle(color: Colors.orangeAccent, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildTossSection(MatchModel match, TeamModel t1, TeamModel t2) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Toss Management', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _tossWinnerId,
          decoration: const InputDecoration(labelText: 'Toss Winner'),
          items: [
            DropdownMenuItem(value: t1.id, child: Text(t1.name)),
            DropdownMenuItem(value: t2.id, child: Text(t2.name)),
          ],
          onChanged: (v) => setState(() => _tossWinnerId = v),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: RadioListTile<String>(
                title: const Text('BAT'),
                value: 'bat',
                groupValue: _tossDecision,
                onChanged: (v) => setState(() => _tossDecision = v),
              ),
            ),
            Expanded(
              child: RadioListTile<String>(
                title: const Text('BOWL'),
                value: 'bowl',
                groupValue: _tossDecision,
                onChanged: (v) => setState(() => _tossDecision = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () async {
            if (_tossWinnerId == null || _tossDecision == null) return;
            await ref.read(supabaseServiceProvider).updateMatch(match.id, {
              'toss_winner_id': _tossWinnerId,
              'toss_decision': _tossDecision,
              'status': 'live',
              'innings': 1,
            });
          },
          child: const Text('START MATCH'),
        ),
      ],
    );
  }

  Widget _buildInningsSection(MatchModel match) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Innings Management', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        if (match.innings == 1)
          ElevatedButton(
            onPressed: () async {
               // Calculate 1st innings score to set target
               final score = ref.read(scoreProvider(match.id));
               await ref.read(supabaseServiceProvider).updateMatch(match.id, {
                 'innings': 2,
                 'target': score['runs'] + 1,
               });
            },
            child: const Text('SWITCH TO 2ND INNINGS'),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Text('TARGET: ${match.target ?? "..."} RUNS', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange)),
          ),
      ],
    );
  }

  void _completeMatch(MatchModel match) async {
    await ref.read(supabaseServiceProvider).updateMatch(match.id, {'status': 'completed'});
    if (mounted) Navigator.pop(context);
  }
}
