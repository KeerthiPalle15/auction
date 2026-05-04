import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/match_provider.dart';
import '../providers/supabase_provider.dart';
import '../models/match_event_model.dart';
import '../providers/auth_provider.dart';
import '../models/player_model.dart';
import '../models/match_model.dart';
import '../providers/wifi_provider.dart';
import '../services/wifi_scoring_service.dart';

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
  int _currentInnings = 1;
  int _firstInningsTotal = 0;
  int _currentOver = 0;
  int _currentBall = 0;
  bool isInningsEnded = false;
  bool _showEndInningsButton = false;
  String? _battingTeamId;
  String? _bowlingTeamId;
  late final WifiScoringService wifiService;
  bool _wifiConnected = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      wifiService = ref.read(wifiServiceProvider);
      ref.listen(wifiStatusProvider, (previous, next) {
        if (next.value == ConnectionStatus.paired) {
          setState(() => _wifiConnected = true);
        } else if ((next.value == ConnectionStatus.disconnected ||
            next.value == ConnectionStatus.error)) {
          setState(() => _wifiConnected = false);
        }
      });
    });
  }

  static const int MAX_WICKETS = 10;

  void _switchToSecondInnings() {
    setState(() {
      _currentInnings = 2;
      _currentOver = 0;
      _currentBall = 0;
      _strikerId = null;
      _nonStrikerId = null;
      _bowlerId = null;
      isInningsEnded = false;
      _showEndInningsButton = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '2nd Innings Started! Target: ${_firstInningsTotal + 1}',
          ),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _resetInningsState() {
    _currentOver = 0;
    _currentBall = 0;
    _strikerId = null;
    _nonStrikerId = null;
    _bowlerId = null;
  }

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

    final targetReached =
        _currentInnings == 2 &&
        (scoreData['runs'] as int) >= _firstInningsTotal + 1;

    final wickets = scoreData['wickets'] as int;
    _showEndInningsButton =
        _currentInnings ==
        1; // Always show innings switch button in 1st innings for easy access

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
            icon: Icon(
              Icons.wifi,
              color: _wifiConnected ? Colors.greenAccent : Colors.white54,
            ),
            onPressed: _toggleWifiPairing,
            tooltip: _wifiConnected ? 'WiFi Paired' : 'Pair WiFi',
          ),
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

              // Dynamic team roles based on innings
              final battingPlayers = (_currentInnings == 1)
                  ? team1Players
                  : team2Players;
              final bowlingPlayers = (_currentInnings == 1)
                  ? team2Players
                  : team1Players;
              final allMatchPlayers = [...team1Players, ...team2Players];

              return Column(
                children: [
                  _buildScoreCard(scoreData, match.totalOvers, targetReached),
                  if (!isInningsEnded)
                    _buildPlayerSelection(battingPlayers, bowlingPlayers),
                  if (_showEndInningsButton &&
                      _currentInnings == 1 &&
                      !isInningsEnded)
                    Container(
                      margin: const EdgeInsets.all(16),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.swap_horiz, color: Colors.white),
                        label: const Text(
                          'END 1st INNINGS & START 2nd',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        onPressed: _switchToSecondInnings,
                      ),
                    ),
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
                  userAsync.when(
                    data: (user) => user?.isAdmin == true && !isInningsEnded
                        ? _buildScoringPanel(scoreData)
                        : _buildViewerFooter(),
                    loading: () => const SizedBox(),
                    error: (_, _) => const SizedBox(),
                  ),
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

  Widget _buildScoreCard(
    Map<String, dynamic> scoreData,
    int? totalOvers,
    bool targetReached,
  ) {
    final currentScore = scoreData['runs'] as int;
    final target = _firstInningsTotal + 1;
    final isWinning = targetReached;

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
          if (targetReached) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'TARGET REACHED! MATCH WON',
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
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
          (p) => p.id == (ev.batsmanId ?? ''),
          orElse: () =>
              PlayerModel(id: '', name: 'Unknown', role: '', basePrice: 0),
        );
        final bowler = players.firstWhere(
          (p) => p.id == (ev.bowlerId ?? ''),
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
                : 'Runs: ${ev.runs} ${ev.extraType ?? ""}',
            style: const TextStyle(color: Colors.white),
          ),
          subtitle: Text(
            'Over ${ev.overNumber}.${ev.ballNumber} | ${batsman.name} | ${bowler.name}',
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
          if (_showEndInningsButton && _currentInnings == 1)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.sports_cricket, color: Colors.white),
                label: const Text(
                  'END 1st INNINGS',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onPressed: _switchToSecondInnings,
              ),
            ),
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
                  (r) => GestureDetector(
                    onTap: () => _addEvent({
                      'runs': r,
                      'wickets': 0,
                      'overs': scoreData['overs'],
                    }, runs: r),
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
              TextButton(
                onPressed: () =>
                    _addEvent(scoreData, extraRuns: 1, extraType: 'wide'),
                child: const Text(
                  'WIDE',
                  style: TextStyle(color: Colors.orangeAccent),
                ),
              ),
              TextButton(
                onPressed: () =>
                    _addEvent(scoreData, extraRuns: 1, extraType: 'no-ball'),
                child: const Text(
                  'NO BALL',
                  style: TextStyle(color: Colors.orangeAccent),
                ),
              ),
              ElevatedButton(
                onPressed: () => _showWicketTypeDialog(scoreData),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select Striker and Bowler first!'),
          ),
        );
      }
      return;
    }

    final match = ref
        .read(liveMatchesStreamProvider)
        .value
        ?.firstWhere(
          (m) => m.id == widget.matchId,
          orElse: () => throw 'Match not found',
        );
    final totalOvers = match?.totalOvers ?? 20;

    int newBall = _currentBall + 1;
    int newOver = _currentOver;
    final isLegalBall = extraType != 'wide' && extraType != 'no-ball';

    if (isLegalBall) {
      if (newBall > 6) {
        newOver++;
        newBall = 1;
      }
      if (newOver >= totalOvers) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Innings completed! Set overs reached'),
              backgroundColor: Colors.green,
            ),
          );
        }
        isInningsEnded = true;
        setState(() {});
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
    wifiService.sendEvent(event).catchError((e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('WiFi sync failed: $e')));
      }
    });

    setState(() {
      _currentOver = newOver;
      _currentBall = newBall;

      if (isLegalBall && _currentBall == 6) {
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
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Select Wicket Type',
          style: TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Bowled'),
                onTap: () {
                  Navigator.pop(context);
                  _addEvent(scoreData, wicketType: 'bowled');
                },
              ),
              ListTile(
                title: const Text('Caught'),
                onTap: () {
                  Navigator.pop(context);
                  _addEvent(scoreData, wicketType: 'caught');
                },
              ),
              ListTile(
                title: const Text('LBW'),
                onTap: () {
                  Navigator.pop(context);
                  _addEvent(scoreData, wicketType: 'lbw');
                },
              ),
              ListTile(
                title: const Text('Stumped'),
                onTap: () {
                  Navigator.pop(context);
                  _addEvent(scoreData, wicketType: 'stumped');
                },
              ),
              ListTile(
                title: const Text('Run Out'),
                onTap: () {
                  Navigator.pop(context);
                  _addEvent(scoreData, wicketType: 'run-out');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleWifiPairing() async {
    if (_wifiConnected) {
      wifiService.disconnect();
    } else {
      try {
        await wifiService.connect();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('WiFi pairing initiated... code 103625'),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('WiFi pair failed: $e')));
      }
    }
  }

  Widget _buildViewerFooter() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Match In Progress • Live Updates',
            style: TextStyle(
              color: Colors.white24,
              fontStyle: FontStyle.italic,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _wifiConnected
                  ? Colors.green.withOpacity(0.2)
                  : Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.wifi,
                  size: 16,
                  color: _wifiConnected ? Colors.greenAccent : Colors.redAccent,
                ),
                const SizedBox(width: 4),
                Text(
                  _wifiConnected ? 'PAIRED' : 'WiFi OFF',
                  style: TextStyle(
                    color: _wifiConnected
                        ? Colors.greenAccent
                        : Colors.redAccent,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
