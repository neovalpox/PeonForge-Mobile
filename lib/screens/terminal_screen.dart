import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/peonforge_provider.dart';
import '../theme/wc3_theme.dart';

class TerminalScreen extends StatefulWidget {
  final String? sessionId;
  final String? project;

  const TerminalScreen({super.key, this.sessionId, this.project});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  Uint8List? _frameData;
  bool _streaming = false;
  int _fps = 0;
  int _frameCount = 0;
  Timer? _fpsTimer;
  StreamSubscription? _streamSub;
  final _inputController = TextEditingController();
  final _inputFocus = FocusNode();
  bool _showInput = false;

  bool _started = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _fpsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() { _fps = _frameCount; _frameCount = 0; });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _startStream();
    }
  }

  @override
  void dispose() {
    // Restore normal UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _stopStream();
    _fpsTimer?.cancel();
    _streamSub?.cancel();
    _inputController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _startStream() {
    final provider = context.read<PeonForgeProvider>();

    // Get phone screen size to resize terminal window accordingly
    final screenSize = MediaQuery.of(context).size;
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;

    void sendStart() {
      if (!mounted) return;
      final sent = provider.connection.trySend({
        'type': 'start-terminal-stream',
        if (widget.sessionId != null) 'sessionId': widget.sessionId,
        if (widget.project != null) 'project': widget.project,
        'phoneWidth': (screenSize.width * pixelRatio).round(),
        'phoneHeight': (screenSize.height * pixelRatio).round(),
      });
      if (!sent) {
        Future.delayed(const Duration(seconds: 2), sendStart);
      }
    }
    sendStart();

    _streamSub = provider.connection.stateStream.listen((msg) {
      if (msg['type'] == 'terminal-frame' && msg['data'] != null) {
        try {
          final bytes = base64Decode(msg['data'] as String);
          if (mounted) {
            setState(() {
              _frameData = bytes;
              _streaming = true;
              _frameCount++;
            });
          }
        } catch (_) {}
      }
    });
    setState(() => _streaming = true);
  }

  void _stopStream() {
    context.read<PeonForgeProvider>().connection.trySend({'type': 'stop-terminal-stream'});
    _streamSub?.cancel();
    _streamSub = null;
  }

  void _sendKeys(String keys) {
    final provider = context.read<PeonForgeProvider>();
    // Try WS first
    final sent = provider.connection.trySend({
      'type': 'send-keys',
      'keys': keys,
    });
    // Also try HTTP as fallback
    if (!sent) {
      provider.sendKeysViaHttp(keys);
    }
    debugPrint('[Terminal] sendKeys "$keys" -> ws=$sent');
  }

  void _sendInput() {
    final text = _inputController.text;
    if (text.isEmpty) return;
    // SendKeys syntax: text followed by Enter
    _sendKeys('$text{ENTER}');
    _inputController.clear();
  }

  void _sendSpecialKey(String key) {
    _sendKeys(key);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: WC3Colors.bgCard,
        title: Row(
          children: [
            Expanded(
              child: Text(widget.project ?? 'Terminal', style: const TextStyle(color: WC3Colors.goldLight, fontSize: 15), overflow: TextOverflow.ellipsis),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _streaming && _fps > 0 ? WC3Colors.green.withValues(alpha: 0.1) : WC3Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _streaming && _fps > 0 ? WC3Colors.green.withValues(alpha: 0.3) : WC3Colors.red.withValues(alpha: 0.3)),
              ),
              child: Text(
                _streaming && _fps > 0 ? 'LIVE $_fps FPS' : 'Connexion...',
                style: TextStyle(color: _streaming && _fps > 0 ? WC3Colors.green : WC3Colors.red, fontSize: 10, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: WC3Colors.goldLight),
          onPressed: () { _stopStream(); Navigator.of(context).pop(); },
        ),
        actions: [
          IconButton(
            icon: Icon(_showInput ? Icons.keyboard_hide : Icons.keyboard, color: WC3Colors.goldLight),
            onPressed: () => setState(() { _showInput = !_showInput; if (_showInput) _inputFocus.requestFocus(); }),
          ),
        ],
      ),
      body: Column(
        children: [
          // Terminal view
          Expanded(
            child: _frameData != null
                ? InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 10.0,
                    child: Center(
                      child: Image.memory(
                        _frameData!,
                        gaplessPlayback: true,
                        fit: BoxFit.contain,
                      ),
                    ),
                  )
                : const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: WC3Colors.goldLight),
                        SizedBox(height: 16),
                        Text('Connexion au terminal...', style: TextStyle(color: WC3Colors.textDim)),
                      ],
                    ),
                  ),
          ),

          // Tab switcher + Quick action buttons
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: WC3Colors.bgCard,
            child: Column(
              children: [
                // Tab navigation row
                Row(
                  children: [
                    _quickBtn('< Onglet', () => _sendSpecialKey('^+{TAB}')),
                    _quickBtn('Onglet >', () => _sendSpecialKey('^{TAB}')),
                    _quickBtn('Ctrl+C', () => _sendSpecialKey('^c')),
                    _quickBtn('Enter', () => _sendSpecialKey('{ENTER}')),
                  ],
                ),
                const SizedBox(height: 4),
                // Standard keys row
                Row(
                  children: [
                    _quickBtn('y', () => _sendSpecialKey('y')),
                    _quickBtn('n', () => _sendSpecialKey('n')),
                    _quickBtn('Up', () => _sendSpecialKey('{UP}')),
                    _quickBtn('Down', () => _sendSpecialKey('{DOWN}')),
                    _quickBtn('Tab', () => _sendSpecialKey('{TAB}')),
                    _quickBtn('Esc', () => _sendSpecialKey('{ESC}')),
                  ],
                ),
              ],
            ),
          ),

          // Text input
          if (_showInput)
            Container(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              color: WC3Colors.bgCard,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      focusNode: _inputFocus,
                      style: const TextStyle(color: WC3Colors.goldText, fontSize: 14, fontFamily: 'monospace'),
                      decoration: const InputDecoration(
                        hintText: 'Commande...',
                        hintStyle: TextStyle(color: WC3Colors.textDim),
                        border: OutlineInputBorder(borderSide: BorderSide(color: WC3Colors.goldDark)),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: WC3Colors.goldDark)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: WC3Colors.goldLight)),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _sendInput(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sendInput,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: WC3Colors.goldDark,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.send, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _quickBtn(String label, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: WC3Colors.bgSurface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: WC3Colors.goldDark.withValues(alpha: 0.3)),
          ),
          child: Text(label, textAlign: TextAlign.center, style: const TextStyle(color: WC3Colors.goldText, fontSize: 10, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
