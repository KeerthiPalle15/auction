import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/match_event_model.dart';

enum ConnectionStatus { disconnected, connecting, connected, paired, error }

class WifiScoringService {
  static const String serverUrl = 'ws://192.168.137.66:41561/ws';
  static const String pairingCode = '103625';

  WebSocketChannel? _channel;
  final StreamController<ConnectionStatus> _statusController =
      StreamController<ConnectionStatus>.broadcast();
  ConnectionStatus _status = ConnectionStatus.disconnected;

  Stream<ConnectionStatus> get statusStream => _statusController.stream;
  ConnectionStatus get status => _status;

  Future<void> connect() async {
    try {
      _setStatus(ConnectionStatus.connecting);

      // Check network
      final connectivityResult = await Connectivity().checkConnectivity();
      if (!connectivityResult.contains(ConnectivityResult.wifi)) {
        throw Exception('WiFi connection required');
      }

      _channel = WebSocketChannel.connect(Uri.parse(serverUrl));

      _channel!.stream.listen(
        (message) {
          final data = jsonDecode(message);
          if (data['type'] == 'paired') {
            _setStatus(ConnectionStatus.paired);
          } else if (data['type'] == 'error') {
            _setStatus(ConnectionStatus.error);
          }
        },
        onError: (error) {
          _setStatus(ConnectionStatus.error);
        },
        onDone: () {
          _setStatus(ConnectionStatus.disconnected);
        },
      );

      // Send pairing request
      await sendPairingRequest();

      _setStatus(ConnectionStatus.connected);
    } catch (e) {
      _setStatus(ConnectionStatus.error);
      rethrow;
    }
  }

  Future<void> sendPairingRequest() async {
    if (_channel == null) return;
    _channel!.sink.add(jsonEncode({'type': 'pair', 'code': pairingCode}));
  }

  Future<void> sendEvent(MatchEventModel event) async {
    if (_status != ConnectionStatus.paired || _channel == null) return;
    _channel!.sink.add(
      jsonEncode({
        'type': 'event',
        'matchId': event.matchId,
        'data': event.toJson(),
      }),
    );
  }

  void _setStatus(ConnectionStatus newStatus) {
    _status = newStatus;
    _statusController.add(newStatus);
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
    _setStatus(ConnectionStatus.disconnected);
  }

  void dispose() {
    disconnect();
    _statusController.close();
  }
}
