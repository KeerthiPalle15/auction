import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/admin_dashboard.dart';
import 'screens/auction_screen.dart';
import 'screens/matches_screen.dart';
import 'screens/live_scoring_screen.dart';
import 'screens/scorecard_screen.dart';
import 'screens/leaderboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase. Please replace with your actual keys before running.
  await Supabase.initialize(
    url: 'https://xppiiozpqkwgscmlzonj.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhwcGlpb3pwcWt3Z3NjbWx6b25qIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQzNTM4MTYsImV4cCI6MjA4OTkyOTgxNn0.o6-YIkdrFuIp1woq_6PML1efPjBPZQVUl_Ijdp4Ehq8',
  );

  runApp(
    const ProviderScope(
      child: CricketApp(),
    ),
  );
}

class CricketApp extends ConsumerWidget {
  const CricketApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Standard Material 3 dark-green cricket theme
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.green,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    );

    final goRouter = GoRouter(
      initialLocation: '/',
      redirect: (context, state) {
        final session = Supabase.instance.client.auth.currentSession;
        final isAuthPath = state.matchedLocation == '/auth';
        
        if (session == null && !isAuthPath) {
          return '/auth';
        }
        if (session != null && isAuthPath) {
          return '/';
        }
        return null;
      },
      routes: [
        GoRoute(
          path: '/auth',
          builder: (context, state) => const AuthScreen(),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/admin',
          builder: (context, state) => const AdminDashboard(),
        ),
        GoRoute(
          path: '/auction',
          builder: (context, state) => const AuctionScreen(),
        ),
        GoRoute(
          path: '/matches',
          builder: (context, state) => const MatchesScreen(),
        ),
        GoRoute(
          path: '/live_score/:matchId',
          builder: (context, state) {
            final matchId = state.pathParameters['matchId']!;
            return LiveScoringScreen(matchId: matchId);
          },
        ),
        GoRoute(
          path: '/scorecard/:matchId',
          builder: (context, state) {
            final matchId = state.pathParameters['matchId']!;
            return ScorecardScreen(matchId: matchId);
          },
        ),
        GoRoute(
          path: '/leaderboard',
          builder: (context, state) => const LeaderboardScreen(),
        ),
      ],
    );

    return MaterialApp.router(
      title: 'Cricket Tournament App',
      theme: theme,
      routerConfig: goRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
