import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
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

class _AppShellState extends State<AppShell> {
  int _tab = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _requestNotificationPermission();
  }

  Future<void> _requestNotificationPermission() async {
    final android = _notifs.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      await android.requestNotificationsPermission();
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
      // This opens the Android "battery optimization" dialog for the app
      final android = _notifs.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      // We can't directly request battery exemption from Flutter without a plugin,
      // but the wake lock + user setting "unrestricted" will do the job
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    final provider = context.read<PeonForgeProvider>();
    _globalProvider = provider;
    provider.onTaskComplete = _onTaskComplete;
    provider.onPermissionRequest = _onPermissionRequest;
  }

  void _onTaskComplete(AppEvent event) {
    final payload = jsonEncode({'sessionId': event.sessionId, 'project': event.project});
    final provider = context.read<PeonForgeProvider>();
    final isOrc = provider.config.faction == 'orc';

    _notifs.show(
      event.timestamp ~/ 1000,
      isOrc ? 'Zug zug !' : 'Travail termine !',
      'Claude a fini sur ${event.project}',
      AndroidNotificationDetails(
        'peonforge_tasks', 'Taches',
        channelDescription: 'Notifications de taches terminees',
        importance: Importance.high,
        priority: Priority.high,
        sound: RawResourceAndroidNotificationSound(isOrc ? 'peon_complete' : 'task_complete'),
        playSound: true,
      ).toNotificationDetails(),
      payload: payload,
    );
  }

  void _onPermissionRequest(AppEvent event) {
    final payload = jsonEncode({'sessionId': event.sessionId, 'project': event.project});
    final provider = context.read<PeonForgeProvider>();
    final isOrc = provider.config.faction == 'orc';

    _notifs.show(
      event.timestamp ~/ 1000 + 1,
      isOrc ? 'Chef ? Quoi faire ?' : 'Permission requise',
      '${event.project} attend une reponse',
      AndroidNotificationDetails(
        'peonforge_perms', 'Permissions',
        channelDescription: 'Demandes de permission',
        importance: Importance.max,
        priority: Priority.max,
        sound: RawResourceAndroidNotificationSound(isOrc ? 'peon_question' : 'permission_required'),
        playSound: true,
      ).toNotificationDetails(),
      payload: payload,
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
            Image.asset(
              provider.config.faction == 'orc' ? 'assets/images/peon.gif' : 'assets/images/peasant.gif',
              width: 28, height: 28,
            ),
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
