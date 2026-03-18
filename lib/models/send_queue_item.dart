class SendQueueItem {
  final int? id;
  final int photoId;
  final String type; // 'sync' or 'email'
  final String? recipient;
  final String status; // 'pending', 'sending', 'sent', 'failed'
  final int attempts;
  final String? lastError;
  final DateTime createdAt;
  final DateTime? sentAt;

  SendQueueItem({
    this.id,
    required this.photoId,
    required this.type,
    this.recipient,
    this.status = 'pending',
    this.attempts = 0,
    this.lastError,
    required this.createdAt,
    this.sentAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'photo_id': photoId,
        'type': type,
        'recipient': recipient,
        'status': status,
        'attempts': attempts,
        'last_error': lastError,
        'created_at': createdAt.toIso8601String(),
        'sent_at': sentAt?.toIso8601String(),
      };

  factory SendQueueItem.fromMap(Map<String, dynamic> map) => SendQueueItem(
        id: map['id'],
        photoId: map['photo_id'],
        type: map['type'],
        recipient: map['recipient'],
        status: map['status'] ?? 'pending',
        attempts: map['attempts'] ?? 0,
        lastError: map['last_error'],
        createdAt: DateTime.parse(map['created_at']),
        sentAt: map['sent_at'] != null
            ? DateTime.parse(map['sent_at'] as String)
            : null,
      );
}
