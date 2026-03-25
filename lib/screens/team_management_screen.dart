import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/supabase_provider.dart';
import '../models/team_model.dart';

class TeamManagementScreen extends ConsumerStatefulWidget {
  const TeamManagementScreen({super.key});

  @override
  ConsumerState<TeamManagementScreen> createState() => _TeamManagementScreenState();
}

class _TeamManagementScreenState extends ConsumerState<TeamManagementScreen> {
  final _nameController = TextEditingController();
  final _purseController = TextEditingController(text: '1000000');

  void _showTeamForm([TeamModel? team]) {
    if (team != null) {
      _nameController.text = team.name;
      _purseController.text = team.purse.toString();
    } else {
      _nameController.clear();
      _purseController.text = '1000000';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(team == null ? 'Add New Team' : 'Edit Team', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Team Name', prefixIcon: Icon(Icons.group)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _purseController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Purse (₹)', prefixIcon: Icon(Icons.account_balance_wallet)),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                final data = {
                  'name': _nameController.text,
                  'purse': int.tryParse(_purseController.text) ?? 1000000,
                };
                if (team == null) {
                  await ref.read(supabaseServiceProvider).client.from('teams').insert(data);
                } else {
                  await ref.read(supabaseServiceProvider).client.from('teams').update(data).eq('id', team.id);
                }
                if (mounted) {
                  Navigator.pop(context);
                  setState(() {}); // Refresh list
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
              child: Text(team == null ? 'CREATE TEAM' : 'UPDATE TEAM'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Team Management')),
      body: FutureBuilder<List<TeamModel>>(
        future: ref.read(supabaseServiceProvider).getTeams(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final teams = snapshot.data ?? [];
          if (teams.isEmpty) {
            return const Center(child: Text('No teams created.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: teams.length,
            itemBuilder: (ctx, i) {
              final team = teams[i];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange.withOpacity(0.1),
                    child: const Icon(Icons.group, color: Colors.orange),
                  ),
                  title: Text(team.name),
                  subtitle: Text('Purse: ₹${team.purse}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showTeamForm(team)),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red), 
                        onPressed: () async {
                          await ref.read(supabaseServiceProvider).client.from('teams').delete().eq('id', team.id);
                          setState(() {});
                        }
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTeamForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
