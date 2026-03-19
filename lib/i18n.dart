import 'dart:ui';

class I18n {
  static String _lang = 'fr';

  static void init() {
    final locale = PlatformDispatcher.instance.locale;
    _lang = locale.languageCode == 'fr' ? 'fr' : 'en';
  }

  static String get lang => _lang;
  static bool get isFr => _lang == 'fr';

  static String t(String key) => (_strings[_lang]?[key]) ?? (_strings['en']?[key]) ?? key;

  static final Map<String, Map<String, String>> _strings = {
    'fr': {
      // Navigation
      'home': 'Accueil',
      'agents': 'Agents',
      'settings': 'Reglages',

      // Home
      'no_activity': 'Aucune activite recente',
      'active_sessions': 'SESSIONS ACTIVES',
      'activity': 'ACTIVITE',
      'happiness': 'Bonheur',
      'pet': 'Caresser',
      'feed': 'Nourrir',
      'train': 'Entrainer',
      'free': 'Gratuit',
      'gold_cost': 'Or',
      'see_leaderboard': 'Voir le classement sur peonforge.ch',
      'tasks': 'taches',

      // Agents
      'no_agent': 'Aucun agent actif',
      'launch_claude': 'Lance Claude Code pour voir tes sessions ici',
      'view_terminal': 'Voir terminal',
      'change_avatar': 'Changer avatar',
      'events': 'events',

      // Settings
      'camp': 'CAMP',
      'alliance': 'Alliance',
      'horde': 'Horde',
      'parameters': 'PARAMETRES',
      'sound': 'Son',
      'sound_sub': 'Jouer les voix Warcraft',
      'listening': 'Ecoute active',
      'listening_sub': 'Recevoir les evenements',
      'companion_toggle': 'Peon sur l\'ecran',
      'companion_sub': 'Compagnon sur le bureau',
      'notifications_toggle': 'Notifications visuelles',
      'notifications_sub': 'Overlay WC3 en haut a droite',
      'volume': 'VOLUME',
      'username_section': 'PSEUDO (PEONFORGE.CH)',
      'not_set': 'Non defini',
      'set': 'Definir',
      'modify': 'Modifier',
      'characters_section': 'PERSONNAGES',
      'see_all_characters': 'Voir tous les personnages',
      'unlocked': 'debloques',
      'test_notification': 'Tester la notification',
      'connection_info': 'CONNEXION',
      'connected': 'Connecte',
      'disconnected': 'Deconnecte',
      'disconnect': 'Deconnecter',

      // Characters
      'choose_character': 'Choisir un personnage',
      'characters': 'Personnages',
      'next_unlock': 'Prochain',
      'level_required': 'Niveau {0} requis (tu es Niv. {1})',
      'unlocked_section': 'DEBLOQUES',
      'locked_section': 'A DEBLOQUER',

      // Terminal
      'connecting': 'Connexion au terminal...',
      'offline': 'Hors ligne',

      // Connect
      'connect_title': 'Connecte-toi a ton PC',
      'scan_qr': 'Scanner le QR du PC',
      'or': 'ou',
      'connect': 'Connecter',
      'servers_found': 'Serveurs trouves',
      'scanning': 'Scan du reseau...',
      'no_server': 'Aucun serveur trouve.\nVerifie que PeonForge est lance sur ton PC.',
      'change_server': 'Changer de serveur',
      'connecting_to': 'Connexion en cours...',

      // General
      'cancel': 'Annuler',
      'validate': 'Valider',
      'username_hint': 'Entre ton pseudo (2-20 car.)',
      'username_title': 'Pseudo',
      'not_enough_gold': 'Pas assez d\'or',
      'already_training': 'Deja en entrainement',
    },
    'en': {
      'home': 'Home',
      'agents': 'Agents',
      'settings': 'Settings',
      'no_activity': 'No recent activity',
      'active_sessions': 'ACTIVE SESSIONS',
      'activity': 'ACTIVITY',
      'happiness': 'Happiness',
      'pet': 'Pet',
      'feed': 'Feed',
      'train': 'Train',
      'free': 'Free',
      'gold_cost': 'Gold',
      'see_leaderboard': 'See leaderboard on peonforge.ch',
      'tasks': 'tasks',
      'no_agent': 'No active agent',
      'launch_claude': 'Launch Claude Code to see your sessions here',
      'view_terminal': 'View terminal',
      'change_avatar': 'Change avatar',
      'events': 'events',
      'camp': 'SIDE',
      'alliance': 'Alliance',
      'horde': 'Horde',
      'parameters': 'SETTINGS',
      'sound': 'Sound',
      'sound_sub': 'Play Warcraft voices',
      'listening': 'Active listening',
      'listening_sub': 'Receive events',
      'companion_toggle': 'Peon on screen',
      'companion_sub': 'Companion on desktop',
      'notifications_toggle': 'Visual notifications',
      'notifications_sub': 'WC3 overlay top-right',
      'volume': 'VOLUME',
      'username_section': 'USERNAME (PEONFORGE.CH)',
      'not_set': 'Not set',
      'set': 'Set',
      'modify': 'Modify',
      'characters_section': 'CHARACTERS',
      'see_all_characters': 'See all characters',
      'unlocked': 'unlocked',
      'test_notification': 'Test notification',
      'connection_info': 'CONNECTION',
      'connected': 'Connected',
      'disconnected': 'Disconnected',
      'disconnect': 'Disconnect',
      'choose_character': 'Choose a character',
      'characters': 'Characters',
      'next_unlock': 'Next',
      'level_required': 'Level {0} required (you are Lv. {1})',
      'unlocked_section': 'UNLOCKED',
      'locked_section': 'TO UNLOCK',
      'connecting': 'Connecting to terminal...',
      'offline': 'Offline',
      'connect_title': 'Connect to your PC',
      'scan_qr': 'Scan PC QR code',
      'or': 'or',
      'connect': 'Connect',
      'servers_found': 'Servers found',
      'scanning': 'Scanning network...',
      'no_server': 'No server found.\nCheck that PeonForge is running on your PC.',
      'change_server': 'Change server',
      'connecting_to': 'Connecting...',
      'cancel': 'Cancel',
      'validate': 'OK',
      'username_hint': 'Enter your username (2-20 chars)',
      'username_title': 'Username',
      'not_enough_gold': 'Not enough gold',
      'already_training': 'Already training',
    },
  };
}
