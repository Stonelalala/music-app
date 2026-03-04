import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_service.dart';
import '../../core/player/player_service.dart';
import '../../shared/theme/app_theme.dart';

class PlayerPage extends ConsumerWidget {
  const PlayerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handler = ref.watch(playerHandlerProvider);
    final auth = ref.watch(authServiceProvider);
    final track = handler.currentTrack;

    if (track == null) return const Scaffold();

    final baseUrl = auth.baseUrl ?? '';
    final token = auth.token ?? '';

    return Scaffold(
      backgroundColor: AppTheme.bgBase,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, size: 30),
          onPressed: () => context.pop(),
        ),
        title: Column(
          children: [
            const Text(
              'PLAYING FROM PLAYLIST',
              style: TextStyle(
                color: AppTheme.accent,
                fontSize: 10,
                letterSpacing: 1,
              ),
            ),
            Text(
              track.album,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [IconButton(icon: const Icon(Icons.cast), onPressed: () {})],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(height: 8),
                      // Album Art
                      Center(
                        child: Container(
                          width: constraints.maxHeight * 0.38,
                          height: constraints.maxHeight * 0.38,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                blurRadius: 40,
                                offset: const Offset(0, 20),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(32),
                            child: Image.network(
                              '$baseUrl/api/tracks/${track.id}/cover?auth=$token',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: AppTheme.surfaceElevated,
                                child: const Icon(
                                  Icons.music_note,
                                  color: AppTheme.accent,
                                  size: 80,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Title & Artist
                      Column(
                        children: [
                          Text(
                            track.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            track.artist,
                            style: const TextStyle(
                              color: AppTheme.accent,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Progress Bar
                      StreamBuilder<Duration>(
                        stream: handler.player.positionStream,
                        builder: (context, snap) {
                          final pos = snap.data ?? Duration.zero;
                          final dur = Duration(seconds: track.duration.toInt());
                          return Column(
                            children: [
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 3,
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 5,
                                  ),
                                  activeTrackColor: AppTheme.accent,
                                  inactiveTrackColor: AppTheme.border,
                                  thumbColor: Colors.white,
                                  overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 10,
                                  ),
                                ),
                                child: Slider(
                                  value: pos.inSeconds.toDouble().clamp(
                                    0,
                                    dur.inSeconds.toDouble(),
                                  ),
                                  max: dur.inSeconds.toDouble() > 0
                                      ? dur.inSeconds.toDouble()
                                      : 1.0,
                                  onChanged: (v) => handler.seek(
                                    Duration(seconds: v.toInt()),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatDuration(pos),
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                    Text(
                                      _formatDuration(dur),
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 12),

                      // Controls
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.shuffle,
                              color: AppTheme.textSecondary,
                              size: 20,
                            ),
                            onPressed: () {},
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.skip_previous,
                              size: 32,
                              color: AppTheme.textPrimary,
                            ),
                            onPressed: () => handler.skipToPrevious(),
                          ),
                          StreamBuilder<bool>(
                            stream: handler.player.playingStream,
                            builder: (context, snap) {
                              final playing = snap.data ?? false;
                              return GestureDetector(
                                onTap: () =>
                                    playing ? handler.pause() : handler.play(),
                                child: Container(
                                  width: 64,
                                  height: 64,
                                  decoration: const BoxDecoration(
                                    color: AppTheme.accent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    playing ? Icons.pause : Icons.play_arrow,
                                    color: AppTheme.bgBase,
                                    size: 36,
                                  ),
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.skip_next,
                              size: 32,
                              color: AppTheme.textPrimary,
                            ),
                            onPressed: () => handler.skipToNext(),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.repeat,
                              color: AppTheme.textSecondary,
                              size: 20,
                            ),
                            onPressed: () {},
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Bottom Actions
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          color: AppTheme.surfaceElevated.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildBottomAction(Icons.lyrics_outlined, 'LYRICS'),
                            _buildDivider(),
                            _buildBottomAction(Icons.playlist_play, 'QUEUE'),
                            _buildDivider(),
                            _buildBottomAction(Icons.share_outlined, 'SHARE'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
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

  Widget _buildBottomAction(IconData icon, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppTheme.textSecondary, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(height: 20, width: 1, color: AppTheme.border);
  }
}
