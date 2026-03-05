import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_service.dart';
import '../../core/player/player_service.dart';

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
      builder: (context) {
        final queue = handler.trackQueue;
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '当前播放队列',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    '${queue.length} 首歌曲',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: queue.length,
                itemBuilder: (context, i) {
                  final t = queue[i];
                  final isCurrent = i == handler.currentIndex;
                  return ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        '$baseUrl/api/tracks/${t.id}/cover?auth=$token',
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 44,
                          height: 44,
                          color: colorScheme.surfaceContainerHigh,
                          child: const Icon(Icons.music_note, size: 24),
                        ),
                      ),
                    ),
                    title: Text(
                      t.title,
                      style: TextStyle(
                        color: isCurrent
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                        fontWeight: isCurrent
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      t.artist,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      handler.loadQueue(queue, startIndex: i);
                      Navigator.pop(context);
                    },
                    trailing: isCurrent
                        ? Icon(
                            Icons.volume_up_rounded,
                            color: colorScheme.primary,
                          )
                        : null,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
