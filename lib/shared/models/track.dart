class Track {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String extension;
  final double duration;
  final int size;
  final int scrapeStatus;
  final bool hasLyrics;
  final String? filepath;

  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.extension,
    required this.duration,
    required this.size,
    required this.scrapeStatus,
    required this.hasLyrics,
    this.filepath,
  });

  factory Track.fromJson(Map<String, dynamic> json) => Track(
    id: json['id'] as String,
    title: (json['title'] as String?) ?? '未知标题',
    artist: (json['artist'] as String?) ?? '未知艺术家',
    album: (json['album'] as String?) ?? '未知专辑',
    extension: (json['extension'] as String?) ?? '',
    duration: ((json['duration'] as num?) ?? 0).toDouble(),
    size: (json['size'] as int?) ?? 0,
    scrapeStatus: (json['scrape_status'] as int?) ?? 0,
    hasLyrics: (json['hasLyrics'] as bool?) ?? false,
    filepath: json['filepath'] as String?,
  );

  /// 格式化时长 mm:ss
  String get durationText {
    final s = duration.toInt();
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  /// 格式化文件大小
  String get sizeText {
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}

class TracksResponse {
  final List<String> folders;
  final List<Track> tracks;

  const TracksResponse({required this.folders, required this.tracks});

  factory TracksResponse.fromJson(Map<String, dynamic> json) => TracksResponse(
    folders: ((json['folders'] as List<dynamic>?) ?? [])
        .map((e) => e as String)
        .toList(),
    tracks: ((json['tracks'] as List<dynamic>?) ?? [])
        .map((e) => Track.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
