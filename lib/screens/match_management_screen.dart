import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/supabase_provider.dart';
import '../models/match_model.dart';
import '../models/team_model.dart';
import '../providers/match_provider.dart';

class MatchManagementScreen extends ConsumerStatefulWidget {
  const MatchManagementScreen({super.key});

  @override
  ConsumerState<MatchManagementScreen> createState() => _MatchManagementScreenState();
}

class _MatchManagementScreenState extends ConsumerState<MatchManagementScreen> {
  final _venueController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String? _t1;
  String? _t2;
  final _oversController = TextEditingController(text: '20');

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time != null) {
      setState(() => _selectedTime = time);
    }
  }

  void _createMatch() async {
    if (_t1 == null || _t2 == null || _t1 == _t2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select two different teams')));
      return;
    }

    DateTime? scheduledAt;
    if (_selectedDate != null && _selectedTime != null) {
      scheduledAt = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );
    }

    try {
      await ref.read(supabaseServiceProvider).createMatch(
        _t1!,
        _t2!,
        venue: _venueController.text.isEmpty ? null : _venueController.text,
        scheduledAt: scheduledAt,
        totalOvers: int.tryParse(_oversController.text) ?? 20,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Match scheduled successfully!')));
        setState(() {
          _t1 = null;
          _t2 = null;
          _venueController.clear();
          _selectedDate = null;
          _selectedTime = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _showAddMatchSheet(List<TeamModel> teams) {
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
                const Text('Schedule New Match', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _t1,
                  decoration: const InputDecoration(labelText: 'Team 1'),
                  items: teams.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))).toList(),
                  onChanged: (v) => setStateSB(() => _t1 = v),
                ),
                const SizedBox(height: 8),
                const Center(child: Text('VS', style: TextStyle(fontWeight: FontWeight.bold))),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _t2,
                  decoration: const InputDecoration(labelText: 'Team 2'),
                  items: teams.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))).toList(),
                  onChanged: (v) => setStateSB(() => _t2 = v),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _venueController,
                  decoration: const InputDecoration(labelText: 'Venue', prefixIcon: Icon(Icons.location_on)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _oversController,
                  decoration: const InputDecoration(labelText: 'Match Overs', prefixIcon: Icon(Icons.timer)),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                           await _pickDate();
                           setStateSB(() {});
                        },
                        icon: const Icon(Icons.calendar_today),
                        label: Text(_selectedDate == null ? 'Pick Date' : DateFormat('MMM d, y').format(_selectedDate!)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await _pickTime();
                          setStateSB(() {});
                        },
                        icon: const Icon(Icons.access_time),
                        label: Text(_selectedTime == null ? 'Pick Time' : _selectedTime!.format(context)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _createMatch,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  child: const Text('SCHEDULE MATCH'),
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
    final matchesAsync = ref.watch(liveMatchesStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Match Management')),
      body: FutureBuilder<List<TeamModel>>(
        future: ref.read(supabaseServiceProvider).getTeams(),
        builder: (context, teamSnapshot) {
          final teams = teamSnapshot.data ?? [];
          
          return matchesAsync.when(
            data: (matches) {
              if (matches.isEmpty) {
                return const Center(child: Text('No matches scheduled yet.'));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: matches.length,
                itemBuilder: (ctx, i) {
                  final match = matches[i];
                  final t1 = teams.firstWhere((t) => t.id == match.team1Id, orElse: () => TeamModel(id: '', name: 'Unknown', purse: 0));
                  final t2 = teams.firstWhere((t) => t.id == match.team2Id, orElse: () => TeamModel(id: '', name: 'Unknown', purse: 0));

                  return Card(
                    child: ListTile(
                      title: Text('${t1.name} vs ${t2.name}'),
                      subtitle: Text('${match.venue ?? "No Venue"} | ${match.scheduledAt != null ? DateFormat('MMM d, h:mm a').format(match.scheduledAt!) : "TBD"}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          await ref.read(supabaseServiceProvider).deleteMatch(match.id);
                        },
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error: $err')),
          );
        }
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final teams = await ref.read(supabaseServiceProvider).getTeams();
          if (mounted) _showAddMatchSheet(teams);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
