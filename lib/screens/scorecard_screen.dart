import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/match_provider.dart';
import '../providers/player_provider.dart';
import '../models/player_model.dart';

class ScorecardScreen extends ConsumerWidget {
  final String matchId;
  const ScorecardScreen({super.key, required this.matchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(matchEventsStreamProvider(matchId));
    final scoreData = ref.watch(scoreProvider(matchId));
    final playersAsync = ref.watch(playersProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Match Scorecard', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
      ),
      body: playersAsync.when(
        data: (allPlayers) {
          return eventsAsync.when(
            data: (events) {
              // Aggregate Stats
              Map<String, Map<String, num>> batsmenStats = {};
              Map<String, Map<String, num>> bowlerStats = {};

              for (var ev in events) {
                if (ev.isUndo) continue;
                
                // Batting
                final batId = ev.batsmanId ?? 'Unknown';
                batsmenStats.putIfAbsent(batId, () => {'R': 0, 'B': 0, '4s': 0, '6s': 0});
                if (ev.extraType != 'wide') {
                   batsmenStats[batId]!['B'] = batsmenStats[batId]!['B']! + 1;
                   batsmenStats[batId]!['R'] = batsmenStats[batId]!['R']! + ev.runs;
                   if (ev.runs == 4) batsmenStats[batId]!['4s'] = batsmenStats[batId]!['4s']! + 1;
                   if (ev.runs == 6) batsmenStats[batId]!['6s'] = batsmenStats[batId]!['6s']! + 1;
                }

                // Bowling
                final bowlId = ev.bowlerId ?? 'Unknown';
                bowlerStats.putIfAbsent(bowlId, () => {'O_balls': 0, 'R': 0, 'W': 0});
                bowlerStats[bowlId]!['R'] = bowlerStats[bowlId]!['R']! + ev.runs + ev.extraRuns;
                if (ev.extraType != 'wide' && ev.extraType != 'no-ball') {
                  bowlerStats[bowlId]!['O_balls'] = bowlerStats[bowlId]!['O_balls']! + 1;
                }
                if (ev.wicketType != null && ev.wicketType != 'run-out') {
                  bowlerStats[bowlId]!['W'] = bowlerStats[bowlId]!['W']! + 1;
                }
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildSummaryCard(scoreData),
                    const SizedBox(height: 24),
                    _buildSectionTitle('BATTING'),
                    _buildBattingTable(batsmenStats, allPlayers),
                    const SizedBox(height: 32),
                    _buildSectionTitle('BOWLING'),
                    _buildBowlingTable(bowlerStats, allPlayers),
                  ],
                ),
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

  Widget _buildSummaryCard(Map<String, dynamic> scoreData) {
    return Card(
      color: Colors.green[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        width: double.infinity,
        child: Column(
          children: [
            const Text('INNINGS 1', style: TextStyle(color: Colors.white60, letterSpacing: 1.5)),
            const SizedBox(height: 8),
            Text(
              '${scoreData['runs']} / ${scoreData['wickets']}',
              style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text('Overs: ${scoreData['overs']}', style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.greenAccent),
      ),
    );
  }

  Widget _buildBattingTable(Map<String, Map<String, num>> stats, List<PlayerModel> players) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(Colors.white.withOpacity(0.05)),
        columnSpacing: 24,
        columns: const [
          DataColumn(label: Text('Batsman', style: TextStyle(color: Colors.white70))),
          DataColumn(label: Text('R', style: TextStyle(color: Colors.white70))),
          DataColumn(label: Text('B', style: TextStyle(color: Colors.white70))),
          DataColumn(label: Text('4s', style: TextStyle(color: Colors.white70))),
          DataColumn(label: Text('6s', style: TextStyle(color: Colors.white70))),
          DataColumn(label: Text('SR', style: TextStyle(color: Colors.white70))),
        ],
        rows: stats.entries.map((e) {
          final p = players.firstWhere((p) => p.id == e.key, orElse: () => PlayerModel(id: '', name: 'Unknown', role: '', basePrice: 0));
          final R = e.value['R']!;
          final B = e.value['B']!;
          double sr = B > 0 ? (R / B) * 100 : 0;
          return DataRow(cells: [
            DataCell(Text(p.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            DataCell(Text('$R', style: const TextStyle(color: Colors.white))),
            DataCell(Text('$B', style: const TextStyle(color: Colors.white))),
            DataCell(Text('${e.value['4s']}', style: const TextStyle(color: Colors.white))),
            DataCell(Text('${e.value['6s']}', style: const TextStyle(color: Colors.white))),
            DataCell(Text(sr.toStringAsFixed(1), style: const TextStyle(color: Colors.greenAccent))),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildBowlingTable(Map<String, Map<String, num>> stats, List<PlayerModel> players) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(Colors.white.withOpacity(0.05)),
        columnSpacing: 24,
        columns: const [
          DataColumn(label: Text('Bowler', style: TextStyle(color: Colors.white70))),
          DataColumn(label: Text('O', style: TextStyle(color: Colors.white70))),
          DataColumn(label: Text('R', style: TextStyle(color: Colors.white70))),
          DataColumn(label: Text('W', style: TextStyle(color: Colors.white70))),
          DataColumn(label: Text('ECO', style: TextStyle(color: Colors.white70))),
        ],
        rows: stats.entries.map((e) {
          final p = players.firstWhere((p) => p.id == e.key, orElse: () => PlayerModel(id: '', name: 'Unknown', role: '', basePrice: 0));
          final balls = e.value['O_balls']!;
          final R = e.value['R']!;
          final W = e.value['W']!;
          final overs = '${balls ~/ 6}.${balls % 6}';
          double eco = balls > 0 ? (R / balls) * 6 : 0;
          return DataRow(cells: [
            DataCell(Text(p.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            DataCell(Text(overs, style: const TextStyle(color: Colors.white))),
            DataCell(Text('$R', style: const TextStyle(color: Colors.white))),
            DataCell(Text('$W', style: const TextStyle(color: Colors.white))),
            DataCell(Text(eco.toStringAsFixed(1), style: const TextStyle(color: Colors.greenAccent))),
          ]);
        }).toList(),
      ),
    );
  }
}
