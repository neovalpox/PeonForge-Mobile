import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/peonforge_provider.dart';
import '../theme/wc3_theme.dart';
import '../widgets/gold_card.dart';
import '../widgets/xp_bar.dart';
import '../models/models.dart';
import 'achievements_screen.dart';
import 'stats_screen.dart';

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
  static const _walkSpeeches = {
    'human': ["Bien marche sire !", "Les jambes sont solides !", "On avance bien !", "Pour la sante !"],
    'orc': ["Moe marche !", "Zug zug, bonne route !", "Moe fort jambes !", "Lok'tar, on avance !"],
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


  @override
  Widget build(BuildContext context) {
    return Consumer<PeonForgeProvider>(builder: (ctx, p, _) {
      final tama = p.tamagotchi;
      final avatarChar = p.avatar.isNotEmpty ? p.characters.where((c) => c.id == p.avatar).firstOrNull : null;
      final charName = avatarChar?.name ?? (p.config.faction == 'orc' ? 'Peon' : 'Paysan');
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
                            child: avatarChar != null
                                ? Image.network(avatarChar.iconUrl, fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Image.asset(
                                      p.config.faction == 'orc' ? 'assets/images/peon.gif' : 'assets/images/peasant.gif',
                                      fit: BoxFit.cover))
                                : Image.asset(
                                    p.config.faction == 'orc' ? 'assets/images/peon.gif' : 'assets/images/peasant.gif',
                                    fit: BoxFit.cover),
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

                // Step counter / happiness
                const SizedBox(height: 12),
                _buildStepCounter(p, tama),

                // Usage stats
                if (tama.usage.todayCost > 0 || tama.usage.weekCost > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _buildUsageWidget(tama.usage),
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

          // Quick links
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AchievementsScreen())),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: WC3Colors.goldDark),
                      foregroundColor: WC3Colors.goldLight,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.emoji_events, size: 16),
                    label: const Text('Hauts faits', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StatsScreen())),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: WC3Colors.goldDark),
                      foregroundColor: WC3Colors.goldLight,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.bar_chart, size: 16),
                    label: const Text('Stats', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),

          // PeonForge link
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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

  Widget _buildStepCounter(PeonForgeProvider p, TamagotchiState tama) {
    final steps = p.dailySteps > 0 ? p.dailySteps : tama.dailySteps;
    final progress = (steps / 10000).clamp(0.0, 1.0);
    final color = progress > 0.6 ? WC3Colors.green : progress > 0.3 ? WC3Colors.goldLight : WC3Colors.red;
    final isOrc = p.config.faction == 'orc';

    return GestureDetector(
      onTap: () {
        setState(() => _speechBubble = _randomSpeech(_walkSpeeches, p.config.faction));
        Future.delayed(const Duration(seconds: 3), () { if (mounted) setState(() => _speechBubble = null); });
      },
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.directions_walk, color: color, size: 16),
              const SizedBox(width: 6),
              Text('${_formatSteps(steps)} / 10 000 pas',
                style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${tama.happiness}%', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(width: 4),
              Text(isOrc ? 'content' : 'heureux', style: const TextStyle(color: WC3Colors.textDim, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: WC3Colors.bgSurface,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtTokens(int t) => t >= 1e9 ? '${(t / 1e9).toStringAsFixed(1)}G' : t >= 1e6 ? '${(t / 1e6).toStringAsFixed(1)}M' : t >= 1e3 ? '${(t / 1e3).round()}K' : '$t';

  Widget _buildUsageWidget(UsageStats usage) {
    Widget bar(String label, int tokens, double budget, Color color) {
      final pct = (tokens / budget).clamp(0.0, 1.0);
      final barColor = pct >= 0.8 ? WC3Colors.red : pct >= 0.5 ? WC3Colors.goldLight : color;
      return Row(
        children: [
          SizedBox(width: 14, child: Text(label, style: TextStyle(color: barColor, fontSize: 8, fontWeight: FontWeight.w700))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(value: pct, minHeight: 3, backgroundColor: WC3Colors.bgSurface, valueColor: AlwaysStoppedAnimation(barColor)),
            ),
          ),
          SizedBox(width: 32, child: Text(_fmtTokens(tokens), textAlign: TextAlign.right, style: TextStyle(color: barColor, fontSize: 8))),
        ],
      );
    }
    return Column(
      children: [
        Row(
          children: [
            const Icon(Icons.bolt, color: WC3Colors.blue, size: 14),
            const SizedBox(width: 4),
            Text('${_fmtTokens(usage.todayTokens)} tokens aujourd\'hui', style: const TextStyle(color: WC3Colors.blue, fontSize: 11, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('${_fmtTokens(usage.monthTokens)} ce mois', style: const TextStyle(color: WC3Colors.textDim, fontSize: 9)),
          ],
        ),
        const SizedBox(height: 4),
        bar('J', usage.todayTokens, 500e6, WC3Colors.blue),
        const SizedBox(height: 2),
        bar('S', usage.weekTokens, 2e9, WC3Colors.purple),
        const SizedBox(height: 2),
        bar('M', usage.monthTokens, 5e9, WC3Colors.goldLight),
      ],
    );
  }

  String _formatSteps(int steps) {
    if (steps >= 1000) {
      return '${(steps / 1000).toStringAsFixed(1).replaceAll('.0', '')} k';
    }
    return '$steps';
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
    final idle = s.isIdle;

    return Opacity(
      opacity: idle ? 0.5 : 1.0,
      child: Container(
        width: 140, margin: const EdgeInsets.symmetric(horizontal: 4), padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: idle ? WC3Colors.bgCard : WC3Colors.bgCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: idle ? color.withValues(alpha: 0.15) : color.withValues(alpha: 0.4)),
          boxShadow: idle ? null : [BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 8)],
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: idle ? color.withValues(alpha: 0.3) : color, width: 1.5),
                boxShadow: idle ? null : [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 6)],
              ),
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
                    Container(width: 5, height: 5, decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: idle ? WC3Colors.goldDark.withValues(alpha: 0.4) : WC3Colors.green.withValues(alpha: 0.8),
                    )),
                    const SizedBox(width: 4),
                    Text(idle ? '$m:$ss (idle)' : '$m:$ss', style: const TextStyle(color: WC3Colors.textDim, fontSize: 10)),
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
