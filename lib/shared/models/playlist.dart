import 'track.dart';

class UserPlaylist {
  final String id;
  final String name;
  final int trackCount;
  final String? coverTrackId;
  final String? customCoverTrackId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserPlaylist({
    required this.id,
    required this.name,
    required this.trackCount,
    this.coverTrackId,
    this.customCoverTrackId,
    this.createdAt,
    this.updatedAt,
  });

  factory UserPlaylist.fromJson(Map<String, dynamic> json) => UserPlaylist(
    id: json['id'] as String,
    name: (json['name'] as String?) ?? '未命名歌单',
    trackCount: (json['track_count'] as num?)?.toInt() ?? 0,
    coverTrackId: json['cover_track_id'] as String?,
    customCoverTrackId: json['cover'] as String?,
    createdAt: _parseDateTime(json['created_at']),
    updatedAt: _parseDateTime(json['updated_at']),
  );
}

class SmartPlaylistSummary {
  final String id;
  final String name;
  final String description;

  const SmartPlaylistSummary({
    required this.id,
    required this.name,
    required this.description,
  });

  factory SmartPlaylistSummary.fromJson(Map<String, dynamic> json) =>
      SmartPlaylistSummary(
        id: json['id'] as String,
        name: (json['name'] as String?) ?? 'Smart Playlist',
        description: (json['description'] as String?) ?? '',
      );
}

class PlaylistDetail extends UserPlaylist {
  final List<Track> tracks;

  const PlaylistDetail({
    required super.id,
    required super.name,
    required super.trackCount,
    required this.tracks,
    super.coverTrackId,
    super.customCoverTrackId,
    super.createdAt,
    super.updatedAt,
  });

  factory PlaylistDetail.fromJson(Map<String, dynamic> json) => PlaylistDetail(
    id: json['id'] as String,
    name: (json['name'] as String?) ?? '未命名歌单',
    trackCount: (json['track_count'] as num?)?.toInt() ?? 0,
    coverTrackId: json['cover_track_id'] as String?,
    customCoverTrackId: json['cover'] as String?,
    createdAt: _parseDateTime(json['created_at']),
    updatedAt: _parseDateTime(json['updated_at']),
    tracks: ((json['tracks'] as List<dynamic>?) ?? const [])
        .map((item) => Track.fromJson(item as Map<String, dynamic>))
        .toList(),
  );
}

DateTime? _parseDateTime(dynamic value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}
