import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/match_model.dart';
import '../models/match_event_model.dart';
import 'supabase_provider.dart';

final liveMatchesStreamProvider = StreamProvider<List<MatchModel>>((ref) {
  final service = ref.watch(supabaseServiceProvider);
  return service.streamLiveMatches();
});

final matchEventsStreamProvider = StreamProvider.family<List<MatchEventModel>, String>((ref, matchId) {
  final service = ref.watch(supabaseServiceProvider);
  return service.streamMatchEvents(matchId);
});

final allMatchEventsStreamProvider = StreamProvider<List<MatchEventModel>>((ref) {
  final service = ref.watch(supabaseServiceProvider);
  return service.client.from('match_events').stream(primaryKey: ['id']).map((list) {
    return list.map((e) => MatchEventModel.fromJson(e)).toList();
  });
});

// A computed provider to calculate score for a specific innings
final scoreProvider = Provider.family<Map<String, dynamic>, String>((ref, matchId) {
  final eventsAsync = ref.watch(matchEventsStreamProvider(matchId));
  return eventsAsync.maybeWhen(
    data: (events) {
      if (events.isEmpty) return {'runs': 0, 'wickets': 0, 'overs': '0.0'};
      
      int totalRuns = 0;
      int totalWickets = 0;
      int totalBalls = 0;

      for (var e in events) {
        if (!e.isUndo) {
          totalRuns += e.runs + e.extraRuns;
          if (e.wicketType != null && e.wicketType!.isNotEmpty) {
            totalWickets += 1;
          }
          if (e.extraType != 'wide' && e.extraType != 'no-ball') {
            totalBalls += 1;
          }
        }
      }

      int overFull = totalBalls ~/ 6;
      int overBalls = totalBalls % 6;
      String overDisplay = '$overFull.$overBalls';

      return {
        'runs': totalRuns,
        'wickets': totalWickets,
        'overs': overDisplay,
      };
    },
    orElse: () => {'runs': 0, 'wickets': 0, 'overs': '0.0'},
  );
});

// Score provider with innings filter
final inningsScoreProvider = Provider.family<Map<String, dynamic>, (String, int)>((ref, params) {
  final (matchId, innings) = params;
  final eventsAsync = ref.watch(matchEventsStreamProvider(matchId));
  return eventsAsync.maybeWhen(
    data: (events) {
      if (events.isEmpty) return {'runs': 0, 'wickets': 0, 'overs': '0.0'};
      
      int totalRuns = 0;
      int totalWickets = 0;
      int totalBalls = 0;

      for (var e in events) {
        if (!e.isUndo && e.innings == innings) {
          totalRuns += e.runs + e.extraRuns;
          if (e.wicketType != null && e.wicketType!.isNotEmpty) {
            totalWickets += 1;
          }
          if (e.extraType != 'wide' && e.extraType != 'no-ball') {
            totalBalls += 1;
          }
        }
      }

      int overFull = totalBalls ~/ 6;
      int overBalls = totalBalls % 6;
      String overDisplay = '$overFull.$overBalls';

      return {
        'runs': totalRuns,
        'wickets': totalWickets,
        'overs': overDisplay,
      };
    },
    orElse: () => {'runs': 0, 'wickets': 0, 'overs': '0.0'},
  );
});

// Provider for first innings score
final firstInningsScoreProvider = Provider.family<int, String>((ref, matchId) {
  final eventsAsync = ref.watch(matchEventsStreamProvider(matchId));
  return eventsAsync.maybeWhen(
    data: (events) {
      int totalRuns = 0;
      for (var e in events) {
        if (!e.isUndo && e.innings == 1) {
          totalRuns += e.runs + e.extraRuns;
        }
      }
      return totalRuns;
    },
    orElse: () => 0,
  );
});

// Provider for second innings score
final secondInningsScoreProvider = Provider.family<int, String>((ref, matchId) {
  final eventsAsync = ref.watch(matchEventsStreamProvider(matchId));
  return eventsAsync.maybeWhen(
    data: (events) {
      int totalRuns = 0;
      for (var e in events) {
        if (!e.isUndo && e.innings == 2) {
          totalRuns += e.runs + e.extraRuns;
        }
      }
      return totalRuns;
    },
    orElse: () => 0,
  );
});
