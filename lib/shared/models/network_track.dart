class NetworkTrack {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String? year;
  final String? coverUrl;
  final String? source;

  NetworkTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    this.year,
    this.coverUrl,
    this.source,
  });

  factory NetworkTrack.fromJson(Map<String, dynamic> json, {String? defaultSource}) {
    return NetworkTrack(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '未知歌曲',
      artist: json['artist'] ?? '未知歌手',
      album: json['album'] ?? '',
      year: json['year'],
      coverUrl: json['coverUrl'],
      source: json['source'] ?? defaultSource,
    );
  }
}
