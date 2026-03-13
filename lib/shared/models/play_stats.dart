import 'track.dart';

class PlayStats {
  final int totalPlays;
  final int uniqueTracks;
  final int favoriteTracks;
  final int playlists;
  final List<Track> topTracks;

  const PlayStats({
    required this.totalPlays,
    required this.uniqueTracks,
    required this.favoriteTracks,
    required this.playlists,
    required this.topTracks,
  });

  factory PlayStats.fromJson(Map<String, dynamic> json) => PlayStats(
    totalPlays: (json['totalPlays'] as num?)?.toInt() ?? 0,
    uniqueTracks: (json['uniqueTracks'] as num?)?.toInt() ?? 0,
    favoriteTracks: (json['favoriteTracks'] as num?)?.toInt() ?? 0,
    playlists: (json['playlists'] as num?)?.toInt() ?? 0,
    topTracks: ((json['topTracks'] as List<dynamic>?) ?? const [])
        .map((item) => Track.fromJson(item as Map<String, dynamic>))
        .toList(),
  );
}
