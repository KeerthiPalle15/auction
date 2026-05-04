import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/match_provider.dart';
import '../providers/supabase_provider.dart';
import '../models/match_event_model.dart';
import '../providers/auth_provider.dart';
import '../models/player_model.dart';
import '../models/match_model.dart';

class LiveScoringScreen extends ConsumerStatefulWidget {
  final String matchId;
  const LiveScoringScreen({super.key, required this.matchId});

  @override
  ConsumerState<LiveScoringScreen> createState() => _LiveScoringScreenState();
}

class _LiveScoringScreenState extends ConsumerState<LiveScoringScreen> {
  String? _strikerId;
  String? _nonStrikerId;
  String? _bowlerId;
  final int _currentInnings = 1;
  int _firstInningsTotal = 0;
  int _currentOver = 0;
  int _currentBall = 0;

  @override
  Widget build(BuildContext context) {
    final scoreData = ref.watch(
      inningsScoreProvider((widget.matchId, _currentInnings)),
    );
    final firstInningsScore = ref.watch(
      inningsScoreProvider((widget.matchId, 1)),
    );
    final eventsAsync = ref.watch(matchEventsStreamProvider(widget.matchId));
    final userAsync = ref.watch(currentUserProvider);
    final matchesAsync = ref.watch(liveMatchesStreamProvider);

    if (_currentInnings == 2 && firstInningsScore['runs'] > 0) {
      _firstInningsTotal = firstInningsScore['runs'] as int;
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Live Scoring',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.analytics_outlined,
              color: Colors.greenAccent,
            ),
            onPressed: () => context.push('/scorecard/${widget.matchId}'),
          ),
        ],
      ),
      body: matchesAsync.when(
        data: (matches) {
          final match = matches.firstWhere(
            (m) => m.id == widget.matchId,
            orElse: () => throw 'Match not found',
          );

          return FutureBuilder<List<List<PlayerModel>>>(
            future: Future.wait([
              ref.read(supabaseServiceProvider).getTeamPlayers(match.team1Id),
              ref.read(supabaseServiceProvider).getTeamPlayers(match.team2Id),
            ]),
            builder: (context, snapshot) {
              final team1Players = snapshot.data?[0] ?? [];
              final team2Players = snapshot.data?[1] ?? [];
              final allMatchPlayers = [...team1Players, ...team2Players];

              return Column(
                children: [
                  _buildScoreCard(scoreData, match.totalOvers),
                  _buildPlayerSelection(team1Players, team2Players),
                  const Divider(color: Colors.white10),
                  Expanded(
                    child: eventsAsync.when(
                      data: (events) =>
                          _buildEventsList(events, allMatchPlayers),
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (err, _) => Center(
                        child: Text(
                          'Error: $err',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                  ),
                  (userAsync.value?.isAdmin == true)
                      ? _buildScoringPanel(scoreData)
                      : _buildViewerFooter(),
                ],
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text('Error: $err', style: const TextStyle(color: Colors.red)),
        ),
      ),
    );
  }

  Widget _buildScoreCard(Map<String, dynamic> scoreData, int totalOvers) {
    final target = _firstInningsTotal > 0 ? _firstInningsTotal + 1 : 0;
    final currentScore = scoreData['runs'] as int;
    final isWinning = _currentInnings == 2 && currentScore >= target;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            isWinning ? Colors.green[700]! : Colors.green[900]!,
            isWinning ? Colors.green[500]! : Colors.green[700]!,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'INNINGS $_currentInnings',
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '($totalOvers overs)',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$currentScore / ${scoreData['wickets']}',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  if (_currentInnings == 2 && _firstInningsTotal > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Target: $target',
                      style: const TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Need ${target - currentScore} runs',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if (isWinning) ...[
                    const SizedBox(height: 4),
                    const Text(
                      'WINNING!',
                      style: TextStyle(
                        color: Colors.amber,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('OVERS', style: TextStyle(color: Colors.white70)),
                  Text(
                    '${scoreData['overs']}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerSelection(
    List<PlayerModel> battingPlayers,
    List<PlayerModel> bowlingPlayers,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white.withOpacity(0.05),
      child: Row(
        children: [
          Expanded(
            child: _playerDropdown(
              'Striker',
              _strikerId,
              battingPlayers,
              (v) => setState(() => _strikerId = v),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _playerDropdown(
              'Non-Striker',
              _nonStrikerId,
              battingPlayers,
              (v) => setState(() => _nonStrikerId = v),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _playerDropdown(
              'Bowler',
              _bowlerId,
              bowlingPlayers,
              (v) => setState(() => _bowlerId = v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _playerDropdown(
    String label,
    String? current,
    List<PlayerModel> players,
    ValueChanged<String?> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.white54),
        ),
        DropdownButton<String>(
          value: current,
          isExpanded: true,
          hint: const Text(
            'Select',
            style: TextStyle(fontSize: 12, color: Colors.white24),
          ),
          dropdownColor: Colors.grey[900],
          style: const TextStyle(color: Colors.white, fontSize: 13),
          items: players
              .map(
                (p) => DropdownMenuItem(
                  value: p.id,
                  child: Text(p.name, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildEventsList(
    List<MatchEventModel> events,
    List<PlayerModel> players,
  ) {
    return ListView.builder(
      itemCount: events.length,
      itemBuilder: (context, index) {
        final ev = events[index];
        final batsman = players.firstWhere(
          (p) => p.id == ev.batsmanId,
          orElse: () =>
              PlayerModel(id: '', name: 'Unknown', role: '', basePrice: 0),
        );
        final bowler = players.firstWhere(
          (p) => p.id == ev.bowlerId,
          orElse: () =>
              PlayerModel(id: '', name: 'Unknown', role: '', basePrice: 0),
        );
        final isWicket = ev.wicketType != null;

        return ListTile(
          dense: true,
          leading: CircleAvatar(
            backgroundColor: isWicket ? Colors.red : Colors.white10,
            child: Text(
              isWicket ? 'W' : '${ev.runs}',
              style: TextStyle(
                color: isWicket ? Colors.white : Colors.greenAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(
            isWicket
                ? 'Wicket: ${ev.wicketType}'
                : 'Runs: ${ev.runs} ${ev.extraType != null ? "(${ev.extraType})" : ""}',
            style: const TextStyle(color: Colors.white),
          ),
          subtitle: Text(
            'Over ${ev.overNumber}.${ev.ballNumber} | Batsman: ${batsman.name} | Bowler: ${bowler.name}',
            style: const TextStyle(color: Colors.white38),
          ),
        );
      },
    );
  }

  Widget _buildScoringPanel(Map<String, dynamic> scoreData) {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white.withOpacity(0.05),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'UMPIRE CONTROLS',
                style: TextStyle(
                  color: Colors.white54,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.undo, color: Colors.white54),
                onPressed: () => ref
                    .read(supabaseServiceProvider)
                    .undoLastEvent(widget.matchId),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [0, 1, 2, 3, 4, 6]
                .map(
                  (r) => InkWell(
                    onTap: () => _addEvent(scoreData, runs: r),
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.white10,
                      child: Text(
                        '$r',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              OutlinedButton(
                onPressed: () =>
                    _addEvent(scoreData, extraRuns: 1, extraType: 'wide'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orangeAccent,
                  side: const BorderSide(color: Colors.orangeAccent),
                ),
                child: const Text('WIDE'),
              ),
              OutlinedButton(
                onPressed: () =>
                    _addEvent(scoreData, extraRuns: 1, extraType: 'no-ball'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orangeAccent,
                  side: const BorderSide(color: Colors.orangeAccent),
                ),
                child: const Text('NO BALL'),
              ),
              ElevatedButton(
                onPressed: () => _showWicketTypeDialog(scoreData),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[900],
                  foregroundColor: Colors.white,
                ),
                child: const Text('WICKET'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _addEvent(
    Map<String, dynamic> scoreData, {
    int runs = 0,
    int extraRuns = 0,
    String? extraType,
    String? wicketType,
  }) {
    if (_strikerId == null || _bowlerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select Striker and Bowler first!'),
        ),
      );
      return;
    }

    final matchesAsync = ref.read(liveMatchesStreamProvider);
    final matchesData = matchesAsync.value;
    if (matchesData == null) return;
    final match = matchesData.firstWhere(
      (m) => m.id == widget.matchId,
      orElse: () => throw 'Match not found',
    );
    final totalOvers = match.totalOvers;

    int newBall = _currentBall + 1;
    int newOver = _currentOver;
    bool isLegalBall = extraType != 'wide' && extraType != 'no-ball';

    if (isLegalBall) {
      if (newBall > 6) {
        newOver++;
        newBall = 1;
      }
      if (newOver >= totalOvers) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bowler completed 1 over! Select a new Bowler'),
          ),
        );
        _bowlerId = null;
        return;
      }
    }

    final event = MatchEventModel(
      id: '',
      matchId: widget.matchId,
      innings: _currentInnings,
      overNumber: newOver,
      ballNumber: newBall,
      runs: runs,
      extraRuns: extraRuns,
      extraType: extraType,
      wicketType: wicketType,
      batsmanId: _strikerId,
      bowlerId: _bowlerId,
    );
    ref.read(supabaseServiceProvider).addMatchEvent(event);

    setState(() {
      _currentOver = newOver;
      _currentBall = newBall;

      if (isLegalBall && newBall == 1 && _currentBall == 6) {
        _bowlerId = null;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bowler completed 1 over! Select a new Bowler'),
          ),
        );
      }

      if (isLegalBall && (runs + extraRuns) % 2 != 0) {
        final temp = _strikerId;
        _strikerId = _nonStrikerId;
        _nonStrikerId = temp;
      }
    });
  }

  void _showWicketTypeDialog(Map<String, dynamic> scoreData) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Wicket Type', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text(
                'Bowled',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(dialogContext);
                _addEvent(scoreData, wicketType: 'bowled');
              },
            ),
            ListTile(
              title: const Text(
                'Caught',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(dialogContext);
                _addEvent(scoreData, wicketType: 'caught');
              },
            ),
            ListTile(
              title: const Text('LBW', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(dialogContext);
                _addEvent(scoreData, wicketType: 'lbw');
              },
            ),
            ListTile(
              title: const Text(
                'Run Out',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(dialogContext);
                _addEvent(scoreData, wicketType: 'run-out');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewerFooter() {
    return const Padding(
      padding: EdgeInsets.all(20),
      child: Text(
        'Match In Progress • Live Updates',
        style: TextStyle(color: Colors.white24, fontStyle: FontStyle.italic),
      ),
    );
  }
}
