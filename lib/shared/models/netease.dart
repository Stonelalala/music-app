class NeteasePlaylist {
  final String id;
  final String name;
  final String? coverUrl;
  final int? trackCount;
  final String? description;

  const NeteasePlaylist({
    required this.id,
    required this.name,
    this.coverUrl,
    this.trackCount,
    this.description,
  });

  factory NeteasePlaylist.fromJson(Map<String, dynamic> json) =>
      NeteasePlaylist(
        id: json['id']?.toString() ?? '',
        name: (json['name'] as String?) ?? '未知歌单',
        coverUrl: json['coverUrl'] as String? ?? json['picUrl'] as String?,
        trackCount: json['trackCount'] as int?,
        description: json['description'] as String?,
      );
}

class NeteaseSong {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String? coverUrl;
  final int duration; // ms

  const NeteaseSong({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    this.coverUrl,
    required this.duration,
  });

  factory NeteaseSong.fromJson(Map<String, dynamic> json) => NeteaseSong(
    id: json['id']?.toString() ?? '',
    title: (json['title'] as String?) ?? (json['name'] as String?) ?? '未知',
    artist: (json['artist'] as String?) ?? '未知艺术家',
    album: (json['album'] as String?) ?? '未知专辑',
    coverUrl: json['coverUrl'] as String? ?? json['picUrl'] as String?,
    duration: (json['duration'] as int?) ?? 0,
  );

  String get durationText {
    final s = duration ~/ 1000;
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }
}

class NeteasePlaylistDetail {
  final String id;
  final String name;
  final String? coverUrl;
  final List<NeteaseSong> tracks;

  const NeteasePlaylistDetail({
    required this.id,
    required this.name,
    this.coverUrl,
    required this.tracks,
  });

  factory NeteasePlaylistDetail.fromJson(Map<String, dynamic> json) =>
      NeteasePlaylistDetail(
        id: json['id']?.toString() ?? '',
        name: (json['name'] as String?) ?? '未知歌单',
        coverUrl: json['coverUrl'] as String? ?? json['picUrl'] as String?,
        tracks: ((json['tracks'] as List<dynamic>?) ?? [])
            .map((e) => NeteaseSong.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
