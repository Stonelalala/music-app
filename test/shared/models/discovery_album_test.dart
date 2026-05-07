import 'package:flutter_test/flutter_test.dart';
import 'package:music/shared/models/discovery_album.dart';

void main() {
  test('fromJson maps album summary fields', () {
    final album = DiscoveryAlbum.fromJson({
      'album': 'Discovery',
      'artist': 'Daft Punk',
      'id': '123',
    });

    expect(album.album, 'Discovery');
    expect(album.artist, 'Daft Punk');
    expect(album.coverTrackId, '123');
  });

  test('fromJson falls back for missing album values', () {
    final album = DiscoveryAlbum.fromJson({'artist': 'Unknown Artist'});

    expect(album.album, 'Unknown Album');
    expect(album.artist, 'Unknown Artist');
    expect(album.coverTrackId, '');
  });
}
