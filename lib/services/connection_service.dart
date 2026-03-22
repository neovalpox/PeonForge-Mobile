import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';

class ConnectionService {
  IOWebSocketChannel? _channel;
  final _stateController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  final _logController = StreamController<String>.broadcast();
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  String? _lanUrl;
  String? _tunnelUrl;
  String? _authToken;
  bool _connected = false;
  bool _tryingTunnel = false;
  bool _tunnelWorked = false;
  int _reconnectAttempts = 0;

  Stream<Map<String, dynamic>> get stateStream => _stateController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<String> get logStream => _logController.stream;
  bool get isConnected => _connected;

  void _log(String msg) {
    debugPrint('[WS] $msg');
    _logController.add(msg);
  }

  void connect(String address, {bool isTunnel = false, String? lanFallback, String? tunnelFallback, int port = 7777, String? authToken}) {
    _tryingTunnel = false;
    _tunnelWorked = false;
    if (authToken != null) _authToken = authToken;

    if (isTunnel) {
      _tunnelUrl = address;
      _lanUrl = lanFallback != null ? 'ws://$lanFallback:$port' : null;
    } else {
      _lanUrl = 'ws://$address:$port';
      _tunnelUrl = tunnelFallback;
    }
    _log('Config: LAN=$_lanUrl, Tunnel=$_tunnelUrl');
    _doConnect();
  }

  Future<void> _doConnect() async {
    _cleanup();

    String? url;
    if (!_tryingTunnel && _lanUrl != null) {
      url = _lanUrl;
    } else if (_tunnelUrl != null) {
      url = _tunnelUrl;
      _tryingTunnel = true;
    } else if (_lanUrl != null) {
      url = _lanUrl;
    }

    if (url == null) {
      _log('No URL to connect to');
      return;
    }

    // Append auth token to URL
    if (_authToken != null && _authToken!.isNotEmpty) {
      final sep = url.contains('?') ? '&' : '?';
      url = '$url${sep}token=$_authToken';
    }

    _log('Connecting to $url...');

    try {
      // Use raw WebSocket.connect with timeout
      final ws = await WebSocket.connect(url).timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException('Connection timeout'),
      );

      _channel = IOWebSocketChannel(ws);
      _log('Connected${_tryingTunnel ? " (tunnel)" : " (LAN)"}!');

      if (_tryingTunnel) _tunnelWorked = true;
      _connected = true;
      _reconnectAttempts = 0;
      _connectionController.add(true);

      _channel!.stream.listen(
        (data) {
          try {
            final msg = jsonDecode(data as String) as Map<String, dynamic>;
            _stateController.add(msg);
          } catch (_) {}
        },
        onDone: () {
          _log('Connection closed');
          _onDisconnected();
        },
        onError: (e) {
          _log('Stream error: $e');
          _onDisconnected();
        },
      );

      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        try { _channel?.sink.add(jsonEncode({'type': 'ping'})); } catch (_) {}
      });
    } catch (e) {
      _log('Failed: $e');
      _onDisconnected();
    }
  }

  void _onDisconnected() {
    if (_connected) {
      _connected = false;
      _connectionController.add(false);
      // Connection was active and dropped — reset tunnel preference to try both
      _tunnelWorked = false;
    }
    _pingTimer?.cancel();

    _reconnectAttempts++;

    // First try: LAN failed, try tunnel
    if (!_tryingTunnel && _tunnelUrl != null) {
      _tryingTunnel = true;
      _log('Trying tunnel fallback...');
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(const Duration(seconds: 1), _doConnect);
      return;
    }

    // Both failed — progressive backoff (3s, 5s, 10s, 15s, max 30s)
    _tryingTunnel = false;
    final delay = (_reconnectAttempts <= 2) ? 3 : (_reconnectAttempts <= 5) ? 10 : 30;

    // Every 3rd attempt, try fetching latest tunnel from peonforge.ch
    if (_reconnectAttempts % 3 == 0 && _forgeToken != null) {
      _log('Fetching tunnel from server...');
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(Duration(seconds: delay), () async {
        await _fetchTunnelFromForge();
        _doConnect();
      });
    } else {
      _log('Reconnecting in ${delay}s... (attempt $_reconnectAttempts)');
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(Duration(seconds: delay), _doConnect);
    }
  }

  String? _forgeToken;
  void setForgeToken(String? token) { _forgeToken = token; }

  Future<void> _fetchTunnelFromForge() async {
    if (_forgeToken == null || _forgeToken!.isEmpty) return;
    try {
      _log('Fetching tunnel URL from peonforge.ch...');
      final url = Uri.parse('https://peonforge.ch/api/connect?auth=$_forgeToken');
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
      final req = await client.getUrl(url);
      final res = await req.close().timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final body = await res.transform(const Utf8Decoder()).join();
        final data = jsonDecode(body) as Map<String, dynamic>;
        if (data['online'] == true && data['tunnel_url'] != null && (data['tunnel_url'] as String).isNotEmpty) {
          final newTunnel = (data['tunnel_url'] as String)
              .replaceFirst('https://', 'wss://')
              .replaceFirst('http://', 'ws://');
          _tunnelUrl = newTunnel;
          _tryingTunnel = true;
          _log('Got tunnel from server: $newTunnel');
        }
        if (data['lan_ip'] != null && (data['lan_ip'] as String).isNotEmpty) {
          _lanUrl = 'ws://${data['lan_ip']}:${data['lan_port'] ?? 7777}';
          _log('Got LAN from server: $_lanUrl');
        }
      }
      client.close(force: true);
    } catch (e) {
      _log('Forge fetch failed: $e');
    }
  }

  void _cleanup() {
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    try { _channel?.sink.close(); } catch (_) {}
    _channel = null;
  }

  void updateTunnel(String tunnelWsUrl) {
    _tunnelUrl = tunnelWsUrl;
    _log('Tunnel updated: $tunnelWsUrl');
  }

  void send(Map<String, dynamic> msg) {
    trySend(msg);
  }

  bool trySend(Map<String, dynamic> msg) {
    _log('send: ${msg['type']} connected=$_connected');
    if (_channel != null && _connected) {
      _channel!.sink.add(jsonEncode(msg));
      _log('sent OK');
      return true;
    } else {
      _log('DROPPED - not connected');
      return false;
    }
  }

  void setConfig({String? faction, double? volume, bool? soundEnabled, bool? watching}) {
    final msg = <String, dynamic>{'type': 'set-config'};
    if (faction != null) msg['faction'] = faction;
    if (volume != null) msg['volume'] = volume;
    if (soundEnabled != null) msg['soundEnabled'] = soundEnabled;
    if (watching != null) msg['watching'] = watching;
    send(msg);
  }

  void testNotification() => send({'type': 'test-notification'});

  void disconnect() {
    _cleanup();
    _tryingTunnel = false;
    _connected = false;
    _connectionController.add(false);
  }

  void dispose() {
    _cleanup();
    _stateController.close();
    _connectionController.close();
    _logController.close();
  }
}
