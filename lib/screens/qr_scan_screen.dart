import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../providers/peonforge_provider.dart';
import '../theme/wc3_theme.dart';

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  bool _scanned = false;
  String? _status;
  StreamSubscription? _connSub;
  StreamSubscription? _logSub;
  final List<String> _logs = [];

  @override
  void dispose() {
    _connSub?.cancel();
    _logSub?.cancel();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    setState(() => _scanned = true);

    try {
      final data = jsonDecode(barcode.rawValue!) as Map<String, dynamic>;
      final tunnelUrl = data['tunnelUrl'] as String?;
      final lanIp = data['lanIp'] as String?;
      final port = data['port'] as int? ?? 7777;

      final provider = context.read<PeonForgeProvider>();

      // Listen for logs
      _logSub = provider.connection.logStream.listen((log) {
        if (mounted) setState(() => _logs.add(log));
      });

      // Listen for connection success
      _connSub = provider.connectionStream.listen((connected) {
        if (connected && mounted) {
          setState(() => _status = 'Connecte !');
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) Navigator.of(context).pop(true);
          });
        }
      });

      // Connect via LAN first, tunnel as fallback
      if (lanIp != null && lanIp.isNotEmpty) {
        final tUrl = (tunnelUrl != null && tunnelUrl.isNotEmpty)
            ? tunnelUrl.replaceFirst('https://', 'wss://').replaceFirst('http://', 'ws://')
            : null;
        provider.connectTo(lanIp, port: port, tunnelFallback: tUrl);
        setState(() => _status = 'Connexion a $lanIp...');
      } else if (tunnelUrl != null && tunnelUrl.isNotEmpty) {
        final wsUrl = tunnelUrl.replaceFirst('https://', 'wss://').replaceFirst('http://', 'ws://');
        provider.connectTo(wsUrl, isTunnel: true, port: port);
        setState(() => _status = 'Connexion tunnel...');
      } else {
        setState(() { _status = 'QR invalide'; _scanned = false; });
        return;
      }

      // Timeout: go back after 8s even if not connected
      Future.delayed(const Duration(seconds: 8), () {
        if (mounted) Navigator.of(context).pop(false);
      });
    } catch (e) {
      setState(() { _status = 'Erreur: $e'; _scanned = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WC3Colors.bgDark,
      appBar: AppBar(
        title: const Text('Scanner le QR', style: TextStyle(color: WC3Colors.goldLight)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: WC3Colors.goldLight),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _scanned
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 40, height: 40, child: CircularProgressIndicator(color: WC3Colors.goldLight)),
                      const SizedBox(height: 16),
                      Text(_status ?? 'Connexion...', style: const TextStyle(color: WC3Colors.goldText, fontSize: 16)),
                      const SizedBox(height: 16),
                      // Debug logs
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: ListView(
                          shrinkWrap: true,
                          children: _logs.map((l) => Text(l, style: const TextStyle(color: Colors.green, fontSize: 10, fontFamily: 'monospace'))).toList(),
                        ),
                      ),
                    ],
                  ),
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: MobileScanner(onDetect: _onDetect),
                  ),
                ),
          ),
          if (!_scanned)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Scanne le QR affiche sur le PC\n(Tray > Connecter mobile)',
                textAlign: TextAlign.center,
                style: TextStyle(color: WC3Colors.textMid, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }
}
