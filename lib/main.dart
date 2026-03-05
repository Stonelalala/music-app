import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/player/player_service.dart';
import 'core/auth/auth_service.dart';
import 'core/router/router.dart';
import 'shared/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
      overrides: [playerHandlerProvider.overrideWithValue(handler)],
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
    Future.microtask(() {
      ref.read(authServiceProvider.notifier).init();
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

    final router = ref.watch(routerProvider);
    final themeType = ref.watch(themeTypeProvider);

    return MaterialApp.router(
      title: 'Music',
      theme: AppTheme.getTheme(themeType),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
