import 'dart:ui' show Color;

class SessionCharacter {
  final String id;
  final String name;
  final String gif;
  final String color;

  SessionCharacter({required this.id, required this.name, required this.gif, required this.color});

  factory SessionCharacter.fromJson(Map<String, dynamic> json) => SessionCharacter(
    id: json['id'] ?? 'peasant',
    name: json['name'] ?? 'Paysan',
    gif: json['gif'] ?? 'assets/peasant.gif',
    color: json['color'] ?? '#64c8ff',
  );

  Color get parsedColor {
    try {
      final hex = color.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFF64C8FF);
    }
  }

  // For built-in characters, use local assets. For others, use web icon.
  bool get isLocal => id == 'peon' || id == 'peasant' || id == 'peon_fr' || id == 'peasant_fr';
  String get assetPath => id.contains('peon') ? 'assets/images/peon.gif' : 'assets/images/peasant.gif';
  String get iconUrl => 'https://peonforge.ch/assets/icons/${id.endsWith('_fr') ? id : '${id}_fr'}.png';
}

class Session {
  final String id;
  final String project;
  final SessionCharacter character;
  final int startTime;
  final int eventCount;

  Session({required this.id, required this.project, required this.character, required this.startTime, required this.eventCount});

  factory Session.fromJson(Map<String, dynamic> json) => Session(
    id: json['id'] ?? '',
    project: json['project'] ?? 'Projet',
    character: SessionCharacter.fromJson(json['character'] ?? {}),
    startTime: json['startTime'] ?? DateTime.now().millisecondsSinceEpoch,
    eventCount: json['eventCount'] ?? 0,
  );

  Duration get elapsed => Duration(milliseconds: DateTime.now().millisecondsSinceEpoch - startTime);
}

class TamagotchiState {
  final int xp, gold, level, xpInLevel, xpForLevel, tasksCompleted, totalWorkTime;
  final int happiness; // 0-100
  final int lastFed;   // timestamp
  final int lastPet;   // timestamp
  final bool xpBoost;  // training active

  TamagotchiState({
    this.xp = 0, this.gold = 0, this.level = 1,
    this.xpInLevel = 0, this.xpForLevel = 50,
    this.tasksCompleted = 0, this.totalWorkTime = 0,
    this.happiness = 50, this.lastFed = 0, this.lastPet = 0, this.xpBoost = false,
  });

  factory TamagotchiState.fromJson(Map<String, dynamic> json) => TamagotchiState(
    xp: json['xp'] ?? 0,
    gold: json['gold'] ?? 0,
    level: json['level'] ?? 1,
    xpInLevel: json['xpInLevel'] ?? 0,
    xpForLevel: json['xpForLevel'] ?? 50,
    tasksCompleted: json['tasksCompleted'] ?? 0,
    totalWorkTime: json['totalWorkTime'] ?? 0,
    happiness: json['happiness'] ?? 50,
    lastFed: json['lastFed'] ?? 0,
    lastPet: json['lastPet'] ?? 0,
    xpBoost: json['xpBoost'] ?? false,
  );

  double get xpProgress => xpForLevel > 0 ? xpInLevel / xpForLevel : 0;
}

class AppEvent {
  final String type;
  final String project;
  final String? sessionId;
  final String? characterId; // pack id of the session's character
  final int timestamp;

  AppEvent({required this.type, required this.project, this.sessionId, this.characterId, required this.timestamp});

  factory AppEvent.fromJson(Map<String, dynamic> json) => AppEvent(
    type: json['type'] ?? '',
    project: json['project'] ?? 'Projet',
    sessionId: json['sessionId'],
    characterId: (json['character'] is Map) ? json['character']['id'] : null,
    timestamp: json['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
  );

  static const Map<String, EventMeta> meta = {
    'SessionStart':       EventMeta('▶', 'Session demarree', Color(0xFF64C8FF)),
    'SubagentStart':      EventMeta('⚙', 'Agent lance', Color(0xFFDFBD5E)),
    'PermissionRequest':  EventMeta('🔑', 'Permission requise', Color(0xFFB482FF)),
    'PostToolUseFailure': EventMeta('✖', 'Erreur outil', Color(0xFFFF5050)),
    'PreCompact':         EventMeta('📦', 'Compactage', Color(0xFFFFC832)),
    'Stop':               EventMeta('✔', 'Tache terminee', Color(0xFF5AFF5A)),
    'SubagentStop':       EventMeta('✔', 'Agent termine', Color(0xFFDFBD5E)),
    'Notification':       EventMeta('🔔', 'Notification', Color(0xFFC8B88A)),
    'UserPromptSubmit':   EventMeta('➤', 'Prompt envoye', Color(0xFF5AFF5A)),
    'SessionEnd':         EventMeta('■', 'Session terminee', Color(0xFF64C8FF)),
  };

  EventMeta get eventMeta => meta[type] ?? const EventMeta('•', 'Evenement', Color(0xFFC8B88A));
}

class EventMeta {
  final String icon;
  final String label;
  final Color color;
  const EventMeta(this.icon, this.label, this.color);
}

class GameCharacter {
  final String id;
  final String name;
  final String race;
  final String faction;
  final String side; // alliance or horde
  final int unlockLevel;
  final int sounds;
  final String tier;
  final bool unlocked;

  GameCharacter({
    required this.id, required this.name, required this.race, required this.faction,
    this.side = 'alliance', required this.unlockLevel, this.sounds = 0, this.tier = 'common', this.unlocked = false,
  });

  factory GameCharacter.fromJson(Map<String, dynamic> json) => GameCharacter(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    race: json['race'] ?? '',
    faction: json['faction'] ?? 'human',
    side: json['side'] ?? (['human', 'nightelf'].contains(json['faction']) ? 'alliance' : 'horde'),
    unlockLevel: json['unlockLevel'] ?? 1,
    sounds: json['sounds'] ?? 0,
    tier: json['tier'] ?? 'common',
    unlocked: json['unlocked'] ?? false,
  );

  Color get factionColor {
    switch (faction) {
      case 'orc': return const Color(0xFFFF6644);
      case 'nightelf': return const Color(0xFFB482FF);
      case 'undead': return const Color(0xFF5AFF5A);
      case 'naga': return const Color(0xFF00CCAA);
      case 'neutral': return const Color(0xFFFFC832);
      default: return const Color(0xFF64C8FF);
    }
  }

  Color get tierColor {
    switch (tier) {
      case 'common': return const Color(0xFF5AFF5A);
      case 'rare': return const Color(0xFF64C8FF);
      case 'epic': return const Color(0xFFB482FF);
      case 'legendary': return const Color(0xFFFFD700);
      case 'mythic': return const Color(0xFFFF5050);
      default: return const Color(0xFFC8B88A);
    }
  }

  String get iconUrl => 'https://peonforge.ch/assets/icons/$id.png';
}

class PeonForgeConfig {
  final String faction;
  final String side;
  final double volume;
  final bool soundEnabled;
  final bool watching;
  final bool showCompanion;
  final bool showNotifications;

  PeonForgeConfig({this.faction = 'human', this.side = 'alliance', this.volume = 0.5, this.soundEnabled = true, this.watching = true, this.showCompanion = true, this.showNotifications = true});

  factory PeonForgeConfig.fromJson(Map<String, dynamic> json) => PeonForgeConfig(
    faction: json['faction'] ?? 'human',
    side: json['side'] ?? ((json['faction'] ?? 'human') == 'orc' ? 'horde' : 'alliance'),
    volume: (json['volume'] ?? 0.5).toDouble(),
    soundEnabled: json['soundEnabled'] ?? true,
    watching: json['watching'] ?? true,
    showCompanion: json['showCompanion'] ?? true,
    showNotifications: json['showNotifications'] ?? true,
  );
}
