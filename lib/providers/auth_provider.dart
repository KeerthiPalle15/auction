import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import 'supabase_provider.dart';

final authStateProvider = StreamProvider<AuthState>((ref) {
  final service = ref.watch(supabaseServiceProvider);
  return service.authStateChanges;
});

final currentUserProvider = StreamProvider<UserModel?>((ref) {
  final service = ref.watch(supabaseServiceProvider);
  final user = service.currentUser;
  
  if (user == null) return Stream.value(null);
  
  return service.client
      .from('users')
      .stream(primaryKey: ['id'])
      .eq('id', user.id)
      .map((data) {
        if (data.isEmpty) return null;
        return UserModel.fromJson(data.first);
      });
});
