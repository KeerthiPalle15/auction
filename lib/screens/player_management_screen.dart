import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/supabase_provider.dart';
import '../providers/player_provider.dart';
import '../models/player_model.dart';

class PlayerManagementScreen extends ConsumerStatefulWidget {
  const PlayerManagementScreen({super.key});

  @override
  ConsumerState<PlayerManagementScreen> createState() => _PlayerManagementScreenState();
}

class _PlayerManagementScreenState extends ConsumerState<PlayerManagementScreen> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController(text: '500');
  String _role = 'batsman';
  final List<String> _roles = ['batsman', 'bowler', 'all-rounder', 'wicketkeeper'];

  void _showPlayerForm([PlayerModel? player]) {
    if (player != null) {
      _nameController.text = player.name;
      _role = player.role;
      _priceController.text = player.basePrice.toString();
    } else {
      _nameController.clear();
      _role = 'batsman';
      _priceController.text = '500';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateSB) {
          return Padding(
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
                Text(player == null ? 'Add New Player' : 'Edit Player', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Player Name', prefixIcon: Icon(Icons.person)),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _role,
                  decoration: const InputDecoration(labelText: 'Role', prefixIcon: Icon(Icons.sports_cricket)),
                  items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r.toUpperCase()))).toList(),
                  onChanged: (v) => setStateSB(() => _role = v!),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Base Price (₹)', prefixIcon: Icon(Icons.currency_rupee)),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    final data = {
                      'name': _nameController.text,
                      'role': _role,
                      'base_price': int.tryParse(_priceController.text) ?? 500,
                    };
                    if (player == null) {
                      await ref.read(supabaseServiceProvider).client.from('players').insert(data);
                    } else {
                      await ref.read(supabaseServiceProvider).updatePlayer(player.id, data);
                    }
                    if (mounted) {
                      Navigator.pop(context);
                      ref.invalidate(playersProvider);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                  child: Text(player == null ? 'ADD PLAYER' : 'UPDATE PLAYER'),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playersAsync = ref.watch(playersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Player Management')),
      body: playersAsync.when(
        data: (players) {
          if (players.isEmpty) {
            return const Center(child: Text('No players registered.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: players.length,
            itemBuilder: (ctx, i) {
              final player = players[i];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.withOpacity(0.1),
                    child: const Icon(Icons.person, color: Colors.blue),
                  ),
                  title: Text(player.name),
                  subtitle: Text('${player.role.toUpperCase()} | Base: ₹${player.basePrice}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showPlayerForm(player)),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red), 
                        onPressed: () async {
                          await ref.read(supabaseServiceProvider).deletePlayer(player.id);
                          ref.invalidate(playersProvider);
                        }
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showPlayerForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
