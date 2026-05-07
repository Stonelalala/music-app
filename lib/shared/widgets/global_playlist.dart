import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_service.dart';
import '../../core/player/player_service.dart';
import '../../core/repositories/collection_repository.dart';
import '../../features/my/collection_providers.dart';
import '../../shared/models/track.dart';
import 'modern_toast.dart';

class GlobalPlaylist {
  static void show(BuildContext context, WidgetRef ref) {
    final handler = ref.read(playerHandlerProvider);
    final auth = ref.read(authServiceProvider);
    final baseUrl = auth.baseUrl ?? '';
    final token = auth.token ?? '';
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.76,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.surfaceContainerHigh.withValues(alpha: 0.96),
                  colorScheme.surfaceContainer.withValues(alpha: 0.94),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.18),
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.14),
                  blurRadius: 28,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: DefaultTabController(
              length: 2,
              child: AnimatedBuilder(
                animation: handler,
                builder: (context, child) {
                  final queue = handler.trackQueue;
                  final history = handler.playHistory;
                  return SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                      child: Column(
                        children: [
                          Container(
                            width: 42,
                            height: 4,
                            decoration: BoxDecoration(
                              color: colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.24,
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHigh
                                  .withValues(alpha: 0.82),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: colorScheme.outlineVariant.withValues(
                                  alpha: 0.16,
                                ),
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '\u64ad\u653e\u961f\u5217',
                                            style: TextStyle(
                                              color: colorScheme.onSurface,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 20,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    _SheetIconAction(
                                      tooltip:
                                          '\u4fdd\u5b58\u961f\u5217\u4e3a\u6b4c\u5355',
                                      icon: Icons
                                          .playlist_add_check_circle_outlined,
                                      onPressed: queue.isEmpty
                                          ? null
                                          : () => _saveQueueAsPlaylist(
                                              sheetContext,
                                              ref,
                                              queue,
                                            ),
                                    ),
                                    const SizedBox(width: 8),
                                    _SheetIconAction(
                                      tooltip: '\u6e05\u7a7a\u961f\u5217',
                                      icon: Icons.delete_sweep_outlined,
                                      destructive: true,
                                      onPressed: queue.isEmpty
                                          ? null
                                          : () async {
                                              await handler.clearQueue();
                                              if (sheetContext.mounted) {
                                                Navigator.of(
                                                  sheetContext,
                                                ).pop();
                                              }
                                            },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHigh
                                  .withValues(alpha: 0.46),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: colorScheme.outlineVariant.withValues(
                                  alpha: 0.14,
                                ),
                              ),
                            ),
                            child: TabBar(
                              dividerColor: Colors.transparent,
                              indicator: BoxDecoration(
                                color: colorScheme.primary.withValues(
                                  alpha: 0.16,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              indicatorSize: TabBarIndicatorSize.tab,
                              labelColor: colorScheme.primary,
                              unselectedLabelColor:
                                  colorScheme.onSurfaceVariant,
                              labelStyle: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                              tabs: [
                                Tab(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('\u5f53\u524d\u961f\u5217'),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${queue.length}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Tab(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('\u64ad\u653e\u5386\u53f2'),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${history.length}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: TabBarView(
                              children: [
                                _QueueList(
                                  tracks: queue,
                                  currentIndex: handler.currentIndex,
                                  baseUrl: baseUrl,
                                  token: token,
                                  colorScheme: colorScheme,
                                  onTap: (index) async {
                                    await handler.loadQueue(
                                      queue,
                                      startIndex: index,
                                    );
                                    if (sheetContext.mounted) {
                                      Navigator.of(sheetContext).pop();
                                    }
                                  },
                                  onReorder: handler.moveQueueItem,
                                  onRemove: handler.removeQueueItemAt,
                                ),
                                _HistoryList(
                                  tracks: history,
                                  baseUrl: baseUrl,
                                  token: token,
                                  colorScheme: colorScheme,
                                  onTap: (index) async {
                                    await handler.playTrackPreservingQueue(
                                      history[index],
                                    );
                                    if (sheetContext.mounted) {
                                      Navigator.of(sheetContext).pop();
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Future<void> _saveQueueAsPlaylist(
    BuildContext context,
    WidgetRef ref,
    List<Track> queue,
  ) async {
    final controller = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('\u4fdd\u5b58\u5f53\u524d\u961f\u5217'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '\u8f93\u5165\u6b4c\u5355\u540d\u79f0',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('\u53d6\u6d88'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('\u4fdd\u5b58'),
          ),
        ],
      ),
    );

    if (created != true) {
      return;
    }

    final name = controller.text.trim();
    if (name.isEmpty) {
      if (context.mounted) {
        ModernToast.show(
          context,
          '\u6b4c\u5355\u540d\u79f0\u4e0d\u80fd\u4e3a\u7a7a',
          isError: true,
        );
      }
      return;
    }

    try {
      await ref
          .read(collectionRepositoryProvider)
          .createPlaylistWithTracks(
            name,
            queue.map((track) => track.id).toList(growable: false),
            coverTrackId: queue.isEmpty ? null : queue.first.id,
          );
      ref.invalidate(playlistsProvider);
      ref.invalidate(playStatsProvider);
      if (context.mounted) {
        ModernToast.show(
          context,
          '\u961f\u5217\u5df2\u4fdd\u5b58\u4e3a\u6b4c\u5355',
        );
      }
    } catch (error) {
      if (context.mounted) {
        ModernToast.show(
          context,
          '\u4fdd\u5b58\u5931\u8d25: $error',
          isError: true,
        );
      }
    }
  }
}

class _SheetIconAction extends StatelessWidget {
  const _SheetIconAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.destructive = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = destructive ? colorScheme.error : colorScheme.onSurface;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: destructive
            ? colorScheme.errorContainer.withValues(alpha: 0.72)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onPressed,
          child: SizedBox(
            width: 46,
            height: 46,
            child: Icon(icon, color: foreground, size: 22),
          ),
        ),
      ),
    );
  }
}

class _EmptyPlaylistState extends StatelessWidget {
  const _EmptyPlaylistState({
    required this.icon,
    required this.title,
    required this.message,
    required this.colorScheme,
  });

  final IconData icon;
  final String title;
  final String message;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.14),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: colorScheme.primary, size: 28),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QueueList extends StatelessWidget {
  const _QueueList({
    required this.tracks,
    required this.currentIndex,
    required this.baseUrl,
    required this.token,
    required this.colorScheme,
    required this.onTap,
    required this.onReorder,
    required this.onRemove,
  });

  final List<Track> tracks;
  final int currentIndex;
  final String baseUrl;
  final String token;
  final ColorScheme colorScheme;
  final Future<void> Function(int index) onTap;
  final Future<void> Function(int oldIndex, int newIndex) onReorder;
  final Future<void> Function(int index) onRemove;

  @override
  Widget build(BuildContext context) {
    if (tracks.isEmpty) {
      return _EmptyPlaylistState(
        icon: Icons.queue_music_rounded,
        title: '\u6682\u65e0\u64ad\u653e\u961f\u5217',
        message:
            '\u53ef\u4ee5\u4ece\u4efb\u610f\u6b4c\u5355\u6216\u66f2\u76ee\u9875\u9762\u5c06\u6b4c\u66f2\u52a0\u5165\u961f\u5217\u3002',
        colorScheme: colorScheme,
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      buildDefaultDragHandles: false,
      itemCount: tracks.length,
      onReorder: (oldIndex, newIndex) async {
        final targetIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
        await onReorder(oldIndex, targetIndex);
      },
      itemBuilder: (context, index) {
        final track = tracks[index];
        final isCurrent = index == currentIndex;
        return Container(
          key: ValueKey('${track.id}_$index'),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: isCurrent
                ? colorScheme.primary.withValues(alpha: 0.12)
                : colorScheme.surfaceContainerHigh.withValues(alpha: 0.56),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isCurrent
                  ? colorScheme.primary.withValues(alpha: 0.34)
                  : colorScheme.outlineVariant.withValues(alpha: 0.12),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => onTap(index),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        _CoverThumb(
                          track: track,
                          baseUrl: baseUrl,
                          token: token,
                          colorScheme: colorScheme,
                        ),
                        if (isCurrent)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: colorScheme.surface,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                Icons.graphic_eq_rounded,
                                size: 10,
                                color: colorScheme.onPrimary,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isCurrent) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withValues(
                                  alpha: 0.14,
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '\u5f53\u524d\u64ad\u653e',
                                style: TextStyle(
                                  color: colorScheme.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surface.withValues(alpha: 0.48),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: '\u79fb\u51fa\u961f\u5217',
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints.tightFor(
                              width: 34,
                              height: 34,
                            ),
                            iconSize: 18,
                            onPressed: () => onRemove(index),
                            icon: Icon(
                              Icons.remove_circle_outline_rounded,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          ReorderableDragStartListener(
                            index: index,
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                Icons.drag_handle_rounded,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({
    required this.tracks,
    required this.baseUrl,
    required this.token,
    required this.colorScheme,
    required this.onTap,
  });

  final List<Track> tracks;
  final String baseUrl;
  final String token;
  final ColorScheme colorScheme;
  final Future<void> Function(int index) onTap;

  @override
  Widget build(BuildContext context) {
    if (tracks.isEmpty) {
      return _EmptyPlaylistState(
        icon: Icons.history_toggle_off_rounded,
        title: '\u6682\u65e0\u64ad\u653e\u5386\u53f2',
        message:
            '\u64ad\u653e\u8fc7\u7684\u66f2\u76ee\u4f1a\u5728\u8fd9\u91cc\u663e\u793a\uff0c\u53ef\u4ee5\u76f4\u63a5\u4ece\u5386\u53f2\u91cd\u65b0\u64ad\u653e\u3002',
        colorScheme: colorScheme,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        final track = tracks[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.56),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.12),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => onTap(index),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Row(
                  children: [
                    _CoverThumb(
                      track: track,
                      baseUrl: baseUrl,
                      token: token,
                      colorScheme: colorScheme,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CoverThumb extends StatelessWidget {
  const _CoverThumb({
    required this.track,
    required this.baseUrl,
    required this.token,
    required this.colorScheme,
  });

  final Track track;
  final String baseUrl;
  final String token;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.network(
        '$baseUrl/api/tracks/${track.id}/cover?auth=$token',
        width: 52,
        height: 52,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: 52,
          height: 52,
          color: colorScheme.surfaceContainerHigh,
          child: const Icon(Icons.music_note_rounded, size: 22),
        ),
      ),
    );
  }
}
