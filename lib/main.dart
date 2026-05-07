import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/auth/auth_service.dart';
import 'core/player/cache_service.dart';
import 'core/player/player_service.dart';
import 'core/repositories/sync_repository.dart';
import 'core/router/router.dart';
import 'features/settings/settings_provider.dart';
import 'shared/theme/app_theme.dart';
import 'shared/widgets/launch_splash_overlay.dart';

Future<MusicPlayerHandler> _initializePlayerHandler() async {
  if (kIsWeb) {
    return MusicPlayerHandler();
  }
  return AudioService.init(
    builder: MusicPlayerHandler.new,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.stonelalala.music.channel.audio',
      androidNotificationChannelName: 'Music Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final results = await Future.wait<Object>([
    SharedPreferences.getInstance(),
    _initializePlayerHandler(),
  ]);
  final prefs = results[0] as SharedPreferences;
  final handler = results[1] as MusicPlayerHandler;

  runApp(
    ProviderScope(
      overrides: [
        playerHandlerProvider.overrideWith((ref) => handler),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const MusicApp(),
    ),
  );
}

class MusicApp extends ConsumerStatefulWidget {
  const MusicApp({super.key});

  @override
  ConsumerState<MusicApp> createState() => _MusicAppState();
}

class _MusicAppState extends ConsumerState<MusicApp> {
  bool _sessionRecoveryInFlight = false;
  bool _showLaunchSplash = true;
  DateTime? _lastSessionRecoveryAt;
  final Stopwatch _launchStopwatch = Stopwatch()..start();

  late final AppLifecycleListener _lifecycleListener = AppLifecycleListener(
    onResume: () {
      unawaited(_recoverSessionOnResume());
    },
  );

  Future<void> _completeLaunchSplash() async {
    const minimumSplashDuration = Duration(milliseconds: 450);
    final remaining = minimumSplashDuration - _launchStopwatch.elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _showLaunchSplash = false;
    });
  }

  Future<void> _syncPreferencesFromServer({
    bool autoPlayOnRestore = false,
  }) async {
    final auth = ref.read(authServiceProvider);
    if (!auth.isAuthenticated) {
      return;
    }

    final syncRepository = ref.read(syncRepositoryProvider);
    final player = ref.read(playerHandlerProvider);
    player.setRemotePreferenceSync(syncRepository.setPreference);

    try {
      final remotePreferences = await syncRepository.getPreferences();
      final remoteTheme = remotePreferences['theme_type'] as String?;
      if (remoteTheme != null) {
        final type = ThemeType.values.firstWhere(
          (item) => item.name == remoteTheme,
          orElse: () => ThemeType.system,
        );
        await ref.read(themeTypeProvider.notifier).setTheme(type);
      }

      final remoteCacheSize = remotePreferences['max_cache_size_mb'];
      if (remoteCacheSize is num) {
        await ref
            .read(settingsProvider.notifier)
            .setMaxCacheSize(remoteCacheSize.toInt());
      }

      await player.applyRemotePreferences(
        remotePreferences,
        autoPlayOnRestore: autoPlayOnRestore,
      );
    } catch (e) {
      debugPrint('Remote preference sync failed: $e');
    }
  }

  Future<void> _recoverSessionOnResume() async {
    final now = DateTime.now();
    if (_sessionRecoveryInFlight) {
      return;
    }
    if (_lastSessionRecoveryAt != null &&
        now.difference(_lastSessionRecoveryAt!) < const Duration(seconds: 3)) {
      return;
    }

    final auth = ref.read(authServiceProvider);
    if (!auth.isAuthenticated) {
      return;
    }

    _sessionRecoveryInFlight = true;
    _lastSessionRecoveryAt = now;
    try {
      final restored = await ref
          .read(authServiceProvider.notifier)
          .ensureActiveSession();
      final nextAuth = ref.read(authServiceProvider);
      if (restored &&
          nextAuth.isAuthenticated &&
          nextAuth.token != null &&
          nextAuth.baseUrl != null) {
        ref
            .read(playerHandlerProvider)
            .setAuth(nextAuth.token!, nextAuth.baseUrl!);
      }
    } finally {
      _sessionRecoveryInFlight = false;
    }
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final player = ref.read(playerHandlerProvider);
      try {
        await Future.wait<void>([
          ref.read(authServiceProvider.notifier).init(),
          player.initHistoryStorage(ref.read(sharedPreferencesProvider)),
        ]);

        final cacheService = ref.read(cacheServiceProvider);
        final maxBytes = ref.read(settingsProvider.notifier).maxCacheSizeBytes;
        player.setCacheConfig(cacheService, maxBytes);

        final auth = ref.read(authServiceProvider);
        if (auth.isAuthenticated &&
            auth.token != null &&
            auth.baseUrl != null) {
          player.setAuth(auth.token!, auth.baseUrl!, autoPlayOnRestore: true);
        }

        unawaited(_syncPreferencesFromServer(autoPlayOnRestore: true));
      } finally {
        await _completeLaunchSplash();
      }
    });
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authServiceProvider, (previous, next) {
      if (next.isAuthenticated && next.token != null && next.baseUrl != null) {
        ref.read(playerHandlerProvider).setAuth(next.token!, next.baseUrl!);
        Future.microtask(_syncPreferencesFromServer);
      } else {
        ref.read(playerHandlerProvider).clearAuth();
      }
    });

    ref.listen(settingsProvider, (previous, next) {
      final cacheService = ref.read(cacheServiceProvider);
      final maxBytes = ref.read(settingsProvider.notifier).maxCacheSizeBytes;
      ref.read(playerHandlerProvider).setCacheConfig(cacheService, maxBytes);
      if (ref.read(authServiceProvider).isAuthenticated) {
        unawaited(
          ref
              .read(syncRepositoryProvider)
              .setPreference('max_cache_size_mb', next.maxCacheSizeMB),
        );
      }
    });

    ref.listen(themeTypeProvider, (previous, next) {
      if (ref.read(authServiceProvider).isAuthenticated) {
        unawaited(
          ref
              .read(syncRepositoryProvider)
              .setPreference('theme_type', next.name),
        );
      }
    });

    final router = ref.watch(routerProvider);
    final themeType = ref.watch(themeTypeProvider);
    final themeMode = switch (themeType) {
      ThemeType.system => ThemeMode.system,
      ThemeType.light => ThemeMode.light,
      _ => ThemeMode.dark,
    };

    return MaterialApp.router(
      title: '石头音乐',
      theme: AppTheme.getTheme(ThemeType.light),
      darkTheme: AppTheme.getTheme(
        themeType == ThemeType.magenta ? ThemeType.magenta : ThemeType.dark,
      ),
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return Stack(
          fit: StackFit.expand,
          children: [
            child ?? const SizedBox.shrink(),
            LaunchSplashOverlay(visible: _showLaunchSplash),
          ],
        );
      },
    );
  }
}
