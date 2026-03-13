import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music/core/repositories/track_repository.dart';
import 'package:music/core/auth/auth_service.dart';
import 'package:music/shared/widgets/modern_toast.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PlaylistDetailSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> playlist;
  const PlaylistDetailSheet({super.key, required this.playlist});

  static Future<void> show(
    BuildContext context,
    Map<String, dynamic> playlist,
  ) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PlaylistDetailSheet(playlist: playlist),
    );
  }

  @override
  ConsumerState<PlaylistDetailSheet> createState() =>
      _PlaylistDetailSheetState();
}

class _PlaylistDetailSheetState extends ConsumerState<PlaylistDetailSheet> {
  bool _isLoading = true;
  Map<String, dynamic>? _detail;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    final detail = await ref
        .read(trackRepositoryProvider)
        .getPlaylistDetail(widget.playlist['id'].toString());
    if (mounted) {
      setState(() {
        _detail = detail;
        _isLoading = false;
      });
    }
  }

  Future<void> _downloadSong(Map<String, dynamic> song) async {
    try {
      await ref
          .read(trackRepositoryProvider)
          .downloadNeteaseSong(song['id'].toString(), 'exhigh');
      if (mounted) {
        ModernToast.show(
          context,
          '已加入下载队列: ${song['title']}',
          icon: Icons.download_done,
        );
      }
    } catch (e) {
      if (mounted) {
        ModernToast.show(context, '下载失败: $e', isError: true);
      }
    }
  }

  Future<void> _downloadAll() async {
    if (_detail == null || _detail!['trackIds'] == null) return;
    try {
      final List<String> ids = (_detail!['trackIds'] as List)
          .map((e) => e.toString())
          .toList();
      await ref
          .read(trackRepositoryProvider)
          .downloadNeteasePlaylist(
            _detail!['id'].toString(),
            _detail!['name'] ?? '歌单下载',
            ids,
            'exhigh',
          );
      if (mounted) {
        Navigator.pop(context);
        ModernToast.show(context, '已启动全量下载任务', icon: Icons.download_done);
      }
    } catch (e) {
      if (mounted) {
        ModernToast.show(context, '启动下载失败: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenHeight = MediaQuery.of(context).size.height;
    final auth = ref.watch(authServiceProvider);
    final baseUrl = auth.baseUrl ?? '';
    final token = auth.token ?? '';

    String proxyCover(String rawUrl) =>
        '$baseUrl/api/proxy-image?url=${Uri.encodeComponent(rawUrl)}&auth=$token';

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: screenHeight * 0.85,
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.7),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(
              color: colorScheme.onSurface.withValues(alpha: 0.1),
              width: 0.5,
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: CachedNetworkImage(
                        imageUrl: proxyCover(widget.playlist['coverUrl'] ?? ''),
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: colorScheme.surfaceContainerHighest,
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.playlist_play, size: 40),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.playlist['name'] ?? '歌单详情',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_detail?['trackCount'] ?? widget.playlist['trackCount'] ?? 0} 首歌曲',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '歌曲列表',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _isLoading ? null : _downloadAll,
                      style: TextButton.styleFrom(
                        backgroundColor: colorScheme.onSurface.withValues(alpha: 0.1),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text(
                        '全部下载',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 32),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: _detail?['tracks']?.length ?? 0,
                        itemBuilder: (context, index) {
                          final s = _detail!['tracks'][index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest.withValues(
                                alpha:
                                0.3,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                    imageUrl: proxyCover(s['coverUrl'] ?? ''),
                                    width: 44,
                                    height: 44,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      color: colorScheme.surfaceContainerHighest,
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) =>
                                        Container(
                                          color: colorScheme.surfaceContainerHighest,
                                          child: const Icon(
                                            Icons.music_note,
                                            size: 20,
                                          ),
                                        ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s['title'] ?? '未知',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        s['artist'] ?? '未知',
                                        style: TextStyle(
                                          color: colorScheme.onSurfaceVariant,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.download_rounded,
                                    size: 20,
                                  ),
                                  onPressed: () => _downloadSong(s),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
