import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music/core/auth/auth_service.dart';
import 'package:music/core/http/api_client.dart';
import 'package:music/core/player/player_service.dart';
import 'package:music/core/repositories/collection_repository.dart';
import 'package:music/core/repositories/track_repository.dart';
import 'package:music/core/router/router.dart';
import 'package:music/features/search/search_page.dart';
import 'package:music/features/settings/settings_provider.dart';
import 'package:music/shared/models/discovery_album.dart';
import 'package:music/shared/models/playlist.dart';
import 'package:music/shared/models/track.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('home search button opens the full search page', (tester) async {
    SharedPreferences.setMockInitialValues(const {});
    final prefs = await SharedPreferences.getInstance();
    final auth = _FakeAuthService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWith((ref) => auth),
          sharedPreferencesProvider.overrideWithValue(prefs),
          trackRepositoryProvider.overrideWith(
            (ref) => _FakeTrackRepository(auth),
          ),
          collectionRepositoryProvider.overrideWith(
            (ref) => _FakeCollectionRepository(auth),
          ),
          playerHandlerProvider.overrideWith((ref) => MusicPlayerHandler()),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            final router = ref.watch(routerProvider);
            return MaterialApp.router(routerConfig: router);
          },
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.search_rounded), findsWidgets);

    await tester.tap(find.byIcon(Icons.search_rounded).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(SearchPage), findsOneWidget);
    expect(find.byIcon(Icons.home_rounded).hitTestable(), findsNothing);
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Muse');
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Muse'), findsOneWidget);
  });

  testWidgets(
    'search page keeps the search field visible when mini player is active',
    (tester) async {
      SharedPreferences.setMockInitialValues(const {});
      final prefs = await SharedPreferences.getInstance();
      final auth = _FakeAuthService();
      final handler = MusicPlayerHandler();

      handler.mediaItem.add(
        MediaItem(
          id: 'track-1',
          title: 'Current Song',
          artist: 'Current Artist',
          artUri: Uri.parse('https://example.com/cover.jpg'),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWith((ref) => auth),
            sharedPreferencesProvider.overrideWithValue(prefs),
            trackRepositoryProvider.overrideWith(
              (ref) => _FakeTrackRepository(auth),
            ),
            collectionRepositoryProvider.overrideWith(
              (ref) => _FakeCollectionRepository(auth),
            ),
            playerHandlerProvider.overrideWith((ref) => handler),
          ],
          child: const MaterialApp(home: SearchPage()),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final searchField = find.byType(TextField).hitTestable();
      final miniPlayerButton = find.byIcon(Icons.play_arrow_rounded)
          .hitTestable();

      expect(searchField, findsOneWidget);
      expect(
        find.byIcon(Icons.arrow_back_ios_new_rounded).hitTestable(),
        findsOneWidget,
      );
      expect(miniPlayerButton, findsOneWidget);
      expect(
        tester.getTopLeft(searchField).dy,
        lessThan(tester.getTopLeft(miniPlayerButton).dy),
      );
    },
  );
}

class _FakeAuthService extends AuthService {
  _FakeAuthService() : super() {
    state = const AuthState(
      token: 'token',
      baseUrl: 'http://example.com',
      username: 'user',
      password: 'pass',
      isAuthenticated: true,
    );
  }

  @override
  Future<String?> getToken() async => state.token;
}

class _FakeTrackRepository extends TrackRepository {
  _FakeTrackRepository(_FakeAuthService auth)
    : super(ApiClient(auth, 'http://example.com'));

  static const _sampleTrack = Track(
    id: 'track-1',
    title: 'Test Song',
    artist: 'Test Artist',
    album: 'Test Album',
    extension: '.mp3',
    duration: 180,
    size: 1024,
    scrapeStatus: 1,
    hasLyrics: false,
  );

  @override
  Future<TracksResponse> getTracks({String? folder, int? status}) async {
    return const TracksResponse(folders: <String>[], tracks: <Track>[]);
  }

  @override
  Future<List<Track>> getRandomTracks({int limit = 30}) async {
    return const <Track>[_sampleTrack];
  }

  @override
  Future<List<Track>> getRecentTracks({int limit = 50}) async {
    return const <Track>[_sampleTrack];
  }

  @override
  Future<List<DiscoveryAlbum>> getDiscoveryAlbums() async {
    return const <DiscoveryAlbum>[];
  }

  @override
  Future<List<Track>> getPlayHistory({int limit = 50}) async {
    return const <Track>[];
  }
}

class _FakeCollectionRepository extends CollectionRepository {
  _FakeCollectionRepository(_FakeAuthService auth)
    : super(ApiClient(auth, 'http://example.com'));

  @override
  Future<List<Track>> getFavorites() async => const <Track>[];

  @override
  Future<List<UserPlaylist>> getPlaylists() async => const <UserPlaylist>[];
}
