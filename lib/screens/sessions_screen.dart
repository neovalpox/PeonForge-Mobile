import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/peonforge_provider.dart';
import '../theme/wc3_theme.dart';
import '../widgets/gold_card.dart';
import '../models/models.dart';
import 'terminal_screen.dart';
import 'characters_screen.dart';

class SessionsScreen extends StatelessWidget {
  const SessionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PeonForgeProvider>(builder: (ctx, p, _) {
      if (p.sessions.isEmpty) {
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Aucun agent actif', style: TextStyle(color: WC3Colors.goldText, fontSize: 16)),
              SizedBox(height: 8),
              Text('Lance Claude Code pour voir tes sessions ici', style: TextStyle(color: WC3Colors.textDim, fontSize: 13)),
            ],
          ),
        );
      }

      return Column(
        children: [
          // Debug banner
          if (p.lastFocusDebug != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(p.lastFocusDebug!, style: const TextStyle(color: Colors.green, fontSize: 10, fontFamily: 'monospace')),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 20),
              itemCount: p.sessions.length,
              itemBuilder: (ctx, i) => _SessionCard(session: p.sessions[i], provider: p),
            ),
          ),
        ],
      );
    });
  }
}

class _SessionCard extends StatelessWidget {
  final Session session;
  final PeonForgeProvider provider;

  const _SessionCard({required this.session, required this.provider});

  @override
  Widget build(BuildContext context) {
    final color = session.character.parsedColor;
    final elapsed = session.elapsed;
    final m = elapsed.inMinutes;
    final ss = (elapsed.inSeconds % 60).toString().padLeft(2, '0');

    return GoldCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: portrait + project + timer
          Row(
            children: [
              GestureDetector(
                onTap: () => _showCharacterPicker(context),
                child: Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color, width: 2),
                    boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8)],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: session.character.isLocal
                        ? Image.asset(session.character.assetPath, fit: BoxFit.cover)
                        : Image.network(session.character.iconUrl, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Image.asset(session.character.assetPath, fit: BoxFit.cover)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(session.project, style: const TextStyle(color: WC3Colors.goldLight, fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: color.withValues(alpha: 0.3)),
                          ),
                          child: Text(session.character.name, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 8),
                        Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: WC3Colors.green.withValues(alpha: 0.8))),
                        const SizedBox(width: 4),
                        Text('$m:$ss', style: const TextStyle(color: WC3Colors.textMid, fontSize: 12, fontFeatures: [FontFeature.tabularFigures()])),
                        const SizedBox(width: 8),
                        Text('${session.eventCount} events', style: const TextStyle(color: WC3Colors.textDim, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
              // View terminal button
              IconButton(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => TerminalScreen(sessionId: session.id, project: session.project),
                  ));
                },
                icon: const Icon(Icons.terminal, color: WC3Colors.goldDark, size: 20),
                tooltip: 'Voir terminal',
              ),
            ],
          ),

          // Action row
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _chipButton('Voir terminal', WC3Colors.blue, () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => TerminalScreen(sessionId: session.id, project: session.project),
                ));
              }),
              _chipButton('Changer avatar', color, () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => CharactersScreen(sessionId: session.id),
                ));
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chipButton(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ),
    );
  }

  void _showCharacterPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: WC3Colors.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Choisir l\'avatar pour ${session.project}', style: const TextStyle(color: WC3Colors.goldLight, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _factionOption(context, 'peasant', 'Paysan', 'assets/images/peasant.gif', WC3Colors.humanColor)),
                const SizedBox(width: 12),
                Expanded(child: _factionOption(context, 'peon', 'Peon', 'assets/images/peon.gif', WC3Colors.orcColor)),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _factionOption(BuildContext context, String id, String name, String gif, Color color) {
    final isActive = session.character.id == id;
    return GestureDetector(
      onTap: () {
        provider.setSessionCharacter(session.id, id);
        Navigator.pop(context);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isActive ? color : Colors.white10, width: isActive ? 2 : 1),
          color: isActive ? color.withValues(alpha: 0.1) : Colors.transparent,
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(gif, width: 56, height: 56, fit: BoxFit.cover),
            ),
            const SizedBox(height: 8),
            Text(name, style: TextStyle(color: isActive ? color : WC3Colors.textMid, fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
