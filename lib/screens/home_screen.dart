import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/supabase_provider.dart';
import '../models/user_model.dart';
import 'captain_portal_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.green[900]!.withOpacity(0.8), Colors.black],
          ),
        ),
        child: SafeArea(
          child: userAsync.when(
            data: (user) {
              if (user == null) {
                return _buildLoadingOrError('Setup Pending. Contact Admin.');
              }
              return _buildDashboard(context, ref, user);
            },
            loading: () => const Center(child: CircularProgressIndicator(color: Colors.greenAccent)),
            error: (err, _) => _buildLoadingOrError('Error: $err'),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingOrError(String msg) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.orangeAccent),
          const SizedBox(height: 16),
          Text(msg, style: const TextStyle(color: Colors.white70, fontSize: 18)),
        ],
      ),
    );
  }

  Widget _buildDashboard(BuildContext context, WidgetRef ref, UserModel user) {
    return Column(
      children: [
        _buildTopBar(context, ref, user),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            children: [
              _buildWelcomeSection(user),
              const SizedBox(height: 32),
              if (user.isAdmin) ...[
                _buildSectionHeader('Management'),
                _buildActionCard(context, 'Admin Dashboard', 'Manage Teams, Players & Users', Icons.admin_panel_settings, Colors.redAccent, () => context.push('/admin')),
                const SizedBox(height: 16),
              ],
              if (user.isCaptain) ...[
                _buildSectionHeader('Your Team'),
                _buildActionCard(context, 'Captain Portal', 'Squad Roster & Fixtures', Icons.stars, Colors.blueAccent, () => Navigator.push(context, MaterialPageRoute(builder: (ctx) => const CaptainPortalScreen()))),
                const SizedBox(height: 16),
              ],
              _buildSectionHeader('Tournament Flow'),
              _buildActionCard(context, 'Live Auction', 'Bidding & Real-time Updates', Icons.gavel, Colors.orangeAccent, () => context.push('/auction')),
              const SizedBox(height: 16),
              _buildActionCard(context, 'Match Fixtures', 'Schedule & Live Scores', Icons.sports_cricket, Colors.greenAccent, () => context.push('/matches')),
              const SizedBox(height: 16),
              _buildActionCard(context, 'Leaderboard', 'Standings & Player Stats', Icons.leaderboard, Colors.purpleAccent, () => context.push('/leaderboard')),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar(BuildContext context, WidgetRef ref, UserModel user) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('V-CRIC', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.greenAccent, letterSpacing: 2)),
          IconButton(
            onPressed: () async {
               await ref.read(supabaseServiceProvider).signOut();
               if (context.mounted) context.go('/auth');
            },
            icon: const Icon(Icons.logout, color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection(UserModel user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Welcome,', style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.6))),
        Text(user.email.split('@')[0].toUpperCase(), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: _getRoleColor(user.role).withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _getRoleColor(user.role).withOpacity(0.5)),
          ),
          child: Text(user.role.toUpperCase(), style: TextStyle(color: _getRoleColor(user.role), fontWeight: FontWeight.bold, fontSize: 12)),
        ),
      ],
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin': return Colors.redAccent;
      case 'captain': return Colors.blueAccent;
      default: return Colors.greenAccent;
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(title.toUpperCase(), style: const TextStyle(color: Colors.white54, letterSpacing: 1.5, fontSize: 13, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildActionCard(BuildContext context, String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
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
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.5))),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.3)),
          ],
        ),
      ),
    );
  }
}
