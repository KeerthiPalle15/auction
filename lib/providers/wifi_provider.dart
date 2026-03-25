import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/wifi_scoring_service.dart';
import '../models/match_event_model.dart';

final wifiServiceProvider = Provider<WifiScoringService>((ref) {
  final service = WifiScoringService();
  ref.onDispose(() => service.dispose());
  return service;
});

final wifiStatusProvider = StreamProvider((ref) {
  final service = ref.watch(wifiServiceProvider);
  return service.statusStream;
});
