import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import '../../core/auth/auth_service.dart';
import '../../core/player/player_service.dart';
import '../../core/repositories/collection_repository.dart';
import '../../shared/models/track.dart';
import '../../shared/widgets/track_action_sheet.dart';
import '../../shared/widgets/global_playlist.dart';
import '../library/widgets/track_edit_sheet.dart';
import '../../core/repositories/track_repository.dart';
import '../../shared/widgets/modern_toast.dart';
import '../my/collection_providers.dart';

class PlayerPage extends ConsumerStatefulWidget {
  const PlayerPage({super.key});

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage>
    with SingleTickerProviderStateMixin {
  final ScrollController _lyricScrollController = ScrollController();
  late AnimationController _rotationController;
  List<_LyricLine> _parsedLyrics = [];
  int _currentLyricIndex = -1;
  StreamSubscription? _posSubscription;
  StreamSubscription? _playingSubscription;
  String? _lastTrackId;

  // 进度条拖动优化：记录本地拖动值
  double? _draggingValue;

  // 记录当前布局信息以便滚动计算
  double _currentItemHeight = 0;

  @override
  void initState() {
    super.initState();
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
        _updateLyricHighlight(pos);
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
  }

  @override
  void didUpdateWidget(PlayerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkAndFetchLyrics();
  }

  void _checkAndFetchLyrics() {
    final handler = ref.read(playerHandlerProvider);
    final track = handler.currentTrack;
    if (track != null && track.id != _lastTrackId) {
      debugPrint('Track changed in PlayerPage: ${track.title}');
      _lastTrackId = track.id;
      setState(() {
        _parsedLyrics = [];
        _currentLyricIndex = -1;
      });
      _fetchLyrics(track.id);
    }
  }

  Future<void> _fetchLyrics(String trackId) async {
    final lyrics = await ref.read(playerHandlerProvider).getLyrics(trackId);
    if (mounted && lyrics != null) {
      setState(() {
        _parsedLyrics = _parseLrc(lyrics);
      });
    }
  }

  void _updateLyricHighlight(Duration pos) {
    int index = -1;
    for (int i = 0; i < _parsedLyrics.length; i++) {
      if (pos >= _parsedLyrics[i].time) {
        index = i;
      } else {
        break;
      }
    }

    if (index != _currentLyricIndex && index != -1) {
      if (mounted) {
        setState(() {
          _currentLyricIndex = index;
        });
        _scrollToCurrentLyric();
      }
    }
  }

  void _scrollToCurrentLyric() {
    if (_lyricScrollController.hasClients && 
        _currentLyricIndex != -1 && 
        _currentItemHeight > 0) {
      
      // 设置 targetScroll 为当前行索引乘以行高
      // 配合 ListView 的 top padding (itemHeight * 2)，当前行将固定在界面第 3 行
      final targetScroll = _currentLyricIndex * _currentItemHeight;
      
      _lyricScrollController.animateTo(
        targetScroll,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _posSubscription?.cancel();
    _playingSubscription?.cancel();
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
    _checkAndFetchLyrics();
    
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
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert_rounded,
              color: colorScheme.onSurface,
              size: 26,
            ),
            offset: const Offset(0, 56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (value) async {
              if (value == 'edit') {
                final currentTrack = ref.read(playerHandlerProvider).currentTrack;
                if (currentTrack != null) {
                  TrackEditSheet.show(context, currentTrack);
                }
              } else if (value == 'actions') {
                final currentTrack = ref.read(playerHandlerProvider).currentTrack;
                if (currentTrack != null) {
                  TrackActionSheet.show(context, ref, currentTrack);
                }
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
                    const Text('歌词信息编辑'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'actions',
                child: Row(
                  children: [
                    Icon(
                      Icons.more_horiz_rounded,
                      size: 22,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    const Text('更多操作'),
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
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer Glow
            Container(
              width: size + 20,
              height: size + 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.2),
                    blurRadius: 60,
                    spreadRadius: 10,
                  ),
                ],
              ),
            ),
            // The Disk
            Transform.rotate(
              angle: _rotationController.value * 2 * pi,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black,
                  border: Border.all(
                    color: colorScheme.onSurface.withValues(alpha: 0.1),
                    width: 2,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: '$baseUrl/api/tracks/${track.id}/cover?auth=$token',
                      cacheKey: 'cover_${track.id}',
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => Container(
                        color: colorScheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.music_note_rounded,
                          color: colorScheme.primary,
                          size: size * 0.28,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Center Pin
            Container(
              width: size * 0.18,
              height: size * 0.18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.surface,
                border: Border.all(
                  color: colorScheme.onSurface.withValues(alpha: 0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.5),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: size * 0.05,
                  height: size * 0.05,
                  decoration: BoxDecoration(
                    color: accentColor,
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
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.08)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 20.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Progress Bar
                StreamBuilder<Duration>(
                  stream: handler.player.positionStream,
                  builder: (context, snap) {
                    final pos = snap.data ?? Duration.zero;
                    final dur = Duration(seconds: track.duration.toInt());
                    
                    // 如果正在拖动，使用拖动时的值，否则使用播放器当前进度
                    final currentSeconds = _draggingValue ?? pos.inSeconds.toDouble();
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Row(
                        children: [
                          Text(
                            _formatDuration(Duration(seconds: currentSeconds.toInt())),
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6,
                                ),
                                activeTrackColor: colorScheme.primary,
                                inactiveTrackColor: colorScheme.onSurface.withValues(alpha: 0.1),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                                // 移除 Slider 内部的边距，使其与文字贴合更紧密
                                trackShape: const RoundedRectSliderTrackShape(),
                              ),
                              child: Slider(
                                value: currentSeconds.clamp(
                                  0.0,
                                  dur.inSeconds.toDouble() > 0 ? dur.inSeconds.toDouble() : 1.0,
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
                              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                // Main Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    StreamBuilder<bool>(
                      stream: handler.player.shuffleModeEnabledStream,
                      builder: (context, snap) => IconButton(
                        icon: Icon(
                          Icons.shuffle,
                          color: (snap.data ?? false)
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                          size: 22,
                        ),
                        onPressed: () => handler.toggleShuffle(),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.skip_previous_rounded,
                        color: colorScheme.onSurface,
                        size: 36,
                      ),
                      onPressed: () => handler.skipToPrevious(),
                    ),
                    StreamBuilder<PlayerState>(
                      stream: handler.player.playerStateStream,
                      builder: (context, snapshot) {
                        final playerState = snapshot.data;
                        final processingState = playerState?.processingState;
                        final playing = playerState?.playing ?? false;

                        // 是否处于加载或缓冲状态
                        final isLoading = processingState == ProcessingState.buffering ||
                                         processingState == ProcessingState.loading;

                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            // 固定 72x72 的空间，防止加载环出现/消失时 UI 整体发生位移
                            SizedBox(
                              width: 72,
                              height: 72,
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 300),
                                opacity: isLoading ? 1.0 : 0.0,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colorScheme.primary,
                                  strokeCap: StrokeCap.round,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => playing ? handler.pause() : handler.play(),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: colorScheme.primary.withValues(alpha: 0.4),
                                      blurRadius: 16,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  color: colorScheme.onPrimary,
                                  size: 36,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.skip_next_rounded,
                        color: colorScheme.onSurface,
                        size: 36,
                      ),
                      onPressed: () => handler.skipToNext(),
                    ),
                    StreamBuilder<LoopMode>(
                      stream: handler.player.loopModeStream,
                      builder: (context, snap) {
                        final mode = snap.data ?? LoopMode.off;
                        return IconButton(
                          icon: Icon(
                            mode == LoopMode.one
                                ? Icons.repeat_one
                                : Icons.repeat,
                            color: mode != LoopMode.off
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                            size: 22,
                          ),
                          onPressed: () => handler.toggleLoopMode(),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
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
                            error: (error, stackTrace) => _buildBottomActionButton(
                              context,
                              icon: Icons.favorite_border_rounded,
                              onTap: () => _toggleFavorite(track),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildBottomActionButton(
                        context,
                        icon: Icons.timer_outlined,
                        onTap: _showSleepTimerSheet,
                      ),
                    ),
                    const SizedBox(width: 10),
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
          padding: EdgeInsets.only(
            top: itemHeight * 2,
            bottom: itemHeight * 4,
          ),
          itemExtent: itemHeight,
          itemBuilder: (context, i) {
            final isCurrent = i == _currentLyricIndex;
            return AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: isCurrent ? 1.0 : 0.3,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () async {
                  await ref.read(playerHandlerProvider).seek(_parsedLyrics[i].time);
                },
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
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

  List<_LyricLine> _parseLrc(String lrc) {
    final List<_LyricLine> lines = [];
    final reg = RegExp(r'\[(\d+):(\d+\.?\d*)\](.*)');
    for (var line in lrc.split('\n')) {
      final match = reg.firstMatch(line);
      if (match != null) {
        final min = int.parse(match.group(1)!);
        final sec = double.parse(match.group(2)!);
        final text = match.group(3)!.trim();
        if (text.isNotEmpty) {
          lines.add(
            _LyricLine(
              time: Duration(
                milliseconds: (min * 60 * 1000 + sec * 1000).toInt(),
              ),
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
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: highlighted
              ? colorScheme.primary.withValues(alpha: 0.16)
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: highlighted
                ? colorScheme.primary.withValues(alpha: 0.4)
                : colorScheme.outlineVariant.withValues(alpha: 0.16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: highlighted
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleFavorite(Track track) async {
    try {
      final repo = ref.read(collectionRepositoryProvider);
      final isFavorite = await ref.read(favoriteStatusProvider(track.id).future);
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
          icon: isFavorite ? Icons.heart_broken_outlined : Icons.favorite_rounded,
        );
      }
    } catch (e) {
      if (mounted) {
        ModernToast.show(context, '收藏操作失败: $e', isError: true);
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
