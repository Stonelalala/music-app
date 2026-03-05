import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/player/player_service.dart';
import 'core/player/cache_service.dart';
import 'core/auth/auth_service.dart';
import 'core/router/router.dart';
import 'shared/theme/app_theme.dart';
import 'features/settings/settings_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  MusicPlayerHandler handler;

  if (kIsWeb) {
    // Web 平台：直接实例化，不走 AudioService（Web 不支持后台播放）
    handler = MusicPlayerHandler();
  } else {
    // Android/iOS：初始化后台播放服务
    handler = await AudioService.init(
      builder: MusicPlayerHandler.new,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.stonelalala.music.channel.audio',
        androidNotificationChannelName: 'Music Playback',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
  }

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
  @override
  void initState() {
    super.initState();
    // 仅在初始化时执行一次恢复
    Future.microtask(() async {
      await ref.read(authServiceProvider.notifier).init();
      
      // 恢复后立即同步给播放器
      final auth = ref.read(authServiceProvider);
      if (auth.isAuthenticated && auth.token != null && auth.baseUrl != null) {
        ref.read(playerHandlerProvider).setAuth(auth.token!, auth.baseUrl!);
      }
      
      // 启动时初次同步缓存配置
      final cacheService = ref.read(cacheServiceProvider);
      final maxBytes = ref.read(settingsProvider.notifier).maxCacheSizeBytes;
      ref.read(playerHandlerProvider).setCacheConfig(cacheService, maxBytes);
    });
  }

  @override
  Widget build(BuildContext context) {
    // 监听认证状态变化，同步给播放器
    ref.listen(authServiceProvider, (previous, next) {
      if (next.isAuthenticated && next.token != null && next.baseUrl != null) {
        ref.read(playerHandlerProvider).setAuth(next.token!, next.baseUrl!);
      }
    });

    // 监听缓存设置变化，同步给播放器
    ref.listen(settingsProvider, (previous, next) {
      final cacheService = ref.read(cacheServiceProvider);
      final maxBytes = ref.read(settingsProvider.notifier).maxCacheSizeBytes;
      ref.read(playerHandlerProvider).setCacheConfig(cacheService, maxBytes);
    });

    final router = ref.watch(routerProvider);
    final themeType = ref.watch(themeTypeProvider);

    return MaterialApp.router(
      title: '石头音乐',
      theme: AppTheme.getTheme(themeType),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
