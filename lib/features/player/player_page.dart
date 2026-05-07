import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import '../../core/auth/auth_service.dart';
import '../../core/player/player_service.dart';
import '../../core/repositories/collection_repository.dart';
import '../../shared/models/playlist.dart';
import '../../shared/models/track.dart';
import '../../shared/widgets/global_playlist.dart';
import '../library/widgets/track_edit_sheet.dart';
import '../../core/repositories/track_repository.dart';
import '../../shared/widgets/modern_toast.dart';
import '../my/collection_providers.dart';
import 'equalizer_page.dart';

class PlayerPage extends ConsumerStatefulWidget {
  const PlayerPage({super.key});

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final ScrollController _lyricScrollController = ScrollController();
  late AnimationController _rotationController;
  List<_LyricLine> _parsedLyrics = [];
  int _currentLyricIndex = -1;
  String? _rawLyrics;
  StreamSubscription<Duration>? _posSubscription;
  StreamSubscription<bool>? _playingSubscription;
  StreamSubscription<MediaItem?>? _mediaItemSubscription;
  String? _lastTrackId;
  bool _lyricSyncScheduled = false;

  // 进度条拖动优化：记录本地拖动值
  double? _draggingValue;

  // 记录当前布局信息以便滚动计算
  double _currentItemHeight = 0;

  bool get _hideLegacyTopActions => false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );
    _setupListeners();
  }

  void _setupListeners() {
    final handler = ref.read(playerHandlerProvider);
    _posSubscription = handler.player.positionStream.listen((pos) {
      if (_parsedLyrics.isNotEmpty) {
        _syncLyricToPosition(pos);
      }
    });
    _playingSubscription = handler.player.playingStream.listen((playing) {
      if (playing) {
        _rotationController.repeat();
      } else {
        _rotationController.stop();
      }
    });
    if (handler.player.playing) {
      _rotationController.repeat();
    }
    _mediaItemSubscription = handler.mediaItem.listen((_) {
      final track = handler.currentTrack;
      if (track != null && track.id != _lastTrackId) {
        unawaited(_handleTrackChanged(track));
      }
    });

    final track = handler.currentTrack;
    if (track != null) {
      unawaited(_handleTrackChanged(track));
    }
  }

  Future<void> _handleTrackChanged(Track track) async {
    if (_lastTrackId == track.id) {
      return;
    }
    _lastTrackId = track.id;
    if (mounted) {
      setState(() {
        _rawLyrics = null;
        _parsedLyrics = [];
        _currentLyricIndex = -1;
      });
    }
    await _fetchLyrics(track.id);
  }

  void _applyLyrics(String trackId, String? lyrics) {
    if (!mounted || trackId != _lastTrackId) {
      return;
    }

    if (lyrics == null || lyrics.trim().isEmpty) {
      setState(() {
        _rawLyrics = null;
        _parsedLyrics = [];
        _currentLyricIndex = -1;
      });
      return;
    }

    final handler = ref.read(playerHandlerProvider);
    setState(() {
      _rawLyrics = lyrics;
      _parsedLyrics = _parseLrc(
        lyrics,
        offset: Duration(milliseconds: handler.lyricOffsetForTrack(trackId)),
      );
      _currentLyricIndex = -1;
    });
    _scheduleLyricResync(immediate: true);
  }

  Future<void> _fetchLyrics(String trackId) async {
    final handler = ref.read(playerHandlerProvider);
    final cachedLyrics = handler.cachedLyricsForTrack(trackId);
    if (cachedLyrics != null && cachedLyrics.trim().isNotEmpty) {
      _applyLyrics(trackId, cachedLyrics);
      return;
    }

    final lyrics = await handler.getLyrics(trackId);
    _applyLyrics(trackId, lyrics);
  }

  int _findLyricIndex(Duration pos) {
    int index = -1;
    for (int i = 0; i < _parsedLyrics.length; i++) {
      if (pos >= _parsedLyrics[i].time) {
        index = i;
      } else {
        break;
      }
    }
    return index;
  }

  void _syncLyricToPosition(
    Duration pos, {
    bool immediate = false,
    bool forceScroll = false,
  }) {
    final index = _findLyricIndex(pos);
    if (!mounted || index == -1) {
      return;
    }

    final previousIndex = _currentLyricIndex;
    final changed = index != previousIndex;

    if (changed) {
      setState(() {
        _currentLyricIndex = index;
      });
    }

    if (changed || forceScroll) {
      _scrollToLyricIndex(
        index,
        immediate:
            immediate ||
            previousIndex == -1 ||
            (previousIndex - index).abs() > 1,
      );
    }
  }

  void _scheduleLyricResync({bool immediate = true, int retries = 4}) {
    if (!mounted || _parsedLyrics.isEmpty || _lyricSyncScheduled) {
      return;
    }
    _lyricSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _lyricSyncScheduled = false;
      if (!mounted || _parsedLyrics.isEmpty) {
        return;
      }
      _resyncLyrics(immediate: immediate, retries: retries);
    });
  }

  void _resyncLyrics({bool immediate = true, int retries = 4}) {
    if (!mounted || _parsedLyrics.isEmpty) {
      return;
    }

    final handler = ref.read(playerHandlerProvider);
    _syncLyricToPosition(
      handler.player.position,
      immediate: immediate,
      forceScroll: true,
    );

    if ((!_lyricScrollController.hasClients || _currentItemHeight <= 0) &&
        retries > 0) {
      Future.delayed(const Duration(milliseconds: 80), () {
        _scheduleLyricResync(immediate: immediate, retries: retries - 1);
      });
    }
  }

  void _scrollToLyricIndex(int lyricIndex, {bool immediate = false}) {
    if (_lyricScrollController.hasClients &&
        lyricIndex != -1 &&
        _currentItemHeight > 0) {
      final targetScroll = lyricIndex * _currentItemHeight;

      if (immediate) {
        _lyricScrollController.jumpTo(targetScroll);
      } else {
        _lyricScrollController.animateTo(
          targetScroll,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final track = ref.read(playerHandlerProvider).currentTrack;
      if (track != null && _parsedLyrics.isEmpty) {
        unawaited(_fetchLyrics(track.id));
      }
      _scheduleLyricResync(immediate: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _posSubscription?.cancel();
    _playingSubscription?.cancel();
    _mediaItemSubscription?.cancel();
    _rotationController.dispose();
    _lyricScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 监听 handler 变化以触发 UI 刷新
    final handler = ref.watch(playerHandlerProvider);
    final auth = ref.watch(authServiceProvider);

    // 每次 build 检查歌曲是否变化（切歌）
    final track = handler.currentTrack;
    if (track == null) return const Scaffold();

    final baseUrl = auth.baseUrl ?? '';
    final token = auth.token ?? '';
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 56, // 缩小高度
        leading: IconButton(
          icon: Icon(
            Icons.keyboard_arrow_down,
            size: 30,
            color: colorScheme.onSurface,
          ),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_hideLegacyTopActions) ...[
            IconButton(
              tooltip: '加入歌单',
              icon: Icon(
                Icons.playlist_add_rounded,
                color: colorScheme.onSurface,
                size: 24,
              ),
              onPressed: () => _showAddToPlaylistSheet(track),
            ),
            IconButton(
              tooltip: '歌词工具',
              icon: Icon(
                Icons.lyrics_outlined,
                color: colorScheme.onSurface,
                size: 23,
              ),
              onPressed: () => _showLyricsToolsSheet(track),
            ),
          ],
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert_rounded,
              color: colorScheme.onSurface,
              size: 26,
            ),
            offset: const Offset(0, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onSelected: (value) async {
              if (value == 'edit') {
                final currentTrack = ref
                    .read(playerHandlerProvider)
                    .currentTrack;
                if (currentTrack != null) {
                  TrackEditSheet.show(context, currentTrack);
                }
              } else if (value == 'lyrics') {
                _showLyricsToolsSheet(track);
              } else if (value == 'equalizer') {
                _showEqualizerSheet();
              } else if (value == 'delete') {
                _confirmDelete(context);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(
                      Icons.edit_note_rounded,
                      size: 22,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    const Text('编辑曲目信息'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'equalizer',
                child: Row(
                  children: [
                    Icon(
                      Icons.graphic_eq_rounded,
                      size: 22,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    const Text('调音'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'lyrics',
                child: Row(
                  children: [
                    Icon(
                      Icons.lyrics_outlined,
                      size: 22,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    const Text('歌词编辑'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline_rounded,
                      size: 22,
                      color: colorScheme.error,
                    ),
                    const SizedBox(width: 12),
                    const Text('删除歌曲'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
        centerTitle: true,
        title: Builder(
          builder: (context) {
            final currentTrack = handler.currentTrack ?? track;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  currentTrack.title,
                  maxLines: 2, // 允许两行
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  currentTrack.artist,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            );
          },
        ),
      ),
      body: SafeArea(
        child: GestureDetector(
          onHorizontalDragEnd: (details) async {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity.abs() < 240) {
              return;
            }
            if (velocity < 0) {
              await handler.skipToNext();
            } else {
              await handler.skipToPrevious();
            }
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isSmallScreen = constraints.maxHeight < 750;
              final isWideLayout =
                  constraints.maxWidth > 900 ||
                  (constraints.maxWidth > constraints.maxHeight &&
                      constraints.maxWidth > 720);
              final cdSize = isSmallScreen ? 140.0 : 180.0;
              // 适度缩小行高和字体
              _currentItemHeight = isSmallScreen ? 34.0 : 44.0;
              final spacingHeight = isSmallScreen ? 8.0 : 16.0;
              final activeFontSize = isSmallScreen ? 17.0 : 22.0;

              if (isWideLayout) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildCDDiskPremium(
                              handler.currentTrack ?? track,
                              baseUrl,
                              token,
                              colorScheme.primary,
                              cdSize * 1.45,
                              colorScheme,
                            ),
                            const SizedBox(height: 24),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 520),
                              child: _buildControlCard(
                                context,
                                handler,
                                handler.currentTrack ?? track,
                                colorScheme,
                                false,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 28),
                      Expanded(
                        flex: 4,
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: SizedBox(
                            height: constraints.maxHeight * 0.78,
                            child: _buildLyricViewPremium(
                              colorScheme,
                              activeFontSize + 2,
                              _currentItemHeight + 2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                mainAxisAlignment: MainAxisAlignment.start, // 置顶排列，消除顶部大空留
                children: [
                  SizedBox(height: spacingHeight), // 只留一小段间距
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start, // 置顶
                      children: [
                        const Spacer(),
                        // CD Disk with Glow Effect
                        _buildCDDiskPremium(
                          handler.currentTrack ?? track,
                          baseUrl,
                          token,
                          colorScheme.primary,
                          cdSize,
                          colorScheme,
                        ),
                        const Spacer(),
                        // Lyrics View - 固定显示7行
                        SizedBox(
                          height: _currentItemHeight * 7,
                          child: _buildLyricViewPremium(
                            colorScheme,
                            activeFontSize,
                            _currentItemHeight,
                          ),
                        ),
                        const Spacer(flex: 2), // 底部留出更多弹性空间
                      ],
                    ),
                  ),
                  // Bottom Control Card (Translucent, responsive theme)
                  _buildControlCard(
                    context,
                    handler,
                    handler.currentTrack ?? track,
                    colorScheme,
                    isSmallScreen,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCDDiskPremium(
    Track track,
    String baseUrl,
    String token,
    Color accentColor,
    double size,
    ColorScheme colorScheme,
  ) {
    return AnimatedBuilder(
      animation: _rotationController,
      builder: (context, child) {
        final coverSize = size * 0.72;
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: size + 28,
              height: size + 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    accentColor.withValues(alpha: 0.14),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Transform.rotate(
              angle: _rotationController.value * 2 * pi,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      colorScheme.surfaceContainerHigh,
                      colorScheme.surface.withValues(alpha: 0.98),
                      Colors.black,
                    ],
                    stops: const [0.0, 0.48, 1.0],
                  ),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.2),
                    width: 1.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.32),
                      blurRadius: 28,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: size * 0.88,
                      height: size * 0.88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colorScheme.onSurface.withValues(alpha: 0.06),
                        ),
                      ),
                    ),
                    Container(
                      width: size * 0.58,
                      height: size * 0.58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colorScheme.onSurface.withValues(alpha: 0.05),
                        ),
                      ),
                    ),
                    Container(
                      width: coverSize + 18,
                      height: coverSize + 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.2),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.2,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: coverSize,
                      height: coverSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colorScheme.onSurface.withValues(alpha: 0.08),
                        ),
                      ),
                      child: ClipOval(
                        child: CachedNetworkImage(
                          imageUrl:
                              '$baseUrl/api/tracks/${track.id}/cover?auth=$token',
                          cacheKey: 'cover_${track.id}',
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => Container(
                            color: colorScheme.surfaceContainerHighest,
                            child: Icon(
                              Icons.music_note_rounded,
                              color: colorScheme.primary,
                              size: size * 0.22,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              width: size * 0.2,
              height: size * 0.2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.surfaceContainer,
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.26),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: size * 0.05,
                  height: size * 0.05,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildControlCard(
    BuildContext context,
    MusicPlayerHandler handler,
    Track track,
    ColorScheme colorScheme,
    bool isSmall,
  ) {
    Widget modeButton({
      required IconData icon,
      required VoidCallback onTap,
      required bool active,
    }) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: active
                ? colorScheme.primary.withValues(alpha: 0.16)
                : colorScheme.surfaceContainerHigh.withValues(alpha: 0.44),
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            color: active ? colorScheme.primary : colorScheme.onSurfaceVariant,
            size: 19,
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.14),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StreamBuilder<Duration>(
                  stream: handler.player.positionStream,
                  builder: (context, snap) {
                    final pos = snap.data ?? Duration.zero;
                    final dur = Duration(seconds: track.duration.toInt());
                    final currentSeconds =
                        _draggingValue ?? pos.inSeconds.toDouble();

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Row(
                        children: [
                          Text(
                            _formatDuration(
                              Duration(seconds: currentSeconds.toInt()),
                            ),
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.82,
                              ),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 3.5,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6,
                                ),
                                activeTrackColor: colorScheme.primary,
                                inactiveTrackColor: colorScheme.onSurface
                                    .withValues(alpha: 0.1),
                                overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 16,
                                ),
                                trackShape: const RoundedRectSliderTrackShape(),
                              ),
                              child: Slider(
                                value: currentSeconds.clamp(
                                  0.0,
                                  dur.inSeconds.toDouble() > 0
                                      ? dur.inSeconds.toDouble()
                                      : 1.0,
                                ),
                                max: dur.inSeconds.toDouble() > 0
                                    ? dur.inSeconds.toDouble()
                                    : 1.0,
                                onChangeStart: (v) {
                                  setState(() {
                                    _draggingValue = v;
                                  });
                                },
                                onChanged: (v) {
                                  setState(() {
                                    _draggingValue = v;
                                  });
                                },
                                onChangeEnd: (v) {
                                  handler.seek(Duration(seconds: v.toInt()));
                                  setState(() {
                                    _draggingValue = null;
                                  });
                                },
                              ),
                            ),
                          ),
                          Text(
                            _formatDuration(dur),
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.82,
                              ),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    StreamBuilder<bool>(
                      stream: handler.player.shuffleModeEnabledStream,
                      builder: (context, snap) => modeButton(
                        icon: Icons.shuffle_rounded,
                        active: snap.data ?? false,
                        onTap: () => handler.toggleShuffle(),
                      ),
                    ),
                    InkWell(
                      onTap: () => handler.skipToPrevious(),
                      borderRadius: BorderRadius.circular(20),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(
                          Icons.skip_previous_rounded,
                          color: colorScheme.onSurface,
                          size: 34,
                        ),
                      ),
                    ),
                    StreamBuilder<PlayerState>(
                      stream: handler.player.playerStateStream,
                      builder: (context, snapshot) {
                        final playerState = snapshot.data;
                        final processingState = playerState?.processingState;
                        final playing = playerState?.playing ?? false;
                        final isLoading =
                            processingState == ProcessingState.buffering ||
                            processingState == ProcessingState.loading;

                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 72,
                              height: 72,
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 250),
                                opacity: isLoading ? 1.0 : 0.0,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colorScheme.primary,
                                  strokeCap: StrokeCap.round,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () =>
                                  playing ? handler.pause() : handler.play(),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: colorScheme.primary.withValues(
                                        alpha: 0.26,
                                      ),
                                      blurRadius: 14,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  playing
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  color: colorScheme.onPrimary,
                                  size: 34,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    InkWell(
                      onTap: () => handler.skipToNext(),
                      borderRadius: BorderRadius.circular(20),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(
                          Icons.skip_next_rounded,
                          color: colorScheme.onSurface,
                          size: 34,
                        ),
                      ),
                    ),
                    StreamBuilder<LoopMode>(
                      stream: handler.player.loopModeStream,
                      builder: (context, snap) {
                        final mode = snap.data ?? LoopMode.off;
                        return modeButton(
                          icon: mode == LoopMode.one
                              ? Icons.repeat_one_rounded
                              : Icons.repeat_rounded,
                          active: mode != LoopMode.off,
                          onTap: () => handler.toggleLoopMode(),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildBottomActionButton(
                        context,
                        icon: Icons.playlist_add_rounded,
                        onTap: () => _showAddToPlaylistSheet(track),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Consumer(
                        builder: (context, ref, child) {
                          final favoriteAsync = ref.watch(
                            favoriteStatusProvider(track.id),
                          );
                          return favoriteAsync.when(
                            data: (isFavorite) => _buildBottomActionButton(
                              context,
                              icon: isFavorite
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              highlighted: isFavorite,
                              onTap: () => _toggleFavorite(track),
                            ),
                            loading: () => _buildBottomActionButton(
                              context,
                              icon: Icons.favorite_border_rounded,
                              onTap: () {},
                            ),
                            error: (error, stackTrace) =>
                                _buildBottomActionButton(
                                  context,
                                  icon: Icons.favorite_border_rounded,
                                  onTap: () => _toggleFavorite(track),
                                ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildBottomActionButton(
                        context,
                        icon: Icons.timer_outlined,
                        onTap: _showSleepTimerSheet,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildBottomActionButton(
                        context,
                        icon: Icons.playlist_play_rounded,
                        onTap: () => GlobalPlaylist.show(context, ref),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLyricViewPremium(
    ColorScheme colorScheme,
    double activeFontSize,
    double itemHeight,
  ) {
    if (_parsedLyrics.isEmpty) {
      return Center(
        child: Text(
          '暂无歌词',
          style: TextStyle(
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            fontSize: 14,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // 更新视察高度以便下一次滚动计算

        return ListView.builder(
          controller: _lyricScrollController,
          itemCount: _parsedLyrics.length,
          physics: const BouncingScrollPhysics(),
          // top 2行，bottom 4行（总高7行），确保当前行（scroll=index*ih）锁定在界面第3行
          padding: EdgeInsets.only(top: itemHeight * 2, bottom: itemHeight * 4),
          itemExtent: itemHeight,
          itemBuilder: (context, i) {
            final isCurrent = i == _currentLyricIndex;
            return AnimatedOpacity(
              duration: const Duration(milliseconds: 140),
              opacity: isCurrent ? 1.0 : 0.3,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () async {
                  await ref
                      .read(playerHandlerProvider)
                      .seek(_parsedLyrics[i].time);
                  _syncLyricToPosition(
                    _parsedLyrics[i].time,
                    immediate: true,
                    forceScroll: true,
                  );
                },
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 140),
                  style: TextStyle(
                    color: isCurrent
                        ? colorScheme.onSurface
                        : colorScheme.onSurfaceVariant,
                    fontSize: isCurrent ? activeFontSize : activeFontSize - 4,
                    fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w400,
                    letterSpacing: isCurrent ? 0.5 : 0,
                  ),
                  textAlign: TextAlign.center,
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      _parsedLyrics[i].text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<_LyricLine> _parseLrc(String lrc, {Duration offset = Duration.zero}) {
    final List<_LyricLine> lines = [];
    final reg = RegExp(r'\[(\d+):(\d+\.?\d*)\](.*)');
    for (var line in lrc.split('\n')) {
      final match = reg.firstMatch(line);
      if (match != null) {
        final min = int.parse(match.group(1)!);
        final sec = double.parse(match.group(2)!);
        final text = match.group(3)!.trim();
        if (text.isNotEmpty) {
          final adjustedMilliseconds = max(
            0,
            (min * 60 * 1000 + sec * 1000).toInt() + offset.inMilliseconds,
          );
          lines.add(
            _LyricLine(
              time: Duration(milliseconds: adjustedMilliseconds),
              text: text,
            ),
          );
        }
      } else if (line.trim().isNotEmpty && !line.startsWith('[')) {
        lines.add(_LyricLine(time: Duration.zero, text: line.trim()));
      }
    }
    return lines;
  }

  Future<void> _showLyricsToolsSheet(Track track) async {
    final handler = ref.read(playerHandlerProvider);
    final repository = ref.read(trackRepositoryProvider);
    double offsetSeconds = handler.lyricOffsetForTrack(track.id) / 1000;
    bool isRefreshing = false;

    Future<void> applyOffset(StateSetter setSheetState, Duration offset) async {
      await handler.setLyricOffset(track.id, offset);
      if (!mounted) {
        return;
      }
      if (_rawLyrics != null) {
        setState(() {
          _parsedLyrics = _parseLrc(_rawLyrics!, offset: offset);
          _currentLyricIndex = -1;
        });
        _scheduleLyricResync(immediate: true);
      }
      setSheetState(() {
        offsetSeconds = offset.inMilliseconds / 1000;
      });
    }

    Future<void> searchLyrics(
      BuildContext sheetContext,
      StateSetter setSheetState,
      String source,
      String label,
    ) async {
      setSheetState(() {
        isRefreshing = true;
      });
      try {
        final lyrics = await repository.searchAndApplyLyrics(
          track,
          source: source,
        );
        if (lyrics == null || lyrics.trim().isEmpty) {
          if (mounted) {
            ModernToast.show(context, '没有找到可用歌词', isError: true);
          }
          return;
        }
        await handler.refreshLyricsForTrack(track.id);
        await _fetchLyrics(track.id);
        if (mounted) {
          ModernToast.show(context, '已从$label更新歌词');
        }
      } catch (error) {
        if (mounted) {
          ModernToast.show(context, '歌词更新失败: $error', isError: true);
        }
      } finally {
        if (sheetContext.mounted) {
          setSheetState(() {
            isRefreshing = false;
          });
        }
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final colorScheme = Theme.of(sheetContext).colorScheme;
        return StatefulBuilder(
          builder: (context, setSheetState) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '歌词工具',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '当前偏移 ${offsetSeconds >= 0 ? '+' : ''}${offsetSeconds.toStringAsFixed(1)} 秒',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                  Slider(
                    min: -3,
                    max: 3,
                    divisions: 60,
                    value: offsetSeconds.clamp(-3, 3),
                    onChanged: (value) {
                      setSheetState(() {
                        offsetSeconds = value;
                      });
                    },
                    onChangeEnd: (value) async {
                      await applyOffset(
                        setSheetState,
                        Duration(milliseconds: (value * 1000).round()),
                      );
                    },
                  ),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          await applyOffset(setSheetState, Duration.zero);
                        },
                        icon: const Icon(Icons.restart_alt_rounded),
                        label: const Text('重置偏移'),
                      ),
                      FilledButton.icon(
                        onPressed: isRefreshing
                            ? null
                            : () async {
                                await searchLyrics(
                                  sheetContext,
                                  setSheetState,
                                  'auto',
                                  '自动',
                                );
                              },
                        icon: isRefreshing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.auto_fix_high_rounded),
                        label: const Text('自动重搜'),
                      ),
                      OutlinedButton(
                        onPressed: isRefreshing
                            ? null
                            : () async {
                                await searchLyrics(
                                  sheetContext,
                                  setSheetState,
                                  'netease',
                                  '网易云',
                                );
                              },
                        child: const Text('网易云'),
                      ),
                      OutlinedButton(
                        onPressed: isRefreshing
                            ? null
                            : () async {
                                await searchLyrics(
                                  sheetContext,
                                  setSheetState,
                                  'qq',
                                  'QQ 音乐',
                                );
                              },
                        child: const Text('QQ 音乐'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final track = ref.read(playerHandlerProvider).currentTrack;
    if (track == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要从服务器永久删除歌曲 "${track.title}" 吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('确定删除'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        // 先停止播放并返回
        final handler = ref.read(playerHandlerProvider);
        await handler.stop();

        if (!context.mounted) return;
        context.pop(); // 退出详情页

        // 执行后端删除
        await ref.read(trackRepositoryProvider).deleteTracks([track.id]);

        if (!context.mounted) return;
        ModernToast.show(context, '歌曲已从服务器删除', icon: Icons.delete_forever);
      } catch (e) {
        if (!context.mounted) return;
        ModernToast.show(context, '删除失败: $e', isError: true);
      }
    }
  }

  Widget _buildBottomActionButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onTap,
    bool highlighted = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 46,
        decoration: BoxDecoration(
          color: highlighted
              ? colorScheme.primary.withValues(alpha: 0.16)
              : colorScheme.surfaceContainerHigh.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(16),
          boxShadow: highlighted
              ? [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 18,
          color: highlighted
              ? colorScheme.primary
              : colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Future<void> _toggleFavorite(Track track) async {
    try {
      final repo = ref.read(collectionRepositoryProvider);
      final isFavorite = await ref.read(
        favoriteStatusProvider(track.id).future,
      );
      if (isFavorite) {
        await repo.removeFavorite(track.id);
      } else {
        await repo.addFavorite(track.id);
      }
      ref.invalidate(favoriteStatusProvider(track.id));
      ref.invalidate(favoritesProvider);
      ref.invalidate(playStatsProvider);
      if (mounted) {
        ModernToast.show(
          context,
          isFavorite ? '已取消收藏' : '已加入收藏',
          icon: isFavorite
              ? Icons.heart_broken_outlined
              : Icons.favorite_rounded,
        );
      }
    } catch (e) {
      if (mounted) {
        ModernToast.show(context, '收藏操作失败: $e', isError: true);
      }
    }
  }

  Future<void> _showEqualizerSheet() async {
    final handler = ref.read(playerHandlerProvider);
    if (!handler.supportsEqualizer) {
      if (mounted) {
        ModernToast.show(context, '当前设备暂不支持调音', isError: true);
      }
      return;
    }

    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const EqualizerPage()));
  }

  Future<void> _showAddToPlaylistSheet(Track track) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => Consumer(
        builder: (context, ref, child) {
          final playlistsAsync = ref.watch(playlistsProvider);
          final colorScheme = Theme.of(context).colorScheme;

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: playlistsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, stackTrace) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    '加载歌单失败: $error',
                    style: TextStyle(color: colorScheme.error),
                  ),
                ),
                data: (playlists) => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '加入歌单',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (playlists.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          '还没有歌单，先去“我的”里新建一个吧。',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      )
                    else
                      SizedBox(
                        height: min(
                          playlists.length * 74.0,
                          MediaQuery.of(context).size.height * 0.48,
                        ),
                        child: ListView.separated(
                          itemCount: playlists.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            final playlist = playlists[index];
                            return ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              tileColor: colorScheme.surfaceContainerHigh,
                              leading: CircleAvatar(
                                backgroundColor: colorScheme.primaryContainer,
                                foregroundColor: colorScheme.primary,
                                child: const Icon(Icons.queue_music_rounded),
                              ),
                              title: Text(playlist.name),
                              subtitle: Text('${playlist.trackCount} 首歌曲'),
                              trailing: Icon(
                                Icons.add_rounded,
                                color: colorScheme.primary,
                              ),
                              onTap: () async {
                                await _addTrackToPlaylist(
                                  sheetContext,
                                  track,
                                  playlist,
                                );
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _addTrackToPlaylist(
    BuildContext sheetContext,
    Track track,
    UserPlaylist playlist,
  ) async {
    try {
      await ref
          .read(collectionRepositoryProvider)
          .addTrackToPlaylist(playlist.id, track.id);
      ref.invalidate(playlistsProvider);
      ref.invalidate(playlistDetailProvider(playlist.id));
      ref.invalidate(playStatsProvider);
      if (sheetContext.mounted) {
        Navigator.of(sheetContext).pop();
      }
      if (mounted) {
        ModernToast.show(context, '已加入 ${playlist.name}');
      }
    } catch (error) {
      if (mounted) {
        ModernToast.show(context, '加入歌单失败: $error', isError: true);
      }
    }
  }

  Future<void> _showSleepTimerSheet() async {
    final handler = ref.read(playerHandlerProvider);
    final options = <Duration, String>{
      const Duration(minutes: 10): '10 分钟',
      const Duration(minutes: 20): '20 分钟',
      const Duration(minutes: 30): '30 分钟',
      const Duration(hours: 1): '1 小时',
    };

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '定时停止播放',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (handler.sleepTimerRemaining != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '当前剩余 ${_formatDuration(handler.sleepTimerRemaining!)}',
                  ),
                ),
              ...options.entries.map(
                (entry) => ListTile(
                  leading: const Icon(Icons.timer_outlined),
                  title: Text(entry.value),
                  onTap: () {
                    handler.startSleepTimer(entry.key);
                    Navigator.of(context).pop();
                    ModernToast.show(this.context, '已设置${entry.value}后停止播放');
                  },
                ),
              ),
              if (handler.sleepTimerRemaining != null)
                ListTile(
                  leading: const Icon(Icons.timer_off_outlined),
                  title: const Text('取消定时'),
                  onTap: () {
                    handler.cancelSleepTimer();
                    Navigator.of(context).pop();
                    ModernToast.show(this.context, '已取消定时停止');
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.inSeconds < 0) return '0:00';
    final m = d.inMinutes.toString();
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _LyricLine {
  final Duration time;
  final String text;
  _LyricLine({required this.time, required this.text});
}
