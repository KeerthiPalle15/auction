import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/supabase_provider.dart';
import '../models/user_model.dart';
import '../models/team_model.dart';

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() =>
      _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('User Management')),
      body: FutureBuilder<List<dynamic>>(
        future: Future.wait([
          ref.read(supabaseServiceProvider).client.from('users').select(),
          ref.read(supabaseServiceProvider).getTeams(),
        ]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final usersData = snapshot.data?[0] as List? ?? [];
          final teams = snapshot.data?[1] as List<TeamModel>? ?? [];
          final users = usersData.map((e) => UserModel.fromJson(e)).toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            itemBuilder: (ctx, i) {
              final user = users[i];
              final teamName = teams
                  .firstWhere(
                    (t) => t.id == user.teamId,
                    orElse: () => TeamModel(id: '', name: 'None', purse: 0),
                  )
                  .name;

              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.person_outline),
                  ),
                  title: Text(user.email),
                  subtitle: Text(
                    'Role: ${user.role.toUpperCase()} | Team: $teamName',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.settings, color: Colors.blue),
                    onPressed: () => _showUserOptions(user, teams),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showUserOptions(UserModel user, List<TeamModel> teams) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        String role = user.role;
        String? teamId = user.teamId;

        return StatefulBuilder(
          builder: (context, setStateSB) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Update User: ${user.email}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: ['admin', 'captain', 'viewer']
                        .map(
                          (r) => DropdownMenuItem(
                            value: r,
                            child: Text(r.toUpperCase()),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setStateSB(() => role = v!),
                  ),
                  const SizedBox(height: 16),
                  if (role == 'captain')
                    DropdownButtonFormField<String>(
                      initialValue: teamId,
                      decoration: const InputDecoration(
                        labelText: 'Assign Team',
                      ),
                      items: teams
                          .map(
                            (t) => DropdownMenuItem(
                              value: t.id,
                              child: Text(t.name),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setStateSB(() => teamId = v),
                    ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () async {
                      await ref
                          .read(supabaseServiceProvider)
                          .client
                          .from('users')
                          .update({
                            'role': role,
                            'team_id': role == 'captain' ? teamId : null,
                          })
                          .eq('id', user.id);
                      if (mounted) {
                        Navigator.pop(context);
                        setState(() {});
                      }
                    },
                    child: const Text('SAVE CHANGES'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
