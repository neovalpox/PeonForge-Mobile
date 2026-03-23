import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:home_widget/home_widget.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../models/saved_pc.dart';
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

  List<SavedPC> savedPCs = [];
  String? activePcId;

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

    // Load saved PCs list
    final pcsJson = prefs.getString('saved_pcs');
    if (pcsJson != null) {
      try {
        final list = jsonDecode(pcsJson) as List;
        savedPCs = list.map((e) => SavedPC.fromJson(e as Map<String, dynamic>)).toList();
        // Sort by most recently connected
        savedPCs.sort((a, b) => b.lastConnected.compareTo(a.lastConnected));
      } catch (_) {
        savedPCs = [];
      }
    }

    // Migrate legacy single-PC prefs to saved_pcs list
    if (savedPCs.isEmpty) {
      final savedIp = prefs.getString('server_ip');
      final savedTunnel = prefs.getString('tunnel_url');
      final savedPort = prefs.getInt('server_port') ?? 7777;
      final savedAuth = prefs.getString('auth_token');
      final savedForge = prefs.getString('forge_token');
      if ((savedIp != null && savedIp.isNotEmpty) || (savedTunnel != null && savedTunnel.isNotEmpty)) {
        final pc = SavedPC(
          id: savedAuth ?? savedIp ?? savedTunnel ?? 'legacy',
          lanIp: savedIp,
          tunnelUrl: savedTunnel,
          port: savedPort,
          authToken: savedAuth,
          forgeToken: savedForge,
          lastConnected: DateTime.now().millisecondsSinceEpoch,
        );
        savedPCs.add(pc);
        await _persistPCs();
      }
    }

    // Auto-connect to most recently used PC
    if (savedPCs.isNotEmpty) {
      final pc = savedPCs.first;
      _connectToSavedPC(pc);
    }

    notifyListeners();
  }

  void _connectToSavedPC(SavedPC pc) {
    serverIp = pc.lanIp;
    tunnelUrl = pc.tunnelUrl;
    port = pc.port;
    authToken = pc.authToken;
    activePcId = pc.id;
    if (pc.forgeToken != null) _connection.setForgeToken(pc.forgeToken!);

    if (pc.lanIp != null && pc.lanIp!.isNotEmpty) {
      _connection.connect(pc.lanIp!, port: pc.port, tunnelFallback: pc.tunnelUrl, authToken: pc.authToken);
    } else if (pc.tunnelUrl != null && pc.tunnelUrl!.isNotEmpty) {
      _connection.connect(pc.tunnelUrl!, isTunnel: true, port: pc.port, authToken: pc.authToken);
    }
  }

  /// Connect to a previously saved PC
  void connectToPC(SavedPC pc) {
    // Update last connected
    pc.lastConnected = DateTime.now().millisecondsSinceEpoch;
    _persistPCs();
    _connectToSavedPC(pc);
    notifyListeners();
  }

  /// Delete a saved PC from the list
  Future<void> deletePC(String pcId) async {
    savedPCs.removeWhere((pc) => pc.id == pcId);
    await _persistPCs();
    // If we deleted the active PC, disconnect
    if (activePcId == pcId) {
      disconnect();
    }
    notifyListeners();
  }

  /// Get the currently active SavedPC
  SavedPC? get activePC => savedPCs.where((pc) => pc.id == activePcId).firstOrNull;

  /// Save/update a PC in the list and persist
  Future<void> _savePC(SavedPC pc) async {
    final idx = savedPCs.indexWhere((p) => p.id == pc.id);
    if (idx >= 0) {
      savedPCs[idx] = pc;
    } else {
      savedPCs.insert(0, pc);
    }
    await _persistPCs();
  }

  Future<void> _persistPCs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_pcs', jsonEncode(savedPCs.map((pc) => pc.toJson()).toList()));
  }

  void connectTo(String address, {bool isTunnel = false, String? tunnelFallback, int port = 7777, String? authToken}) async {
    this.port = port;
    if (authToken != null && authToken.isNotEmpty) {
      this.authToken = authToken;
    }

    if (isTunnel) {
      tunnelUrl = address;
      serverIp = null;
      _connection.connect(address, isTunnel: true, port: port, authToken: this.authToken);
    } else {
      serverIp = address;
      tunnelUrl = tunnelFallback;
      _connection.connect(address, port: port, tunnelFallback: tunnelFallback, authToken: this.authToken);
    }

    // Save/update this PC in the list
    final pcId = this.authToken ?? address;
    activePcId = pcId;
    final pc = SavedPC(
      id: pcId,
      lanIp: isTunnel ? null : address,
      tunnelUrl: isTunnel ? address : tunnelFallback,
      port: port,
      authToken: this.authToken,
      lastConnected: DateTime.now().millisecondsSinceEpoch,
    );
    // Preserve existing name if we already have this PC
    final existing = savedPCs.where((p) => p.id == pcId).firstOrNull;
    if (existing != null) pc.name = existing.name;
    await _savePC(pc);

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
    activePcId = null;
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
      }
      // Parse achievements
      if (msg['achievements'] != null) {
        achievements = (msg['achievements'] as List).map((a) => Achievement.fromJson(a)).toList();
      }
      // Parse characters catalog
      if (msg['characters'] != null) {
        characters = (msg['characters'] as List).map((c) => GameCharacter.fromJson(c)).toList();
      }
      // Update the active saved PC with hostname, tunnel, forge token
      if (activePcId != null) {
        final pc = savedPCs.where((p) => p.id == activePcId).firstOrNull;
        if (pc != null) {
          if (hostname.isNotEmpty) pc.name = hostname;
          if (msg['forgeToken'] != null) pc.forgeToken = msg['forgeToken'] as String;
          pc.lastConnected = DateTime.now().millisecondsSinceEpoch;
          _persistPCs();
        }
      }

      // Save tunnel URL for internet access
      if (msg['tunnelUrl'] != null) {
        final tUrl = msg['tunnelUrl'] as String;
        if (tUrl.isNotEmpty) {
          tunnelUrl = tUrl.replaceFirst('https://', 'wss://').replaceFirst('http://', 'ws://');
          // Update connection to use tunnel as fallback
          _connection.updateTunnel(tunnelUrl!);
          // Update saved PC
          final pc = savedPCs.where((p) => p.id == activePcId).firstOrNull;
          if (pc != null) { pc.tunnelUrl = tunnelUrl; _persistPCs(); }
        }
      }
      // Only save LAN IP if we already have one (connected via LAN initially)
      // Don't set it if we connected via tunnel only — it's not reachable
      if (msg['lanIp'] != null && serverIp != null) {
        final lip = msg['lanIp'] as String;
        if (lip.isNotEmpty && serverIp != lip) {
          serverIp = lip;
          // Update saved PC
          final pc = savedPCs.where((p) => p.id == activePcId).firstOrNull;
          if (pc != null) { pc.lanIp = lip; _persistPCs(); }
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
