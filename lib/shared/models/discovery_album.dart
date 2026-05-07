class DiscoveryAlbum {
  const DiscoveryAlbum({
    required this.album,
    required this.artist,
    required this.coverTrackId,
  });

  final String album;
  final String artist;
  final String coverTrackId;

  factory DiscoveryAlbum.fromJson(Map<String, dynamic> json) {
    return DiscoveryAlbum(
      album: (json['album'] as String?)?.trim().isNotEmpty == true
          ? (json['album'] as String).trim()
          : 'Unknown Album',
      artist: (json['artist'] as String?)?.trim() ?? '',
      coverTrackId: json['id']?.toString() ?? '',
    );
  }
}
