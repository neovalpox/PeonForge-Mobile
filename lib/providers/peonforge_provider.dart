import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:home_widget/home_widget.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/connection_service.dart';

class PeonForgeProvider extends ChangeNotifier {
  final ConnectionService _connection = ConnectionService();
  StreamSubscription? _stateSub;
  StreamSubscription? _connSub;
  Timer? _stepPollTimer;
  int dailySteps = 0;

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
  List<Achievement> achievements = [];
  List<DailyStats> dailyStats = [];
  bool loadingStats = false;
  List<Duel> duels = [];
  bool loadingDuels = false;
  List<Guild> guilds = [];
  Guild? myGuild;
  bool loadingGuilds = false;

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
    if (!Platform.isAndroid) return;

    final health = Health();

    // Configure Health Connect
    Health().configure();

    // Request Health Connect authorization for steps
    try {
      final types = [HealthDataType.STEPS];
      final permissions = [HealthDataAccess.READ];
      final authorized = await health.requestAuthorization(types, permissions: permissions);
      debugPrint('[PeonForge] Health Connect authorized: $authorized');
      if (!authorized) {
        debugPrint('[PeonForge] Health Connect permission denied');
        return;
      }
    } catch (e) {
      debugPrint('[PeonForge] Health Connect auth error: $e');
      return;
    }

    // Fetch today's steps immediately
    await _fetchSteps(health);

    // Poll every 60s to keep step count updated (Health Connect has the data even when app is closed)
    _stepPollTimer = Timer.periodic(const Duration(seconds: 60), (_) => _fetchSteps(health));
  }

  Future<void> _fetchSteps(Health health) async {
    try {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      final steps = await health.getTotalStepsInInterval(midnight, now);
      debugPrint('[PeonForge] Health Connect steps today: $steps');
      if (steps != null && steps != dailySteps) {
        dailySteps = steps;
        _sendSteps();
      }
    } catch (e) {
      debugPrint('[PeonForge] Health Connect fetch error: $e');
    }
  }

  void _sendSteps() {
    _connection.send({'type': 'set-steps', 'steps': dailySteps});
    notifyListeners();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIp = prefs.getString('server_ip');
    final savedTunnel = prefs.getString('tunnel_url');
    final savedPort = prefs.getInt('server_port') ?? 7777;
    authToken = prefs.getString('auth_token');
    // Load forge token for remote reconnect
    final savedForge = prefs.getString('forge_token');
    if (savedForge != null) _connection.setForgeToken(savedForge);

    if (savedIp != null && savedIp.isNotEmpty) {
      serverIp = savedIp;
      tunnelUrl = savedTunnel;
      port = savedPort;
      _connection.connect(savedIp, port: savedPort, tunnelFallback: savedTunnel, authToken: authToken);
      notifyListeners();
    } else if (savedTunnel != null && savedTunnel.isNotEmpty) {
      tunnelUrl = savedTunnel;
      port = savedPort;
      _connection.connect(savedTunnel, isTunnel: true, port: savedPort, authToken: authToken);
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
    } else if (tunnelUrl != null) {
      _connection.connect(tunnelUrl!, isTunnel: true, port: port, authToken: authToken);
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
      // Save forge token for remote reconnect via peonforge.ch
      if (msg['forgeToken'] != null) {
        _connection.setForgeToken(msg['forgeToken'] as String);
        _saveForgeToken(msg['forgeToken'] as String);
      }
      // Parse achievements
      if (msg['achievements'] != null) {
        achievements = (msg['achievements'] as List).map((a) => Achievement.fromJson(a)).toList();
      }
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
      _updateHomeWidget();
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
      if (msg['tamagotchi'] != null) _updateHomeWidget();
      return;
    }

    if (type == 'image-saved') {
      lastImageSavedPath = msg['path'] as String?;
      notifyListeners();
      return;
    }

    // Username/avatar/register updates
    if (msg['username'] != null) username = msg['username'] as String;
    if (msg['avatar'] != null) avatar = msg['avatar'] as String;
    if (msg['registerError'] != null) lastRegisterError = msg['registerError'] as String;
    if (msg['registered'] == true) lastRegisterError = null;

    // Tamagotchi interaction response (from feed/pet/train — no 'type' field)
    final hadTamagotchiUpdate = msg['tamagotchi'] != null;
    if (hadTamagotchiUpdate) tamagotchi = TamagotchiState.fromJson(msg['tamagotchi']);
    if (msg['interaction'] != null) lastInteraction = msg['interaction'] as Map<String, dynamic>;
    if (msg['sessions'] != null) sessions = (msg['sessions'] as List).map((s) => Session.fromJson(s)).toList();
    if (msg['mood'] != null) mood = msg['mood'];
    notifyListeners();
    if (hadTamagotchiUpdate) _updateHomeWidget();
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

  String? lastImageSavedPath;

  Future<bool> uploadImage({ImageSource source = ImageSource.gallery}) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 85, maxWidth: 1920);
      if (picked == null) return false;
      final bytes = await picked.readAsBytes();
      final base64Data = base64Encode(bytes);
      final filename = picked.name;
      _connection.send({'type': 'upload-image', 'data': base64Data, 'filename': filename});
      debugPrint('[PeonForge] Image uploaded: ${bytes.length} bytes');
      return true;
    } catch (e) {
      debugPrint('[PeonForge] uploadImage error: $e');
      return false;
    }
  }
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

  Future<void> _saveForgeToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('forge_token', token);
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

  Future<void> fetchStats({int days = 30}) async {
    if (username.isEmpty) return;
    loadingStats = true;
    notifyListeners();

    try {
      final url = Uri.parse('https://peonforge.ch/api/player/$username/stats?days=$days');
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
      final req = await client.getUrl(url);
      final res = await req.close().timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        final data = jsonDecode(body);
        if (data['days'] != null) {
          dailyStats = (data['days'] as List).map((d) => DailyStats.fromJson(d)).toList();
        }
      }
      client.close(force: true);
    } catch (e) {
      debugPrint('[PeonForge] fetchStats error: $e');
    }

    loadingStats = false;
    notifyListeners();
  }

  // ---- Duels ----

  Future<void> fetchDuels() async {
    if (username.isEmpty) return;
    loadingDuels = true;
    notifyListeners();

    try {
      final url = Uri.parse('https://peonforge.ch/api/duels?player=$username');
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
      final req = await client.getUrl(url);
      final res = await req.close().timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        final data = jsonDecode(body);
        if (data is List) {
          duels = data.map((d) => Duel.fromJson(d)).toList();
        } else if (data['duels'] != null) {
          duels = (data['duels'] as List).map((d) => Duel.fromJson(d)).toList();
        }
      }
      client.close(force: true);
    } catch (e) {
      debugPrint('[PeonForge] fetchDuels error: $e');
    }

    loadingDuels = false;
    notifyListeners();
  }

  void createDuel(String challenged, String stat) {
    _connection.send({'type': 'create-duel', 'challenged': challenged, 'stat': stat});
  }

  // ---- Guilds ----

  Future<void> fetchGuilds() async {
    loadingGuilds = true;
    notifyListeners();

    try {
      final url = Uri.parse('https://peonforge.ch/api/guilds');
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
      final req = await client.getUrl(url);
      final res = await req.close().timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        final data = jsonDecode(body);
        if (data is List) {
          guilds = data.map((g) => Guild.fromJson(g)).toList();
        } else if (data['guilds'] != null) {
          guilds = (data['guilds'] as List).map((g) => Guild.fromJson(g)).toList();
        }
        // Find my guild
        if (username.isNotEmpty) {
          myGuild = guilds.where((g) => g.members.any((m) => m.username == username)).firstOrNull;
        }
      }
      client.close(force: true);
    } catch (e) {
      debugPrint('[PeonForge] fetchGuilds error: $e');
    }

    loadingGuilds = false;
    notifyListeners();
  }

  void createGuild(String name, String tag, String faction) {
    _connection.send({'type': 'create-guild', 'name': name, 'tag': tag, 'faction': faction});
  }

  void joinGuild(String tag) {
    _connection.send({'type': 'join-guild', 'tag': tag});
  }

  void leaveGuild() {
    _connection.send({'type': 'leave-guild'});
    myGuild = null;
    notifyListeners();
  }

  // ---- Leaderboard (for duel target picking) ----

  List<Map<String, dynamic>> leaderboard = [];
  bool loadingLeaderboard = false;

  Future<void> fetchLeaderboard() async {
    loadingLeaderboard = true;
    notifyListeners();

    try {
      final url = Uri.parse('https://peonforge.ch/api/leaderboard');
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
      final req = await client.getUrl(url);
      final res = await req.close().timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        final data = jsonDecode(body);
        if (data is List) {
          leaderboard = data.cast<Map<String, dynamic>>();
        } else if (data['players'] != null) {
          leaderboard = (data['players'] as List).cast<Map<String, dynamic>>();
        }
      }
      client.close(force: true);
    } catch (e) {
      debugPrint('[PeonForge] fetchLeaderboard error: $e');
    }

    loadingLeaderboard = false;
    notifyListeners();
  }

  /// Save tamagotchi data to SharedPreferences and trigger Android home widget update.
  Future<void> _updateHomeWidget() async {
    try {
      await HomeWidget.saveWidgetData<int>('level', tamagotchi.level);
      await HomeWidget.saveWidgetData<int>('xp_progress', (tamagotchi.xpProgress * 100).round());
      await HomeWidget.saveWidgetData<int>('tasks_today', tamagotchi.tasksCompleted);
      await HomeWidget.saveWidgetData<int>('steps_today', tamagotchi.dailySteps);
      await HomeWidget.saveWidgetData<int>('happiness', tamagotchi.happiness);
      await HomeWidget.saveWidgetData<String>('faction', config.faction);
      await HomeWidget.updateWidget(
        androidName: 'PeonForgeWidgetProvider',
      );
    } catch (e) {
      debugPrint('[PeonForge] HomeWidget update error: $e');
    }
  }

  @override
  void dispose() {
    _stepPollTimer?.cancel();
    _stateSub?.cancel();
    _connSub?.cancel();
    _connection.dispose();
    super.dispose();
  }
}
