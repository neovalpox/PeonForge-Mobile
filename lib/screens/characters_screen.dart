import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/peonforge_provider.dart';
import '../theme/wc3_theme.dart';
import '../models/models.dart';

class CharactersScreen extends StatelessWidget {
  final String? sessionId; // if set, selecting a character assigns it to this session

  const CharactersScreen({super.key, this.sessionId});

  @override
  Widget build(BuildContext context) {
    return Consumer<PeonForgeProvider>(builder: (ctx, p, _) {
      final level = p.tamagotchi.level;
      final unlocked = p.characters.where((c) => c.unlocked).toList();
      final locked = p.characters.where((c) => !c.unlocked).toList();
      // Next unlock
      final nextUnlock = locked.isNotEmpty ? locked.reduce((a, b) => a.unlockLevel < b.unlockLevel ? a : b) : null;

      return Scaffold(
        backgroundColor: WC3Colors.bgDark,
        appBar: AppBar(
          backgroundColor: WC3Colors.bgCard,
          title: Text(sessionId != null ? 'Choisir un personnage' : 'Personnages', style: const TextStyle(color: WC3Colors.goldLight, fontSize: 16)),
          leading: IconButton(icon: const Icon(Icons.arrow_back, color: WC3Colors.goldLight), onPressed: () => Navigator.pop(context)),
        ),
        body: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            // Progress to next unlock
            if (nextUnlock != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: WC3Colors.bgCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: nextUnlock.factionColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(nextUnlock.iconUrl, width: 40, height: 40, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(width: 40, height: 40, color: WC3Colors.bgSurface,
                          child: Center(child: Text('?', style: TextStyle(color: nextUnlock.factionColor, fontSize: 18))))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Prochain : ${nextUnlock.name}', style: TextStyle(color: nextUnlock.factionColor, fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text('Niveau ${nextUnlock.unlockLevel} requis (tu es Niv. $level)', style: const TextStyle(color: WC3Colors.textDim, fontSize: 11)),
                      ]),
                    ),
                  ],
                ),
              ),

            // Unlocked section
            if (unlocked.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text('DEBLOQUES (${unlocked.length})', style: const TextStyle(color: WC3Colors.textDim, fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
              ),
              _buildGrid(context, unlocked, p, true),
              const SizedBox(height: 16),
            ],

            // Locked section
            if (locked.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text('A DEBLOQUER (${locked.length})', style: const TextStyle(color: WC3Colors.textDim, fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
              ),
              _buildGrid(context, locked, p, false),
            ],
          ],
        ),
      );
    });
  }

  Widget _buildGrid(BuildContext context, List<GameCharacter> chars, PeonForgeProvider p, bool unlocked) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.75,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: chars.length,
      itemBuilder: (ctx, i) => _CharacterCard(
        character: chars[i],
        unlocked: unlocked,
        isCurrentAvatar: p.avatar == chars[i].id,
        onTap: unlocked ? () {
          if (sessionId != null) {
            p.setSessionCharacter(sessionId!, chars[i].id);
          } else {
            p.setAvatar(chars[i].id);
          }
          Navigator.pop(context);
        } : null,
      ),
    );
  }
}

class _CharacterCard extends StatelessWidget {
  final GameCharacter character;
  final bool unlocked;
  final bool isCurrentAvatar;
  final VoidCallback? onTap;

  const _CharacterCard({required this.character, required this.unlocked, this.isCurrentAvatar = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final col = character.factionColor;
    final tierCol = character.tierColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isCurrentAvatar ? col.withValues(alpha: 0.08) : WC3Colors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isCurrentAvatar ? col : (unlocked ? col.withValues(alpha: 0.3) : Colors.white10), width: isCurrentAvatar ? 2 : 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Portrait
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ColorFiltered(
                    colorFilter: unlocked
                        ? const ColorFilter.mode(Colors.transparent, BlendMode.multiply)
                        : const ColorFilter.matrix([0.2,0.2,0.2,0,0, 0.2,0.2,0.2,0,0, 0.2,0.2,0.2,0,0, 0,0,0,0.5,0]),
                    child: Image.network(character.iconUrl, width: 48, height: 48, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(width: 48, height: 48, color: WC3Colors.bgSurface,
                        child: Center(child: Text(character.name[0], style: TextStyle(color: col, fontSize: 20, fontWeight: FontWeight.w700))))),
                  ),
                ),
                if (!unlocked)
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
                        child: Text('Niv.${character.unlockLevel}', style: const TextStyle(color: WC3Colors.goldLight, fontSize: 9, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            // Name
            Text(character.name, style: TextStyle(color: unlocked ? col : WC3Colors.textDim, fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
            // Tier
            Text(character.tier.toUpperCase(), style: TextStyle(color: unlocked ? tierCol : WC3Colors.textDim.withValues(alpha: 0.5), fontSize: 8, letterSpacing: 1, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
