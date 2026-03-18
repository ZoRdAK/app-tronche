class Photo {
  final int? id;
  final String localPath;
  final String? thumbnailPath;
  final String photoCode;
  final DateTime takenAt;
  final bool isSynced;
  final String? serverPhotoId;
  final DateTime? syncedAt;

  Photo({
    this.id,
    required this.localPath,
    this.thumbnailPath,
    required this.photoCode,
    required this.takenAt,
    this.isSynced = false,
    this.serverPhotoId,
    this.syncedAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'local_path': localPath,
        'thumbnail_path': thumbnailPath,
        'photo_code': photoCode,
        'taken_at': takenAt.toIso8601String(),
        'is_synced': isSynced ? 1 : 0,
        'server_photo_id': serverPhotoId,
        'synced_at': syncedAt?.toIso8601String(),
      };

  factory Photo.fromMap(Map<String, dynamic> map) => Photo(
        id: map['id'],
        localPath: map['local_path'],
        thumbnailPath: map['thumbnail_path'],
        photoCode: map['photo_code'],
        takenAt: DateTime.parse(map['taken_at']),
        isSynced: map['is_synced'] == 1,
        serverPhotoId: map['server_photo_id'],
        syncedAt: map['synced_at'] != null
            ? DateTime.parse(map['synced_at'] as String)
            : null,
      );
}
