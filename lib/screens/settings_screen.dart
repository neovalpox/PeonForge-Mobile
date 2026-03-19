import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/peonforge_provider.dart';
import '../theme/wc3_theme.dart';
import '../widgets/gold_card.dart';
import 'characters_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PeonForgeProvider>(builder: (ctx, p, _) {
      return ListView(
        padding: const EdgeInsets.only(bottom: 20),
        children: [
          // Connection info
          GoldCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.circle, size: 10, color: p.connected ? WC3Colors.green : WC3Colors.red),
                    const SizedBox(width: 8),
                    Text(p.connected ? 'Connecte' : 'Deconnecte', style: TextStyle(color: p.connected ? WC3Colors.green : WC3Colors.red, fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
                if (p.serverIp != null) ...[
                  const SizedBox(height: 4),
                  Text('${p.hostname}  ·  ${p.serverIp}:7777', style: const TextStyle(color: WC3Colors.textMid, fontSize: 12)),
                ],
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => p.disconnect(),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: WC3Colors.goldDark),
                      foregroundColor: WC3Colors.goldLight,
                    ),
                    child: const Text('Deconnecter'),
                  ),
                ),
              ],
            ),
          ),

          // Faction
          _sectionTitle('Camp'),
          GoldCard(
            child: Row(
              children: [
                Expanded(
                  child: _factionButton('alliance', 'Alliance', 'assets/images/peasant.gif', WC3Colors.humanColor, p.config.side == 'alliance', () => p.setSide('alliance')),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _factionButton('horde', 'Horde', 'assets/images/peon.gif', WC3Colors.orcColor, p.config.side == 'horde', () => p.setSide('horde')),
                ),
              ],
            ),
          ),

          // Toggles
          _sectionTitle('Parametres'),
          GoldCard(
            child: Column(
              children: [
                _toggleRow('Son', 'Jouer les voix Warcraft', p.config.soundEnabled, (v) => p.setSoundEnabled(v)),
                const Divider(color: WC3Colors.bgSurface, height: 16),
                _toggleRow('Ecoute active', 'Recevoir les evenements', p.config.watching, (v) => p.setWatching(v)),
                const Divider(color: WC3Colors.bgSurface, height: 16),
                _toggleRow('Peon sur l\'ecran', 'Compagnon sur le bureau', p.config.showCompanion, (v) => p.setShowCompanion(v)),
                const Divider(color: WC3Colors.bgSurface, height: 16),
                _toggleRow('Notifications visuelles', 'Overlay WC3 en haut a droite', p.config.showNotifications, (v) => p.setShowNotifications(v)),
              ],
            ),
          ),

          // Volume
          _sectionTitle('Volume'),
          GoldCard(
            child: Row(
              children: [
                const Icon(Icons.volume_down, color: WC3Colors.textMid, size: 20),
                Expanded(
                  child: Slider(
                    value: p.config.volume,
                    min: 0, max: 1,
                    onChanged: (v) => p.setVolume(v),
                  ),
                ),
                SizedBox(
                  width: 36,
                  child: Text('${(p.config.volume * 100).round()}%', style: const TextStyle(color: WC3Colors.textMid, fontSize: 12)),
                ),
              ],
            ),
          ),

          // Username
          _sectionTitle('Pseudo (peonforge.ch)'),
          GoldCard(
            child: Row(
              children: [
                Expanded(
                  child: Text(p.username.isEmpty ? 'Non defini' : p.username,
                    style: TextStyle(color: p.username.isEmpty ? WC3Colors.textDim : WC3Colors.goldLight, fontSize: 15, fontWeight: FontWeight.w600)),
                ),
                GestureDetector(
                  onTap: () => _showUsernameDialog(context, p),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: WC3Colors.goldDark.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: WC3Colors.goldDark.withValues(alpha: 0.3)),
                    ),
                    child: Text(p.username.isEmpty ? 'Definir' : 'Modifier', style: const TextStyle(color: WC3Colors.goldLight, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),

          // Characters
          _sectionTitle('Personnages'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GestureDetector(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CharactersScreen())),
              child: GoldCard(
                margin: EdgeInsets.zero,
                child: Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: WC3Colors.bgSurface),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          p.avatar.isNotEmpty
                            ? 'https://peonforge.ch/assets/icons/${p.avatar}.png'
                            : 'https://peonforge.ch/assets/icons/${p.config.side == "horde" ? "peon_fr" : "peasant_fr"}.png',
                          fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Voir tous les personnages', style: TextStyle(color: WC3Colors.goldLight, fontSize: 14, fontWeight: FontWeight.w600)),
                        Text('${p.characters.where((c) => c.unlocked).length}/${p.characters.length} debloques', style: const TextStyle(color: WC3Colors.textDim, fontSize: 11)),
                      ],
                    )),
                    const Icon(Icons.chevron_right, color: WC3Colors.goldDark),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Test
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton.icon(
              onPressed: p.connected ? () => p.testNotification() : null,
              icon: const Text('Test', style: TextStyle(fontSize: 14)),
              label: const Text('Tester la notification'),
              style: ElevatedButton.styleFrom(
                backgroundColor: WC3Colors.goldDark.withValues(alpha: 0.3),
                foregroundColor: WC3Colors.goldLight,
                side: const BorderSide(color: WC3Colors.goldDark),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Text(text.toUpperCase(), style: const TextStyle(color: WC3Colors.textDim, fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
    );
  }

  Widget _toggleRow(String title, String sub, bool value, ValueChanged<bool> onChanged) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: WC3Colors.goldText, fontSize: 14)),
              Text(sub, style: const TextStyle(color: WC3Colors.textDim, fontSize: 11)),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }

  Widget _factionButton(String id, String label, String gif, Color color, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? color : Colors.white10, width: active ? 1.5 : 1),
          color: active ? color.withValues(alpha: 0.08) : Colors.transparent,
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(gif, width: 40, height: 40, fit: BoxFit.cover),
            ),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: active ? color : WC3Colors.textMid, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  void _showUsernameDialog(BuildContext context, PeonForgeProvider p) {
    final controller = TextEditingController(text: p.username);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: WC3Colors.bgCard,
        title: const Text('Pseudo', style: TextStyle(color: WC3Colors.goldLight)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: WC3Colors.goldText),
          decoration: const InputDecoration(
            hintText: 'Entre ton pseudo (2-20 car.)',
            hintStyle: TextStyle(color: WC3Colors.textDim),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: WC3Colors.goldDark)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: WC3Colors.goldLight)),
          ),
          maxLength: 20,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: WC3Colors.textDim))),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.length >= 2) {
                p.setUsername(name);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Valider', style: TextStyle(color: WC3Colors.goldLight, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
