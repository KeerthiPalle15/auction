import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/player_model.dart';
import '../services/supabase_service.dart';
import 'supabase_provider.dart';

final playersProvider = StreamProvider<List<PlayerModel>>((ref) {
  final service = ref.watch(supabaseServiceProvider);
  return service.client.from('players').stream(primaryKey: ['id']).map((list) {
    return list.map((e) => PlayerModel.fromJson(e)).toList();
  });
});
