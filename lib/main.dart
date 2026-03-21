import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'theme/wc3_theme.dart';
import 'i18n.dart';
import 'providers/peonforge_provider.dart';
import 'screens/connect_screen.dart';
import 'screens/home_screen.dart';
import 'screens/sessions_screen.dart';
import 'screens/settings_screen.dart';
import 'models/models.dart';

final FlutterLocalNotificationsPlugin _notifs = FlutterLocalNotificationsPlugin();
PeonForgeProvider? _globalProvider;

extension _AndroidToNotif on AndroidNotificationDetails {
  NotificationDetails toNotificationDetails() => NotificationDetails(android: this);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  I18n.init();

  await _notifs.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ),
    onDidReceiveNotificationResponse: _onNotificationTap,
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => PeonForgeProvider(),
      child: const PeonForgeApp(),
    ),
  );
}

void _onNotificationTap(NotificationResponse response) {
  if (response.payload != null && _globalProvider != null) {
    try {
      final data = jsonDecode(response.payload!) as Map<String, dynamic>;
      _globalProvider!.focusTerminal(sessionId: data['sessionId'], project: data['project']);
    } catch (_) {
      _globalProvider?.focusTerminal();
    }
  }
}

class PeonForgeApp extends StatelessWidget {
  const PeonForgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PeonForge',
      theme: wc3Theme(),
      debugShowCheckedModeBanner: false,
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _tab = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _requestNotificationPermission();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Reconnect WebSocket when app comes back to foreground
    if (state == AppLifecycleState.resumed) {
      final provider = context.read<PeonForgeProvider>();
      if (!provider.connected && (provider.serverIp != null || provider.tunnelUrl != null)) {
        provider.reconnect();
      }
    }
  }

  Future<void> _requestNotificationPermission() async {
    final android = _notifs.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      debugPrint('[PeonForge] Notification permission: $granted');
    }
    // Keep screen/CPU wake to maintain WebSocket alive in background
    WakelockPlus.enable();
    // Ask Android to not optimize battery for this app
    if (Platform.isAndroid) {
      _requestBatteryExemption();
    }
  }

  Future<void> _requestBatteryExemption() async {
    try {
      // Open Android battery optimization settings for this app
      // This prompts the user to disable battery optimization
      const channel = MethodChannel('com.peonforge/battery');
      await channel.invokeMethod('requestBatteryExemption');
    } catch (_) {
      // Fallback: just rely on wakelock
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final provider = context.read<PeonForgeProvider>();
    _globalProvider = provider;
    provider.onTaskComplete = _onTaskComplete;
    provider.onPermissionRequest = _onPermissionRequest;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _onTaskComplete(AppEvent event) async {
    final payload = jsonEncode({'sessionId': event.sessionId, 'project': event.project});
    final provider = context.read<PeonForgeProvider>();

    final charId = event.characterId;
    debugPrint('[PeonForge] _onTaskComplete: charId=$charId project=${event.project} type=${event.type} avatar=${provider.avatar}');

    // Resolve character — use event's character, fallback to avatar, fallback to faction
    GameCharacter? char;
    if (charId != null && charId.isNotEmpty) {
      char = provider.characters.where((c) => c.id == charId).firstOrNull;
    }
    char ??= provider.avatar.isNotEmpty
        ? provider.characters.where((c) => c.id == provider.avatar).firstOrNull
        : null;
    final isOrc = char != null ? char.side == 'horde' : provider.config.side == 'horde';

    AndroidBitmap<Object>? largeIcon;
    final iconId = char?.id ?? charId;
    if (iconId != null && iconId.isNotEmpty) {
      largeIcon = await _getCharacterIcon(iconId);
      debugPrint('[PeonForge] Notification icon: $iconId, loaded=${largeIcon != null}');
    }

    final title = isOrc ? 'Zug zug !' : 'Travail termine !';

    try {
      await _notifs.show(
        event.timestamp ~/ 1000,
        title,
        event.project,
        AndroidNotificationDetails(
          'peonforge_tasks', 'Taches',
          channelDescription: 'Notifications de taches terminees',
          importance: Importance.high,
          priority: Priority.high,
          largeIcon: largeIcon,
          playSound: false, // we play sound ourselves
        ).toNotificationDetails(),
        payload: payload,
      );
    } catch (e) {
      debugPrint('[PeonForge] Notification error: $e');
    }

    // Play character voice line
    _playVoiceLine(event);
  }

  Future<void> _onPermissionRequest(AppEvent event) async {
    final payload = jsonEncode({'sessionId': event.sessionId, 'project': event.project});
    final provider = context.read<PeonForgeProvider>();
    debugPrint('[PeonForge] _onPermissionRequest: project=${event.project}');

    final charId = event.characterId;
    GameCharacter? char;
    if (charId != null && charId.isNotEmpty) {
      char = provider.characters.where((c) => c.id == charId).firstOrNull;
    }
    char ??= provider.avatar.isNotEmpty
        ? provider.characters.where((c) => c.id == provider.avatar).firstOrNull
        : null;
    final isOrc = char != null ? char.side == 'horde' : provider.config.side == 'horde';

    AndroidBitmap<Object>? largeIcon;
    final iconId = char?.id ?? charId;
    if (iconId != null && iconId.isNotEmpty) {
      largeIcon = await _getCharacterIcon(iconId);
    }

    final title = isOrc ? 'Chef ? Quoi faire ?' : 'Permission requise !';

    try {
      await _notifs.show(
        event.timestamp ~/ 1000 + 1,
        title,
        event.project,
        AndroidNotificationDetails(
          'peonforge_perms', 'Permissions',
          channelDescription: 'Demandes de permission',
          importance: Importance.max,
          priority: Priority.max,
          largeIcon: largeIcon,
          playSound: false,
        ).toNotificationDetails(),
        payload: payload,
      );
    } catch (e) {
      debugPrint('[PeonForge] Permission notification error: $e');
    }

    _playVoiceLine(event);
  }

  final AudioPlayer _audioPlayer = AudioPlayer();

  Future<void> _playVoiceLine(AppEvent event) async {
    if (event.soundPack == null || event.soundFile == null) return;
    final provider = context.read<PeonForgeProvider>();
    final ip = provider.serverIp;
    final tunnel = provider.tunnelUrl;
    final token = provider.authToken;

    // Build sound URL — try LAN first, then tunnel
    final urls = <String>[];
    final tokenParam = token != null ? '?token=$token' : '';
    if (ip != null) urls.add('http://$ip:${provider.port}/sound/${event.soundPack}/${event.soundFile}$tokenParam');
    if (tunnel != null) {
      final httpTunnel = tunnel.replaceFirst('wss://', 'https://').replaceFirst('ws://', 'http://');
      urls.add('$httpTunnel/sound/${event.soundPack}/${event.soundFile}');
    }

    for (final url in urls) {
      try {
        debugPrint('[PeonForge] Playing sound: $url');
        await _audioPlayer.setVolume(provider.config.volume);
        await _audioPlayer.play(UrlSource(url));
        return;
      } catch (e) {
        debugPrint('[PeonForge] Sound play error: $e');
      }
    }
  }

  Future<AndroidBitmap<Object>?> _getCharacterIcon(String charId) async {
    try {
      // Check local cache first
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/notif_icon_$charId.png');
      if (await file.exists() && await file.length() > 100) {
        debugPrint('[PeonForge] Icon from cache: ${file.path}');
        return FilePathAndroidBitmap(file.path);
      }

      final url = 'https://peonforge.ch/assets/icons/$charId.png';
      debugPrint('[PeonForge] Downloading icon: $url');
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
      final req = await client.getUrl(Uri.parse(url));
      final res = await req.close().timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final bytes = await consolidateHttpClientResponseBytes(res);
        await file.writeAsBytes(bytes);
        debugPrint('[PeonForge] Icon saved: ${file.path} (${bytes.length} bytes)');
        client.close(force: true);
        return FilePathAndroidBitmap(file.path);
      }
      debugPrint('[PeonForge] Icon download failed: ${res.statusCode}');
      client.close(force: true);
    } catch (_) {}
    return null;
  }

  Widget _buildAppBarAvatar(PeonForgeProvider provider) {
    final fallback = Image.asset(
      provider.config.faction == 'orc' ? 'assets/images/peon.gif' : 'assets/images/peasant.gif',
      width: 28, height: 28,
    );
    if (provider.avatar.isEmpty) return fallback;
    final url = 'https://peonforge.ch/assets/icons/${provider.avatar}.png';
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.network(url, width: 28, height: 28, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PeonForgeProvider>();

    // Show connect screen if no server configured or if disconnected with no hope
    if (provider.serverIp == null && provider.tunnelUrl == null) {
      return const ConnectScreen();
    }

    // Show reconnect banner if configured but not connected
    if (!provider.connected) {
      return Scaffold(
        backgroundColor: WC3Colors.bgDark,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images/peasant.gif', width: 64, height: 64),
              const SizedBox(height: 16),
              const Text('Connexion en cours...', style: TextStyle(color: WC3Colors.goldText, fontSize: 16)),
              const SizedBox(height: 8),
              Text('${provider.serverIp ?? ""}', style: const TextStyle(color: WC3Colors.textDim, fontSize: 12)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => provider.disconnect(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: WC3Colors.goldDark,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Changer de serveur'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            _buildAppBarAvatar(provider),
            const SizedBox(width: 10),
            Text('PeonForge', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: provider.connected
                    ? WC3Colors.green.withValues(alpha: 0.1)
                    : WC3Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: provider.connected
                      ? WC3Colors.green.withValues(alpha: 0.3)
                      : WC3Colors.red.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 6, color: provider.connected ? WC3Colors.green : WC3Colors.red),
                  const SizedBox(width: 4),
                  Text(
                    provider.connected ? 'Niv. ${provider.tamagotchi.level}' : 'Hors ligne',
                    style: TextStyle(
                      color: provider.connected ? WC3Colors.green : WC3Colors.red,
                      fontSize: 11, fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: IndexedStack(
        index: _tab,
        children: const [
          HomeScreen(),
          SessionsScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.home), label: I18n.t('home')),
          BottomNavigationBarItem(icon: const Icon(Icons.terminal), label: I18n.t('agents')),
          BottomNavigationBarItem(icon: const Icon(Icons.settings), label: I18n.t('settings')),
        ],
      ),
    );
  }
}
