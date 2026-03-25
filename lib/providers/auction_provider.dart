import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/auction_model.dart';
import 'supabase_provider.dart';

final auctionsStreamProvider = StreamProvider<List<AuctionModel>>((ref) {
  final service = ref.watch(supabaseServiceProvider);
  return service.streamAuctions();
});

final currentLiveAuctionProvider = Provider<AuctionModel?>((ref) {
  final auctionsAsync = ref.watch(auctionsStreamProvider);
  return auctionsAsync.maybeWhen(
    data: (auctions) {
      try {
        return auctions.firstWhere((a) => a.status == 'live');
      } catch (e) {
        return null;
      }
    },
    orElse: () => null,
  );
});
