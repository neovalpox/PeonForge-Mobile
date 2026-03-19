import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/peonforge_provider.dart';
import '../theme/wc3_theme.dart';
import '../widgets/gold_card.dart';
import 'qr_scan_screen.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final _ipController = TextEditingController();
  bool _scanning = false;
  final List<_FoundServer> _found = [];

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  Future<void> _startScan() async {
    setState(() { _scanning = true; _found.clear(); });

    // Get local IP to determine subnet
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (addr.isLoopback) continue;
          final parts = addr.address.split('.');
          if (parts.length != 4) continue;
          final subnet = '${parts[0]}.${parts[1]}.${parts[2]}';

          // Scan subnet in batches
          for (int batch = 1; batch <= 254; batch += 30) {
            final futures = <Future>[];
            for (int i = batch; i < batch + 30 && i <= 254; i++) {
              futures.add(_probe('$subnet.$i'));
            }
            await Future.wait(futures);
          }
        }
      }
    } catch (_) {}

    if (mounted) setState(() => _scanning = false);
  }

  Future<void> _probe(String ip) async {
    try {
      final client = HttpClient()..connectionTimeout = const Duration(milliseconds: 400);
      final req = await client.getUrl(Uri.parse('http://$ip:7777/discover'));
      final res = await req.close().timeout(const Duration(milliseconds: 600));
      final body = await res.transform(utf8.decoder).join();
      final data = jsonDecode(body);
      if (data['app'] == 'peonforge' && mounted) {
        setState(() => _found.add(_FoundServer(ip, data['hostname'] ?? ip)));
      }
      client.close(force: true);
    } catch (_) {}
  }

  void _connect(String ip) {
    context.read<PeonForgeProvider>().connectTo(ip);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 40),
              Image.asset('assets/images/peasant.gif', width: 80, height: 80),
              const SizedBox(height: 16),
              Text('PeonForge', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              const Text('Connecte-toi a ton PC', style: TextStyle(color: WC3Colors.textMid, fontSize: 13)),
              const SizedBox(height: 24),

              // QR Scan button
              SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(builder: (_) => const QrScanScreen()),
                      );
                      // If QR connected, the provider state will update automatically
                    },
                    icon: const Icon(Icons.qr_code_scanner, size: 22),
                    label: const Text('Scanner le QR du PC', style: TextStyle(fontSize: 15)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: WC3Colors.goldDark,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              const Row(
                children: [
                  Expanded(child: Divider(color: WC3Colors.textDim)),
                  Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('ou', style: TextStyle(color: WC3Colors.textDim, fontSize: 12))),
                  Expanded(child: Divider(color: WC3Colors.textDim)),
                ],
              ),
              const SizedBox(height: 16),

              // Manual IP
              GoldCard(
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ipController,
                        style: const TextStyle(color: WC3Colors.goldText),
                        decoration: const InputDecoration(
                          hintText: '192.168.1.x',
                          hintStyle: TextStyle(color: WC3Colors.textDim),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        final ip = _ipController.text.trim();
                        if (ip.isNotEmpty) _connect(ip);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: WC3Colors.goldDark,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Connecter'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 20),
                    child: Text('Serveurs trouves', style: TextStyle(color: WC3Colors.textMid, fontSize: 12, letterSpacing: 1)),
                  ),
                  const SizedBox(width: 8),
                  if (_scanning) const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: WC3Colors.goldLight)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: WC3Colors.goldLight, size: 20),
                    onPressed: _scanning ? null : _startScan,
                  ),
                ],
              ),

              Expanded(
                child: _found.isEmpty
                  ? Center(
                      child: Text(
                        _scanning ? 'Scan du reseau...' : 'Aucun serveur trouve.\nVerifie que PeonForge est lance sur ton PC.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: WC3Colors.textDim, fontSize: 13),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _found.length,
                      itemBuilder: (ctx, i) {
                        final s = _found[i];
                        return GoldCard(
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.computer, color: WC3Colors.goldLight),
                            title: Text(s.hostname, style: const TextStyle(color: WC3Colors.goldLight, fontWeight: FontWeight.w600)),
                            subtitle: Text(s.ip, style: const TextStyle(color: WC3Colors.textMid, fontSize: 12)),
                            trailing: const Icon(Icons.arrow_forward_ios, color: WC3Colors.goldDark, size: 16),
                            onTap: () => _connect(s.ip),
                          ),
                        );
                      },
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FoundServer {
  final String ip, hostname;
  _FoundServer(this.ip, this.hostname);
}
