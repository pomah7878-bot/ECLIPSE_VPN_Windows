class VpnKey {
  final int id;
  final String name;
  final String server;
  final String protocol;
  final TrafficInfo traffic;
  final String? subId;
  final String? subUrl;
  final int? serverId;
  final ExpiryInfo expiry;
  final bool isActive;
  final bool isTrial;

  VpnKey({
    required this.id,
    required this.name,
    required this.server,
    required this.protocol,
    required this.traffic,
    this.subId,
    this.subUrl,
    this.serverId,
    required this.expiry,
    required this.isActive,
    required this.isTrial,
  });

  factory VpnKey.fromJson(Map<String, dynamic> json) {
    return VpnKey(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Ключ',
      server: json['server'] ?? '—',
      protocol: json['protocol'] ?? 'VLESS',
      traffic: TrafficInfo.fromJson(json['traffic'] ?? {}),
      subId: json['sub_id'],
      subUrl: json['sub_url'],
      serverId: json['server_id'],
      expiry: ExpiryInfo.fromJson(json['expiry'] ?? {}),
      isActive: json['is_active'] ?? false,
      isTrial: json['is_trial'] ?? false,
    );
  }
}

class TrafficInfo {
  final String usedHuman;
  final String limitHuman;
  final bool isUnlimited;
  final int usedBytes;
  final int limitBytes;
  final double percent;

  TrafficInfo({
    required this.usedHuman,
    required this.limitHuman,
    required this.isUnlimited,
    required this.usedBytes,
    required this.limitBytes,
    required this.percent,
  });

  factory TrafficInfo.fromJson(Map<String, dynamic> json) {
    return TrafficInfo(
      usedHuman: json['used_human'] ?? '0 B',
      limitHuman: json['limit_human'] ?? '∞',
      isUnlimited: json['is_unlimited'] ?? true,
      usedBytes: json['used_bytes'] ?? 0,
      limitBytes: json['limit_bytes'] ?? 0,
      percent: (json['percent'] ?? 0).toDouble(),
    );
  }
}

class ExpiryInfo {
  final String date;
  final String time;
  final bool isActive;
  final int daysLeft;
  final String remainingHuman;

  ExpiryInfo({
    required this.date,
    required this.time,
    required this.isActive,
    required this.daysLeft,
    required this.remainingHuman,
  });

  factory ExpiryInfo.fromJson(Map<String, dynamic> json) {
    return ExpiryInfo(
      date: json['date'] ?? '—',
      time: json['time'] ?? '',
      isActive: json['is_active'] ?? false,
      daysLeft: json['days_left'] ?? 0,
      remainingHuman: json['remaining_human'] ?? '—',
    );
  }
}

class ConnectionGroup {
  final String host;
  final List<Connection> connections;

  ConnectionGroup({required this.host, required this.connections});

  factory ConnectionGroup.fromJson(Map<String, dynamic> json) {
    return ConnectionGroup(
      host: json['host'] ?? '',
      connections: (json['connections'] as List? ?? [])
          .map((c) => Connection.fromJson(c))
          .toList(),
    );
  }
}

class Connection {
  final String protocol;
  final String link;
  final String? confContent;
  final int? ping;

  Connection({
    required this.protocol,
    required this.link,
    this.confContent,
    this.ping,
  });

  factory Connection.fromJson(Map<String, dynamic> json) {
    return Connection(
      protocol: json['protocol'] ?? '',
      link: json['link'] ?? '',
      confContent: json['conf_content'],
      ping: json['ping'],
    );
  }
}
