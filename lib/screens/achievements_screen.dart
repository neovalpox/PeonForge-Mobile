import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/peonforge_provider.dart';
import '../theme/wc3_theme.dart';
import '../models/models.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PeonForgeProvider>(builder: (ctx, p, _) {
      final unlocked = p.achievements.where((a) => a.unlocked).toList();
      final locked = p.achievements.where((a) => !a.unlocked).toList();
      final total = p.achievements.length;
      final unlockedCount = unlocked.length;

      return Scaffold(
        backgroundColor: WC3Colors.bgDark,
        appBar: AppBar(
          backgroundColor: WC3Colors.bgCard,
          title: const Text('Hauts faits', style: TextStyle(color: WC3Colors.goldLight, fontSize: 16)),
          leading: IconButton(icon: const Icon(Icons.arrow_back, color: WC3Colors.goldLight), onPressed: () => Navigator.pop(context)),
        ),
        body: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            // Progress summary
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: WC3Colors.bgCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: WC3Colors.goldDark, width: 1.5),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.emoji_events, color: WC3Colors.goldLight, size: 20),
                      const SizedBox(width: 8),
                      Text('$unlockedCount / $total', style: const TextStyle(color: WC3Colors.goldLight, fontSize: 18, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: total > 0 ? unlockedCount / total : 0,
                      minHeight: 8,
                      backgroundColor: WC3Colors.bgSurface,
                      valueColor: const AlwaysStoppedAnimation(WC3Colors.goldLight),
                    ),
                  ),
                ],
              ),
            ),

            // Unlocked achievements
            if (unlocked.isNotEmpty) ...[
              _sectionTitle('DEBLOQUES (${unlocked.length})'),
              _buildGrid(unlocked, true),
              const SizedBox(height: 16),
            ],

            // Locked achievements
            if (locked.isNotEmpty) ...[
              _sectionTitle('A DEBLOQUER (${locked.length})'),
              _buildGrid(locked, false),
            ],

            // Empty state
            if (p.achievements.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Text('Aucun haut fait disponible.\nConnecte-toi au serveur pour charger les hauts faits.', textAlign: TextAlign.center, style: TextStyle(color: WC3Colors.textDim, fontSize: 13, fontStyle: FontStyle.italic)),
              ),
          ],
        ),
      );
    });
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(text, style: const TextStyle(color: WC3Colors.textDim, fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildGrid(List<Achievement> achievements, bool unlocked) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.75,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: achievements.length,
      itemBuilder: (ctx, i) => _AchievementCard(achievement: achievements[i], unlocked: unlocked),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  final Achievement achievement;
  final bool unlocked;

  const _AchievementCard({required this.achievement, required this.unlocked});

  @override
  Widget build(BuildContext context) {
    final tierCol = achievement.tierColor;

    return GestureDetector(
      onTap: () => _showDetails(context),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: unlocked ? tierCol.withValues(alpha: 0.06) : WC3Colors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: unlocked ? tierCol.withValues(alpha: 0.4) : Colors.white10,
            width: unlocked ? 1.5 : 1,
          ),
          boxShadow: unlocked ? [BoxShadow(color: tierCol.withValues(alpha: 0.15), blurRadius: 8)] : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon with lock overlay
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: unlocked ? tierCol.withValues(alpha: 0.12) : WC3Colors.bgSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: unlocked ? tierCol.withValues(alpha: 0.3) : Colors.white10),
                  ),
                  child: Icon(
                    achievement.iconData,
                    color: unlocked ? tierCol : WC3Colors.textDim.withValues(alpha: 0.4),
                    size: 24,
                  ),
                ),
                if (!unlocked)
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
                      child: const Icon(Icons.lock, color: WC3Colors.textDim, size: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            // Name
            Text(
              achievement.name,
              style: TextStyle(
                color: unlocked ? tierCol : WC3Colors.textDim,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            // Tier
            Text(
              achievement.tier.toUpperCase(),
              style: TextStyle(
                color: unlocked ? tierCol.withValues(alpha: 0.7) : WC3Colors.textDim.withValues(alpha: 0.4),
                fontSize: 8,
                letterSpacing: 1,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    final tierCol = achievement.tierColor;
    showModalBottomSheet(
      context: context,
      backgroundColor: WC3Colors.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: WC3Colors.textDim, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: unlocked ? tierCol.withValues(alpha: 0.12) : WC3Colors.bgSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: unlocked ? tierCol : Colors.white10, width: 2),
                boxShadow: unlocked ? [BoxShadow(color: tierCol.withValues(alpha: 0.3), blurRadius: 12)] : null,
              ),
              child: Icon(
                achievement.iconData,
                color: unlocked ? tierCol : WC3Colors.textDim,
                size: 32,
              ),
            ),
            const SizedBox(height: 12),
            Text(achievement.name, style: TextStyle(color: unlocked ? tierCol : WC3Colors.goldText, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(achievement.tier.toUpperCase(), style: TextStyle(color: tierCol, fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Text(achievement.description, style: const TextStyle(color: WC3Colors.textMid, fontSize: 13), textAlign: TextAlign.center),
            if (unlocked && achievement.unlockedAt != null) ...[
              const SizedBox(height: 10),
              Text(
                'Debloque le ${_formatDate(achievement.unlockedAt!)}',
                style: const TextStyle(color: WC3Colors.textDim, fontSize: 11, fontStyle: FontStyle.italic),
              ),
            ],
            if (!unlocked) ...[
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.lock, color: WC3Colors.textDim, size: 14),
                const SizedBox(width: 4),
                const Text('Pas encore debloque', style: TextStyle(color: WC3Colors.textDim, fontSize: 11, fontStyle: FontStyle.italic)),
              ]),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _formatDate(int timestamp) {
    final d = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}
