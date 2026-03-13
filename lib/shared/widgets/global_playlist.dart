import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_service.dart';
import '../../core/player/player_service.dart';
import '../../shared/models/track.dart';

class GlobalPlaylist {
  static void show(BuildContext context, WidgetRef ref) {
    final handler = ref.read(playerHandlerProvider);
    final auth = ref.read(authServiceProvider);
    final baseUrl = auth.baseUrl ?? '';
    final token = auth.token ?? '';
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DefaultTabController(
        length: 2,
        child: AnimatedBuilder(
          animation: handler,
          builder: (context, child) {
            final queue = handler.trackQueue;
            final history = handler.playHistory;
            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '播放列表',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        '队列 ${queue.length} 首',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                TabBar(
                  tabs: const [
                    Tab(text: '当前队列'),
                    Tab(text: '历史记录'),
                  ],
                  labelColor: colorScheme.primary,
                  unselectedLabelColor: colorScheme.onSurfaceVariant,
                ),
                const Divider(height: 1),
                Expanded(
                  child: TabBarView(
                    children: [
                      _TrackList(
                        tracks: queue,
                        currentIndex: handler.currentIndex,
                        baseUrl: baseUrl,
                        token: token,
                        colorScheme: colorScheme,
                        onTap: (index) async {
                          await handler.loadQueue(queue, startIndex: index);
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                      ),
                      _TrackList(
                        tracks: history,
                        currentIndex: -1,
                        baseUrl: baseUrl,
                        token: token,
                        colorScheme: colorScheme,
                        onTap: (index) async {
                          await handler.playTrackPreservingQueue(history[index]);
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                        emptyText: '暂无播放历史',
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TrackList extends StatelessWidget {
  const _TrackList({
    required this.tracks,
    required this.currentIndex,
    required this.baseUrl,
    required this.token,
    required this.colorScheme,
    required this.onTap,
    this.emptyText = '暂无歌曲',
  });

  final List<Track> tracks;
  final int currentIndex;
  final String baseUrl;
  final String token;
  final ColorScheme colorScheme;
  final Future<void> Function(int index) onTap;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (tracks.isEmpty) {
      return Center(
        child: Text(
          emptyText,
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      );
    }

    return ListView.builder(
      itemCount: tracks.length,
      itemBuilder: (context, i) {
        final track = tracks[i];
        final isCurrent = i == currentIndex;
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              '$baseUrl/api/tracks/${track.id}/cover?auth=$token',
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              errorBuilder: (_, error, stackTrace) => Container(
                width: 44,
                height: 44,
                color: colorScheme.surfaceContainerHigh,
                child: const Icon(Icons.music_note, size: 24),
              ),
            ),
          ),
          title: Text(
            track.title,
            style: TextStyle(
              color: isCurrent ? colorScheme.primary : colorScheme.onSurface,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            track.artist,
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => onTap(i),
          trailing: isCurrent
              ? Icon(
                  Icons.volume_up_rounded,
                  color: colorScheme.primary,
                )
              : null,
        );
      },
    );
  }
}
