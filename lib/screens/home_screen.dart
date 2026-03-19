import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/peonforge_provider.dart';
import '../theme/wc3_theme.dart';
import '../widgets/gold_card.dart';
import '../widgets/xp_bar.dart';
import '../models/models.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _petAnim;
  String? _speechBubble;

  static const _petSpeeches = {
    'human': ["Hehe, ca chatouille !", "Oui milord ?", "A vos ordres !", "Merci sire !", "Hm ?"],
    'orc': ["Hehe !", "Zug zug !", "Moe content !", "Dabu !", "Grr..."],
  };
  static const _feedSpeeches = {
    'human': ["Miam ! Merci sire !", "Du pain ! Excellent !", "J'avais faim !", "Ca fait du bien !"],
    'orc': ["Moe mange !", "Miam miam !", "Viande ! Moe content !", "Zug zug, merci chef !"],
  };
  static const _trainSpeeches = {
    'human': ["En garde !", "Je vais devenir fort !", "Entrainement !", "Pour l'Alliance !"],
    'orc': ["Moe s'entraine !", "Lok'tar ogar !", "Plus fort !", "Pour la Horde !"],
  };
  static const _idleSpeeches = {
    'human': ["J'attends vos ordres.", "Du travail ?", "Pret !", "Oui milord ?"],
    'orc': ["Zug zug.", "Dabu ?", "Moe pret.", "Quoi faire ?"],
  };

  @override
  void initState() {
    super.initState();
    _petAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
  }

  @override
  void dispose() {
    _petAnim.dispose();
    super.dispose();
  }

  String _randomSpeech(Map<String, List<String>> speeches, String faction) {
    final list = speeches[faction] ?? speeches['human']!;
    return list[Random().nextInt(list.length)];
  }

  void _onPet(PeonForgeProvider p) {
    p.petPeon();
    _petAnim.forward().then((_) => _petAnim.reverse());
    setState(() => _speechBubble = _randomSpeech(_petSpeeches, p.config.faction));
    Future.delayed(const Duration(seconds: 3), () { if (mounted) setState(() => _speechBubble = null); });
  }

  void _onFeed(PeonForgeProvider p) {
    if (p.tamagotchi.gold < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pas assez d\'or (10 requis)'), backgroundColor: WC3Colors.red),
      );
      return;
    }
    p.feedPeon();
    setState(() => _speechBubble = _randomSpeech(_feedSpeeches, p.config.faction));
    Future.delayed(const Duration(seconds: 3), () { if (mounted) setState(() => _speechBubble = null); });
  }

  void _onTrain(PeonForgeProvider p) {
    if (p.tamagotchi.gold < 25) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pas assez d\'or (25 requis)'), backgroundColor: WC3Colors.red),
      );
      return;
    }
    if (p.tamagotchi.xpBoost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deja en entrainement !'), backgroundColor: WC3Colors.goldDark),
      );
      return;
    }
    p.trainPeon();
    setState(() => _speechBubble = _randomSpeech(_trainSpeeches, p.config.faction));
    Future.delayed(const Duration(seconds: 3), () { if (mounted) setState(() => _speechBubble = null); });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PeonForgeProvider>(builder: (ctx, p, _) {
      final tama = p.tamagotchi;
      final charGif = p.config.faction == 'orc' ? 'assets/images/peon.gif' : 'assets/images/peasant.gif';
      final charName = p.config.faction == 'orc' ? 'Peon' : 'Paysan';
      final speech = _speechBubble ?? _randomSpeech(_idleSpeeches, p.config.faction);

      return ListView(
        padding: const EdgeInsets.only(bottom: 20),
        children: [
          // Character + Stats
          GoldCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    // Portrait — tappable to pet
                    GestureDetector(
                      onTap: () => _onPet(p),
                      child: AnimatedBuilder(
                        animation: _petAnim,
                        builder: (ctx, child) => Transform.scale(
                          scale: 1 + _petAnim.value * 0.15,
                          child: child,
                        ),
                        child: Container(
                          width: 72, height: 72,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: WC3Colors.goldDark, width: 2),
                            boxShadow: [BoxShadow(color: _moodColor(p.mood).withValues(alpha: 0.3), blurRadius: 12)],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.asset(charGif, fit: BoxFit.cover),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Stats
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(charName, style: const TextStyle(color: WC3Colors.goldLight, fontSize: 16, fontWeight: FontWeight.w700)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: WC3Colors.goldDark.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: WC3Colors.goldDark.withValues(alpha: 0.4)),
                                ),
                                child: Text('Niv. ${tama.level}', style: const TextStyle(color: WC3Colors.goldLight, fontSize: 11, fontWeight: FontWeight.w600)),
                              ),
                              if (tama.xpBoost) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: WC3Colors.green.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text('+20% XP', style: TextStyle(color: WC3Colors.green, fontSize: 9, fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          XpBar(progress: tama.xpProgress, label: '${tama.xpInLevel} / ${tama.xpForLevel} XP'),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text('${tama.gold} Or', style: const TextStyle(color: Color(0xFFFFD700), fontSize: 13, fontWeight: FontWeight.w600)),
                              const SizedBox(width: 12),
                              Text('${tama.tasksCompleted} taches', style: const TextStyle(color: WC3Colors.textMid, fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Happiness bar
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Bonheur', style: TextStyle(color: WC3Colors.textDim, fontSize: 11)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: tama.happiness / 100,
                          minHeight: 6,
                          backgroundColor: WC3Colors.bgSurface,
                          valueColor: AlwaysStoppedAnimation(
                            tama.happiness > 60 ? WC3Colors.green :
                            tama.happiness > 30 ? WC3Colors.goldLight : WC3Colors.red,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${tama.happiness}%', style: const TextStyle(color: WC3Colors.textMid, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),

          // Speech bubble
          GoldCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: _moodColor(p.mood))),
                const SizedBox(width: 10),
                Expanded(child: Text('"$speech"', style: const TextStyle(color: WC3Colors.goldText, fontSize: 13, fontStyle: FontStyle.italic))),
              ],
            ),
          ),

          // Interaction buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(child: _actionButton('Caresser', 'Gratuit', WC3Colors.blue, () => _onPet(p))),
                const SizedBox(width: 8),
                Expanded(child: _actionButton('Nourrir', '10 Or', WC3Colors.green, () => _onFeed(p))),
                const SizedBox(width: 8),
                Expanded(child: _actionButton('Entrainer', '25 Or', WC3Colors.purple, () => _onTrain(p))),
              ],
            ),
          ),

          // Active sessions
          if (p.sessions.isNotEmpty) ...[
            _sectionTitle('Sessions actives (${p.sessions.length})'),
            SizedBox(
              height: 72,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: p.sessions.length,
                itemBuilder: (ctx, i) => _sessionChip(p.sessions[i], p),
              ),
            ),
          ],

          // Activity feed
          _sectionTitle('Activite'),
          if (p.recentEvents.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('Aucune activite recente', textAlign: TextAlign.center, style: TextStyle(color: WC3Colors.textDim, fontSize: 13, fontStyle: FontStyle.italic)),
            )
          else
            ...p.recentEvents.take(10).map((e) => _eventTile(e, p)),

          // PeonForge link
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: OutlinedButton(
              onPressed: () => launchUrl(Uri.parse('https://peonforge.ch'), mode: LaunchMode.externalApplication),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: WC3Colors.goldDark),
                foregroundColor: WC3Colors.goldLight,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Voir le classement sur peonforge.ch'),
            ),
          ),
        ],
      );
    });
  }

  Widget _actionButton(String label, String cost, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(cost, style: TextStyle(color: color.withValues(alpha: 0.6), fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Text(text.toUpperCase(), style: const TextStyle(color: WC3Colors.textDim, fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
    );
  }

  Widget _sessionChip(Session s, PeonForgeProvider p) {
    final elapsed = s.elapsed;
    final m = elapsed.inMinutes;
    final ss = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    final color = s.character.parsedColor;

    return GestureDetector(
      onTap: () => p.focusTerminal(sessionId: s.id, project: s.project),
      child: Container(
        width: 140, margin: const EdgeInsets.symmetric(horizontal: 4), padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: WC3Colors.bgCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: 0.3))),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: color, width: 1.5)),
              child: ClipRRect(borderRadius: BorderRadius.circular(5),
                child: s.character.isLocal
                    ? Image.asset(s.character.assetPath, fit: BoxFit.cover)
                    : Image.network(s.character.iconUrl, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Image.asset(s.character.assetPath, fit: BoxFit.cover))),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(s.project, style: const TextStyle(color: WC3Colors.goldText, fontSize: 11, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(children: [
                    Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: WC3Colors.green.withValues(alpha: 0.8))),
                    const SizedBox(width: 4),
                    Text('$m:$ss', style: const TextStyle(color: WC3Colors.textDim, fontSize: 10)),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _eventTile(AppEvent e, PeonForgeProvider p) {
    final meta = e.eventMeta;
    final time = DateTime.fromMillisecondsSinceEpoch(e.timestamp);
    final timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';

    return GestureDetector(
      onTap: () => p.focusTerminal(sessionId: e.sessionId, project: e.project),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        child: Row(
          children: [
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(color: meta.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6), border: Border.all(color: meta.color.withValues(alpha: 0.3))),
              alignment: Alignment.center,
              child: Text(meta.icon, style: const TextStyle(fontSize: 11)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(meta.label, style: const TextStyle(color: WC3Colors.goldText, fontSize: 12)),
                Text('$timeStr  ·  ${e.project}', style: const TextStyle(color: WC3Colors.textDim, fontSize: 10)),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Color _moodColor(String mood) {
    switch (mood) {
      case 'working': return WC3Colors.green;
      case 'happy': return WC3Colors.goldLight;
      case 'error': return WC3Colors.red;
      case 'sleeping': return WC3Colors.textDim;
      default: return WC3Colors.blue;
    }
  }
}
