class SavedPC {
  final String id; // unique id (from QR authToken or generated)
  String name; // hostname
  String? lanIp;
  String? tunnelUrl;
  int port;
  String? authToken;
  String? forgeToken;
  int lastConnected; // milliseconds since epoch

  SavedPC({
    required this.id,
    this.name = '',
    this.lanIp,
    this.tunnelUrl,
    this.port = 7777,
    this.authToken,
    this.forgeToken,
    this.lastConnected = 0,
  });

  factory SavedPC.fromJson(Map<String, dynamic> json) => SavedPC(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    lanIp: json['lanIp'],
    tunnelUrl: json['tunnelUrl'],
    port: json['port'] ?? 7777,
    authToken: json['authToken'],
    forgeToken: json['forgeToken'],
    lastConnected: json['lastConnected'] ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'lanIp': lanIp,
    'tunnelUrl': tunnelUrl,
    'port': port,
    'authToken': authToken,
    'forgeToken': forgeToken,
    'lastConnected': lastConnected,
  };

  /// Human-readable display name
  String get displayName => name.isNotEmpty ? name : (lanIp ?? tunnelUrl ?? id);

  /// Time ago string for last connected
  String get lastConnectedAgo {
    if (lastConnected == 0) return 'Jamais';
    final diff = DateTime.now().millisecondsSinceEpoch - lastConnected;
    if (diff < 60000) return 'A l\'instant';
    if (diff < 3600000) return 'Il y a ${diff ~/ 60000} min';
    if (diff < 86400000) return 'Il y a ${diff ~/ 3600000}h';
    return 'Il y a ${diff ~/ 86400000}j';
  }
}
