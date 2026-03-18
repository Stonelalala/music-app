import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_service.dart';
import '../../core/player/player_service.dart';
import '../../core/repositories/collection_repository.dart';
import '../../features/my/collection_providers.dart';
import '../../shared/models/playlist.dart';
import '../../shared/models/track.dart';
import 'modern_toast.dart';
import 'track_action_sheet.dart';

class PlaylistDetailSheet extends ConsumerStatefulWidget {
  const PlaylistDetailSheet({super.key, required this.playlistId});

  final String playlistId;

  static Future<void> show(BuildContext context, String playlistId) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => PlaylistDetailSheet(playlistId: playlistId),
    );
  }

  @override
  ConsumerState<PlaylistDetailSheet> createState() =>
      _PlaylistDetailSheetState();
}

class _PlaylistDetailSheetState extends ConsumerState<PlaylistDetailSheet> {
  List<Track> _tracks = const [];
  String? _customCoverTrackId;
  String _syncSignature = '';
  bool _isSaving = false;

  String? get _displayCoverTrackId {
    if (_customCoverTrackId != null && _customCoverTrackId!.isNotEmpty) {
      return _customCoverTrackId;
    }
    if (_tracks.isEmpty) {
      return null;
    }
    return _tracks.first.id;
  }

  void _syncFromDetail(PlaylistDetail detail) {
    final signature = [
      detail.id,
      detail.customCoverTrackId ?? '',
      detail.tracks.map((track) => track.id).join(','),
    ].join('|');

    if (_syncSignature == signature) {
      return;
    }

    _syncSignature = signature;
    _tracks = List<Track>.from(detail.tracks);
    _customCoverTrackId = detail.customCoverTrackId;
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(playlistDetailProvider(widget.playlistId));

    return detailAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.all(24),
        child: Text('加载失败: $error'),
      ),
      data: (detail) {
        _syncFromDetail(detail);
        final auth = ref.watch(authServiceProvider);
        final colorScheme = Theme.of(context).colorScheme;
        final pageContext = context;
        final coverTrackId = _displayCoverTrackId;
        final coverUrl = coverTrackId == null
            ? null
            : '${auth.baseUrl}/api/tracks/$coverTrackId/cover?auth=${auth.token}';
        final coverHeaders = auth.token == null
            ? null
            : {'Authorization': 'Bearer ${auth.token}'};

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHigh.withValues(
                      alpha: 0.86,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _PlaylistCover(
                            coverUrl: coverUrl,
                            headers: coverHeaders,
                            cacheKey: coverTrackId == null
                                ? null
                                : 'cover_$coverTrackId',
                            onTap: _tracks.isEmpty || _isSaving
                                ? null
                                : _showCoverPicker,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  detail.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _PlaylistMetaChip(
                                      icon: Icons.queue_music_rounded,
                                      label: '${_tracks.length} 首歌曲',
                                    ),
                                    _PlaylistMetaChip(
                                      icon: _customCoverTrackId == null
                                          ? Icons.auto_awesome_rounded
                                          : Icons.image_rounded,
                                      label: _customCoverTrackId == null
                                          ? '默认封面'
                                          : '自定义封面',
                                      highlighted: _customCoverTrackId != null,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _tracks.isEmpty || _isSaving
                                  ? null
                                  : () async {
                                      await ref
                                          .read(playerHandlerProvider)
                                          .loadQueue(_tracks, startIndex: 0);
                                      if (!pageContext.mounted) {
                                        return;
                                      }
                                      Navigator.of(pageContext).pop();
                                      pageContext.push('/player');
                                    },
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: const Text('播放歌单'),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _tracks.isEmpty || _isSaving
                                  ? null
                                  : _showCoverPicker,
                              icon: const Icon(Icons.image_outlined),
                              label: Text(
                                _customCoverTrackId == null ? '设置封面' : '更换封面',
                              ),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (_tracks.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 12),
                    child: Text(
                      '歌单里还没有歌曲，先去加几首吧。',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  )
                else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.16,
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.tips_and_updates_outlined,
                          size: 18,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '右侧拖拽手柄可排序，封面和移除操作在每首歌右侧的操作区。',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ReorderableListView.builder(
                      shrinkWrap: true,
                      buildDefaultDragHandles: false,
                      itemCount: _tracks.length,
                      onReorder: _isSaving
                          ? (oldIndex, newIndex) {}
                          : _reorderTracks,
                      itemBuilder: (context, index) {
                        final track = _tracks[index];
                        final isCoverTrack = _displayCoverTrackId == track.id;
                        return _PlaylistTrackTile(
                          key: ValueKey('${track.id}_$index'),
                          track: track,
                          isCoverTrack: isCoverTrack,
                          enabled: !_isSaving,
                          onTap: () async {
                            await ref
                                .read(playerHandlerProvider)
                                .loadQueue(_tracks, startIndex: index);
                            if (!pageContext.mounted) {
                              return;
                            }
                            Navigator.of(pageContext).pop();
                            pageContext.push('/player');
                          },
                          onLongPress: () =>
                              TrackActionSheet.show(context, ref, track),
                          onSetCover: () => _applyCustomCover(track.id),
                          onRemove: () => _removeTrack(track),
                          authHeaders: coverHeaders,
                          coverUrl:
                              '${auth.baseUrl}/api/tracks/${track.id}/cover?auth=${auth.token}',
                          dragHandle: ReorderableDragStartListener(
                            index: index,
                            child: Icon(
                              Icons.drag_handle_rounded,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _reorderTracks(int oldIndex, int newIndex) async {
    if (_isSaving) {
      return;
    }

    final targetIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
    if (targetIndex == oldIndex) {
      return;
    }

    final previousTracks = List<Track>.from(_tracks);
    final updatedTracks = List<Track>.from(_tracks);
    final item = updatedTracks.removeAt(oldIndex);
    updatedTracks.insert(targetIndex, item);

    setState(() {
      _tracks = updatedTracks;
      _isSaving = true;
    });

    try {
      await ref
          .read(collectionRepositoryProvider)
          .reorderPlaylistTracks(
            widget.playlistId,
            updatedTracks.map((track) => track.id).toList(growable: false),
            coverTrackId: _customCoverTrackId,
          );
      ref.invalidate(playlistDetailProvider(widget.playlistId));
      ref.invalidate(playlistsProvider);
    } catch (error) {
      setState(() {
        _tracks = previousTracks;
      });
      if (mounted) {
        ModernToast.show(context, '排序保存失败: $error', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _removeTrack(Track track) async {
    if (_isSaving) {
      return;
    }

    final previousTracks = List<Track>.from(_tracks);
    final previousCustomCoverTrackId = _customCoverTrackId;
    final updatedTracks = List<Track>.from(_tracks)
      ..removeWhere((item) => item.id == track.id);
    final removedCustomCover = _customCoverTrackId == track.id;

    setState(() {
      _tracks = updatedTracks;
      if (removedCustomCover) {
        _customCoverTrackId = null;
      }
      _isSaving = true;
    });

    try {
      await ref
          .read(collectionRepositoryProvider)
          .removeTrackFromPlaylist(widget.playlistId, track.id);
      if (removedCustomCover) {
        await ref
            .read(collectionRepositoryProvider)
            .updatePlaylist(widget.playlistId, coverTrackId: '');
      }
      ref.invalidate(playlistDetailProvider(widget.playlistId));
      ref.invalidate(playlistsProvider);
      ref.invalidate(playStatsProvider);
      if (mounted) {
        ModernToast.show(context, '已从歌单移除');
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _tracks = previousTracks;
        _customCoverTrackId = previousCustomCoverTrackId;
      });
      ModernToast.show(context, '移除失败: $error', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _showCoverPicker() async {
    if (_tracks.isEmpty || _isSaving) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        final colorScheme = Theme.of(sheetContext).colorScheme;
        final auth = ref.read(authServiceProvider);
        final headers = auth.token == null
            ? null
            : {'Authorization': 'Bearer ${auth.token}'};
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHigh.withValues(
                      alpha: 0.82,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.wallpaper_rounded,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '选择歌单封面',
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '可以跟随默认首曲，也可以从歌单现有歌曲里挑一张更合适的封面。',
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 12,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _CoverSelectionTile(
                  title: '使用默认封面',
                  subtitle: '跟随歌单当前第一首歌曲',
                  selected: _customCoverTrackId == null,
                  leading: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.54,
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: colorScheme.primary,
                    ),
                  ),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _applyCustomCover(null);
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  '从歌单歌曲中选择',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _tracks.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final track = _tracks[index];
                      final isCurrent = _displayCoverTrackId == track.id;
                      final coverUrl = auth.baseUrl == null
                          ? null
                          : '${auth.baseUrl}/api/tracks/${track.id}/cover?auth=${auth.token}';
                      return _CoverSelectionTile(
                        title: track.title,
                        subtitle: track.artist,
                        selected: isCurrent,
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: coverUrl == null
                              ? _CoverSelectionFallback(
                                  colorScheme: colorScheme,
                                  index: index,
                                )
                              : CachedNetworkImage(
                                  imageUrl: coverUrl,
                                  httpHeaders: headers,
                                  cacheKey: 'cover_${track.id}',
                                  width: 54,
                                  height: 54,
                                  fit: BoxFit.cover,
                                  errorWidget: (context, url, error) =>
                                      _CoverSelectionFallback(
                                        colorScheme: colorScheme,
                                        index: index,
                                      ),
                                ),
                        ),
                        trailingLabel: '第 ${index + 1} 首',
                        onTap: () async {
                          Navigator.of(sheetContext).pop();
                          await _applyCustomCover(track.id);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _applyCustomCover(String? trackId) async {
    if (_isSaving) {
      return;
    }

    final previousCustomCoverTrackId = _customCoverTrackId;
    setState(() {
      _customCoverTrackId = trackId;
      _isSaving = true;
    });

    try {
      await ref
          .read(collectionRepositoryProvider)
          .updatePlaylist(widget.playlistId, coverTrackId: trackId ?? '');
      ref.invalidate(playlistDetailProvider(widget.playlistId));
      ref.invalidate(playlistsProvider);
      if (mounted) {
        ModernToast.show(context, trackId == null ? '已恢复默认封面' : '歌单封面已更新');
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _customCoverTrackId = previousCustomCoverTrackId);
      ModernToast.show(context, '设置封面失败: $error', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}

class _PlaylistCover extends StatelessWidget {
  const _PlaylistCover({
    required this.coverUrl,
    required this.headers,
    required this.cacheKey,
    this.onTap,
  });

  final String? coverUrl;
  final Map<String, String>? headers;
  final String? cacheKey;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: coverUrl == null
            ? Container(
                width: 108,
                height: 108,
                color: colorScheme.surfaceContainerHighest,
                child: Icon(
                  Icons.queue_music_rounded,
                  color: colorScheme.primary,
                  size: 36,
                ),
              )
            : CachedNetworkImage(
                imageUrl: coverUrl!,
                httpHeaders: headers,
                cacheKey: cacheKey,
                width: 108,
                height: 108,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => Container(
                  width: 108,
                  height: 108,
                  color: colorScheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.queue_music_rounded,
                    color: colorScheme.primary,
                    size: 36,
                  ),
                ),
              ),
      ),
    );
  }
}

class _PlaylistMetaChip extends StatelessWidget {
  const _PlaylistMetaChip({
    required this.icon,
    required this.label,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: highlighted
            ? colorScheme.primary.withValues(alpha: 0.14)
            : colorScheme.surface.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: highlighted
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: highlighted
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverSelectionTile extends StatelessWidget {
  const _CoverSelectionTile({
    required this.title,
    required this.subtitle,
    required this.leading,
    required this.selected,
    required this.onTap,
    this.trailingLabel,
  });

  final String title;
  final String subtitle;
  final Widget leading;
  final bool selected;
  final VoidCallback onTap;
  final String? trailingLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: selected
          ? colorScheme.primary.withValues(alpha: 0.12)
          : colorScheme.surfaceContainerHigh.withValues(alpha: 0.58),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (trailingLabel != null) ...[
                    Text(
                      trailingLabel!,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: selected
                          ? colorScheme.primary
                          : colorScheme.surface.withValues(alpha: 0.48),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      selected
                          ? Icons.check_rounded
                          : Icons.arrow_forward_ios_rounded,
                      size: selected ? 16 : 12,
                      color: selected
                          ? colorScheme.onPrimary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoverSelectionFallback extends StatelessWidget {
  const _CoverSelectionFallback({
    required this.colorScheme,
    required this.index,
  });

  final ColorScheme colorScheme;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Text(
          '${index + 1}',
          style: TextStyle(
            color: colorScheme.primary,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _PlaylistTrackTile extends StatelessWidget {
  const _PlaylistTrackTile({
    super.key,
    required this.track,
    required this.isCoverTrack,
    required this.enabled,
    required this.onTap,
    required this.onLongPress,
    required this.onSetCover,
    required this.onRemove,
    required this.authHeaders,
    required this.coverUrl,
    required this.dragHandle,
  });

  final Track track;
  final bool isCoverTrack;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onSetCover;
  final VoidCallback onRemove;
  final Map<String, String>? authHeaders;
  final String coverUrl;
  final Widget dragHandle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      key: key,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: enabled ? onTap : null,
        onLongPress: enabled ? onLongPress : null,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: coverUrl,
                  httpHeaders: authHeaders,
                  cacheKey: 'cover_${track.id}',
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => Container(
                    width: 56,
                    height: 56,
                    color: colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.music_note_rounded,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
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
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${track.artist} · ${track.album}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    if (isCoverTrack) ...[
                      const SizedBox(height: 6),
                      _PlaylistMetaChip(
                        icon: Icons.image_rounded,
                        label: '当前封面',
                        highlighted: true,
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.surface.withValues(alpha: 0.42),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: isCoverTrack ? '当前封面' : '设为封面',
                      onPressed: enabled ? onSetCover : null,
                      icon: Icon(
                        isCoverTrack
                            ? Icons.image_rounded
                            : Icons.image_outlined,
                        color: isCoverTrack
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    IconButton(
                      tooltip: '移除',
                      onPressed: enabled ? onRemove : null,
                      icon: const Icon(Icons.remove_circle_outline_rounded),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              dragHandle,
            ],
          ),
        ),
      ),
    );
  }
}
