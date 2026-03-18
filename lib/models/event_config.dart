import 'dart:convert';

class EventConfig {
  final int? id;
  final String? serverEventId;
  final String userEmail;
  final String jwtToken;
  final String refreshToken;
  final String name1;
  final String name2;
  final String eventDate;
  final String overlayTemplate;
  final Map<String, dynamic> overlayConfig;
  final int timerDuration;
  final String adminPasswordHash;
  final String shareCode;
  final String plan;

  EventConfig({
    this.id,
    this.serverEventId,
    required this.userEmail,
    required this.jwtToken,
    required this.refreshToken,
    required this.name1,
    required this.name2,
    required this.eventDate,
    this.overlayTemplate = 'elegant',
    this.overlayConfig = const {},
    this.timerDuration = 3,
    required this.adminPasswordHash,
    required this.shareCode,
    this.plan = 'free',
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'server_event_id': serverEventId,
        'user_email': userEmail,
        'jwt_token': jwtToken,
        'refresh_token': refreshToken,
        'name1': name1,
        'name2': name2,
        'event_date': eventDate,
        'overlay_template': overlayTemplate,
        'overlay_config': jsonEncode(overlayConfig),
        'timer_duration': timerDuration,
        'admin_password_hash': adminPasswordHash,
        'share_code': shareCode,
        'plan': plan,
      };

  factory EventConfig.fromMap(Map<String, dynamic> map) => EventConfig(
        id: map['id'],
        serverEventId: map['server_event_id'],
        userEmail: map['user_email'],
        jwtToken: map['jwt_token'],
        refreshToken: map['refresh_token'],
        name1: map['name1'],
        name2: map['name2'],
        eventDate: map['event_date'],
        overlayTemplate: map['overlay_template'] ?? 'elegant',
        overlayConfig: map['overlay_config'] != null
            ? Map<String, dynamic>.from(jsonDecode(map['overlay_config'] as String))
            : {},
        timerDuration: map['timer_duration'] ?? 3,
        adminPasswordHash: map['admin_password_hash'],
        shareCode: map['share_code'],
        plan: map['plan'] ?? 'free',
      );

  EventConfig copyWith({
    String? name1,
    String? name2,
    String? eventDate,
    String? overlayTemplate,
    Map<String, dynamic>? overlayConfig,
    int? timerDuration,
    String? adminPasswordHash,
    String? plan,
    String? jwtToken,
    String? refreshToken,
  }) =>
      EventConfig(
        id: id,
        serverEventId: serverEventId,
        userEmail: userEmail,
        jwtToken: jwtToken ?? this.jwtToken,
        refreshToken: refreshToken ?? this.refreshToken,
        name1: name1 ?? this.name1,
        name2: name2 ?? this.name2,
        eventDate: eventDate ?? this.eventDate,
        overlayTemplate: overlayTemplate ?? this.overlayTemplate,
        overlayConfig: overlayConfig ?? this.overlayConfig,
        timerDuration: timerDuration ?? this.timerDuration,
        adminPasswordHash: adminPasswordHash ?? this.adminPasswordHash,
        shareCode: shareCode,
        plan: plan ?? this.plan,
      );
}
