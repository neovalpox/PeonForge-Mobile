import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pedometer_2/pedometer_2.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/connection_service.dart';

final Pedometer _pedometer = Pedometer();

class PeonForgeProvider extends ChangeNotifier {
  final ConnectionService _connection = ConnectionService();
  StreamSubscription? _stateSub;
  StreamSubscription? _connSub;
  StreamSubscription<int>? _stepSub;
  int dailySteps = 0;
  String _stepsDate = '';
  int _stepBaseline = 0; // pedometer total at midnight reset

  bool connected = false;
  String? serverIp;
  String? tunnelUrl;
  String? authToken;
  int port = 7777;
  String hostname = '';
  PeonForgeConfig config = PeonForgeConfig();
  TamagotchiState tamagotchi = TamagotchiState();
  String mood = 'idle';
  List<Session> sessions = [];
  List<AppEvent> recentEvents = [];
  List<GameCharacter> characters = [];
  String username = '';
  String avatar = ''; // character pack id for site profile

  Function(AppEvent)? onTaskComplete;
  Function(AppEvent)? onPermissionRequest;

  ConnectionService get connection => _connection;
  Stream<bool> get connectionStream => _connection.connectionStream;

  PeonForgeProvider() {
    _connSub = _connection.connectionStream.listen((c) {
      connected = c;
      notifyListeners();
    });
    _stateSub = _connection.stateStream.listen(_handleMessage);
    _loadSaved();
    _initPedometer();
  }

  void _initPedometer() async {
    _loadStepState();

    // Request ACTIVITY_RECOGNITION permission (required on Android 10+)
    if (Platform.isAndroid) {
      final status = await Permission.activityRecognition.request();
      debugPrint('[PeonForge] Activity recognition permission: $status');
      if (!status.isGranted) {
        debugPrint('[PeonForge] Pedometer permission denied');
        return;
      }
    }

    _stepSub = _pedometer.stepCountStream().listen(_onStepCount, onError: (e) {
      debugPrint('[PeonForge] Pedometer error: $e');
    });
  }

  Future<void> _loadStepState() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final savedDate = prefs.getString('steps_date') ?? '';
    if (savedDate == today) {
      dailySteps = prefs.getInt('daily_steps') ?? 0;
      _stepBaseline = prefs.getInt('step_baseline') ?? 0;
    } else {
      // New day — reset
      dailySteps = 0;
      _stepBaseline = 0;
      _stepsDate = today;
    }
    _stepsDate = today;
  }

  void _onStepCount(int totalSteps) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);

    if (_stepsDate != today) {
      // Day changed — reset baseline to current total
      _stepBaseline = totalSteps;
      dailySteps = 0;
      _stepsDate = today;
    }

    if (_stepBaseline == 0) {
      // First reading: set baseline so daily starts from 0
      _stepBaseline = totalSteps - dailySteps;
    }

    dailySteps = totalSteps - _stepBaseline;
    if (dailySteps < 0) dailySteps = 0;

    // Persist locally
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('daily_steps', dailySteps);
    await prefs.setInt('step_baseline', _stepBaseline);
    await prefs.setString('steps_date', today);

    // Send to server
    _connection.send({'type': 'set-steps', 'steps': dailySteps});
    notifyListeners();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIp = prefs.getString('server_ip');
    final savedTunnel = prefs.getString('tunnel_url');
    final savedPort = prefs.getInt('server_port') ?? 7777;
    authToken = prefs.getString('auth_token');

    if (savedIp != null && savedIp.isNotEmpty) {
      serverIp = savedIp;
      tunnelUrl = savedTunnel;
      port = savedPort;
      _connection.connect(savedIp, port: savedPort, tunnelFallback: savedTunnel, authToken: authToken);
      notifyListeners();
    }
  }

  void connectTo(String address, {bool isTunnel = false, String? tunnelFallback, int port = 7777, String? authToken}) async {
    final prefs = await SharedPreferences.getInstance();
    this.port = port;
    if (authToken != null && authToken.isNotEmpty) {
      this.authToken = authToken;
      await prefs.setString('auth_token', authToken);
    }

    if (isTunnel) {
      tunnelUrl = address;
      await prefs.setString('tunnel_url', address);
      await prefs.setInt('server_port', port);
      _connection.connect(address, isTunnel: true, port: port, authToken: this.authToken);
    } else {
      serverIp = address;
      tunnelUrl = tunnelFallback;
      await prefs.setString('server_ip', address);
      if (tunnelFallback != null) await prefs.setString('tunnel_url', tunnelFallback);
      await prefs.setInt('server_port', port);
      _connection.connect(address, port: port, tunnelFallback: tunnelFallback, authToken: this.authToken);
    }
    notifyListeners();
  }

  void reconnect() {
    if (serverIp != null) {
      _connection.connect(serverIp!, port: port, tunnelFallback: tunnelUrl, authToken: authToken);
    }
  }

  void disconnect() async {
    _connection.disconnect();
    connected = false;
    serverIp = null;
    tunnelUrl = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('server_ip');
    await prefs.remove('tunnel_url');
    notifyListeners();
  }

  void _handleMessage(Map<String, dynamic> msg) {
    final type = msg['type'] as String? ?? '';

    if (type == 'full-state') {
      if (msg['config'] != null) config = PeonForgeConfig.fromJson(msg['config']);
      if (msg['tamagotchi'] != null) tamagotchi = TamagotchiState.fromJson(msg['tamagotchi']);
      mood = msg['mood'] ?? 'idle';
      hostname = msg['hostname'] ?? '';
      if (msg['sessions'] != null) {
        sessions = (msg['sessions'] as List).map((s) => Session.fromJson(s)).toList();
      }
      if (msg['recentEvents'] != null) {
        recentEvents = (msg['recentEvents'] as List).map((e) => AppEvent.fromJson(e)).toList();
      }
      if (msg['username'] != null) username = msg['username'] as String;
      if (msg['avatar'] != null) avatar = msg['avatar'] as String;
      // Parse characters catalog
      if (msg['characters'] != null) {
        characters = (msg['characters'] as List).map((c) => GameCharacter.fromJson(c)).toList();
      }
      // Save tunnel URL for internet access
      if (msg['tunnelUrl'] != null) {
        final tUrl = msg['tunnelUrl'] as String;
        if (tUrl.isNotEmpty) {
          tunnelUrl = tUrl.replaceFirst('https://', 'wss://').replaceFirst('http://', 'ws://');
          _saveTunnelUrl(tunnelUrl!);
          // Update connection to use tunnel as fallback
          _connection.updateTunnel(tunnelUrl!);
        }
      }
      // Only save LAN IP if we already have one (connected via LAN initially)
      // Don't set it if we connected via tunnel only — it's not reachable
      if (msg['lanIp'] != null && serverIp != null) {
        final lip = msg['lanIp'] as String;
        if (lip.isNotEmpty && serverIp != lip) {
          serverIp = lip;
          _saveLanIp(lip);
        }
      }
      notifyListeners();
      return;
    }

    if (type == 'update') {
      if (msg['tamagotchi'] != null) tamagotchi = TamagotchiState.fromJson(msg['tamagotchi']);
      if (msg['mood'] != null) mood = msg['mood'];
      if (msg['sessions'] != null) {
        sessions = (msg['sessions'] as List).map((s) => Session.fromJson(s)).toList();
      }
      if (msg['faction'] != null || msg['side'] != null) {
        config = PeonForgeConfig(
          faction: msg['faction'] ?? config.faction,
          side: msg['side'] ?? config.side,
          volume: config.volume,
          soundEnabled: config.soundEnabled, watching: config.watching,
        );
      }

      if (msg['event'] != null) {
        final event = AppEvent.fromJson(msg['event']);
        recentEvents.insert(0, event);
        if (recentEvents.length > 30) recentEvents.length = 30;

        if (event.type == 'Stop') onTaskComplete?.call(event);
        if (event.type == 'PermissionRequest') onPermissionRequest?.call(event);
      }

      notifyListeners();
      return;
    }

    // Username/avatar/register updates
    if (msg['username'] != null) username = msg['username'] as String;
    if (msg['avatar'] != null) avatar = msg['avatar'] as String;
    if (msg['registerError'] != null) lastRegisterError = msg['registerError'] as String;
    if (msg['registered'] == true) lastRegisterError = null;

    // Tamagotchi interaction response (from feed/pet/train — no 'type' field)
    if (msg['tamagotchi'] != null) tamagotchi = TamagotchiState.fromJson(msg['tamagotchi']);
    if (msg['interaction'] != null) lastInteraction = msg['interaction'] as Map<String, dynamic>;
    if (msg['sessions'] != null) sessions = (msg['sessions'] as List).map((s) => Session.fromJson(s)).toList();
    if (msg['mood'] != null) mood = msg['mood'];
    notifyListeners();
  }

  Map<String, dynamic>? lastInteraction;

  void setFaction(String f) => _connection.setConfig(faction: f);
  void setShowCompanion(bool v) {
    config = PeonForgeConfig(faction: config.faction, side: config.side, volume: config.volume,
      soundEnabled: config.soundEnabled, watching: config.watching, showCompanion: v, showNotifications: config.showNotifications);
    notifyListeners();
    _connection.send({'type': 'set-config', 'showCompanion': v});
  }
  void setShowNotifications(bool v) {
    config = PeonForgeConfig(faction: config.faction, side: config.side, volume: config.volume,
      soundEnabled: config.soundEnabled, watching: config.watching, showCompanion: config.showCompanion, showNotifications: v);
    notifyListeners();
    _connection.send({'type': 'set-config', 'showNotifications': v});
  }
  void setVolume(double v) {
    config = PeonForgeConfig(faction: config.faction, side: config.side, volume: v,
      soundEnabled: config.soundEnabled, watching: config.watching, showCompanion: config.showCompanion, showNotifications: config.showNotifications);
    notifyListeners();
    _connection.setConfig(volume: v);
  }
  void setSoundEnabled(bool v) {
    config = PeonForgeConfig(faction: config.faction, side: config.side, volume: config.volume,
      soundEnabled: v, watching: config.watching, showCompanion: config.showCompanion, showNotifications: config.showNotifications);
    notifyListeners();
    _connection.setConfig(soundEnabled: v);
  }
  void setWatching(bool v) {
    config = PeonForgeConfig(faction: config.faction, side: config.side, volume: config.volume,
      soundEnabled: config.soundEnabled, watching: v, showCompanion: config.showCompanion, showNotifications: config.showNotifications);
    notifyListeners();
    _connection.setConfig(watching: v);
  }
  void setSide(String s) {
    config = PeonForgeConfig(faction: s == 'horde' ? 'orc' : 'human', side: s, volume: config.volume,
      soundEnabled: config.soundEnabled, watching: config.watching, showCompanion: config.showCompanion, showNotifications: config.showNotifications);
    notifyListeners();
    _connection.send({'type': 'set-config', 'side': s});
  }
  void testNotification() => _connection.testNotification();

  String? lastRegisterError;

  void setUsername(String name) => _connection.send({'type': 'set-username', 'username': name});
  void setAvatar(String avatarId) {
    avatar = avatarId;
    notifyListeners();
    _connection.send({'type': 'set-avatar', 'avatar': avatarId});
  }
  void petPeon() => _connection.send({'type': 'interact', 'action': 'pet'});
  void setSessionCharacter(String sessionId, String characterId) => _connection.send({
    'type': 'set-session-character', 'sessionId': sessionId, 'characterId': characterId,
  });

  Future<void> sendKeysViaHttp(String keys) async {
    final ip = serverIp;
    if (ip == null) return;
    try {
      final tokenParam = authToken != null ? '?token=$authToken' : '';
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
      final url = Uri.parse('http://$ip:$port/send-keys$tokenParam');
      final req = await client.postUrl(url);
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({'keys': keys}));
      await req.close().timeout(const Duration(seconds: 3));
      client.close(force: true);
    } catch (_) {}
  }

  String? lastFocusDebug;

  Future<void> _saveTunnelUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tunnel_url', url);
  }

  Future<void> _saveLanIp(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_ip', ip);
  }

  void focusTerminal({String? sessionId, String? project}) {
    lastFocusDebug = 'WS connected=${_connection.isConnected}, IP=$serverIp:$port';
    debugPrint('[PeonForge] focusTerminal: $lastFocusDebug');
    notifyListeners();

    // Try WebSocket
    _connection.send({
      'type': 'focus-terminal',
      if (sessionId != null) 'sessionId': sessionId,
      if (project != null) 'project': project,
    });

    // Always try HTTP too
    _focusViaHttp(sessionId: sessionId, project: project);
  }

  Future<void> _focusViaHttp({String? sessionId, String? project}) async {
    // Try LAN first, then tunnel
    final urls = <String>[];
    final tokenParam = authToken != null ? '?token=$authToken' : '';
    if (serverIp != null) urls.add('http://$serverIp:$port/focus$tokenParam');
    if (tunnelUrl != null) {
      final httpTunnel = tunnelUrl!.replaceFirst('wss://', 'https://').replaceFirst('ws://', 'http://');
      urls.add('$httpTunnel/focus');
    }

    if (urls.isEmpty) {
      lastFocusDebug = 'HTTP SKIP: no URL';
      notifyListeners();
      return;
    }

    for (final targetUrl in urls) {
      try {
        debugPrint('[PeonForge] HTTP focus: $targetUrl');
        final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
        final url = Uri.parse(targetUrl);
        final req = await client.postUrl(url);
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode({'sessionId': sessionId, 'project': project}));
        final res = await req.close().timeout(const Duration(seconds: 5));
        final body = await res.drain();
        lastFocusDebug = 'OK via $targetUrl';
        debugPrint('[PeonForge] $lastFocusDebug');
        client.close(force: true);
        notifyListeners();
        return; // success, stop trying
      } catch (e) {
        debugPrint('[PeonForge] HTTP fail $targetUrl: $e');
        continue; // try next URL
      }
    }
    lastFocusDebug = 'All HTTP failed';
    notifyListeners();
  }

  @override
  void dispose() {
    _stepSub?.cancel();
    _stateSub?.cancel();
    _connSub?.cancel();
    _connection.dispose();
    super.dispose();
  }
}
