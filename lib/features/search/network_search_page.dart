import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/repositories/track_repository.dart';
import '../../shared/models/network_track.dart';
import 'network_search_provider.dart';

class NetworkSearchPage extends ConsumerStatefulWidget {
  const NetworkSearchPage({super.key});

  @override
  ConsumerState<NetworkSearchPage> createState() => _NetworkSearchPageState();
}

class _NetworkSearchPageState extends ConsumerState<NetworkSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchController.text = ref.read(networkSearchQueryProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    ref.read(networkSearchQueryProvider.notifier).state = value.trim();
  }

  void _handleDownload(NetworkTrack track, String level) async {
    final repo = ref.read(trackRepositoryProvider);
    try {
      if (track.source == 'qq') {
        await repo.downloadQQMusicSong(track.id, level);
      } else if (track.source == 'kugou') {
        await repo.downloadKugouSong(track.id, level);
      } else if (track.source == 'kuwo') {
        await repo.downloadKuwoSong(track.id, level);
      } else {
        await repo.downloadNeteaseSong(track.id, level);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已下发下载任务：${track.title}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('下载失败：$e')),
        );
      }
    }
  }

  void _showDownloadOptions(NetworkTrack track) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('标准音质 (Standard)'),
                onTap: () {
                  Navigator.pop(ctx);
                  _handleDownload(track, 'standard');
                },
              ),
              ListTile(
                title: const Text('极高音质 (Exhigh - 320k)'),
                onTap: () {
                  Navigator.pop(ctx);
                  _handleDownload(track, 'exhigh');
                },
              ),
              ListTile(
                title: const Text('无损音质 (Lossless / FLAC)'),
                onTap: () {
                  Navigator.pop(ctx);
                  _handleDownload(track, 'lossless');
                },
              ),
              ListTile(
                title: const Text('Hi-Res'),
                onTap: () {
                  Navigator.pop(ctx);
                  _handleDownload(track, 'hires');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(networkSearchQueryProvider);
    final source = ref.watch(networkSearchSourceProvider);
    final resultsAsync = ref.watch(networkSearchResultsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    onPressed: () => context.pop(),
                  ),
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _focusNode,
                        textAlignVertical: TextAlignVertical.center,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.cloud_download_outlined, size: 20),
                          hintText: '全网搜索歌曲...',
                          hintStyle: TextStyle(
                            color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 20),
                                  onPressed: () {
                                    _searchController.clear();
                                    _onSearch('');
                                    setState(() {});
                                  },
                                )
                              : null,
                        ),
                        onChanged: (val) => setState(() {}),
                        onSubmitted: _onSearch,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Source Filters
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('网易云'),
                      selected: source == 'netease',
                      onSelected: (selected) {
                        if (selected) ref.read(networkSearchSourceProvider.notifier).state = 'netease';
                      },
                      showCheckmark: false,
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('QQ音乐'),
                      selected: source == 'qq',
                      onSelected: (selected) {
                        if (selected) ref.read(networkSearchSourceProvider.notifier).state = 'qq';
                      },
                      showCheckmark: false,
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('酷狗'),
                      selected: source == 'kugou',
                      onSelected: (selected) {
                        if (selected) ref.read(networkSearchSourceProvider.notifier).state = 'kugou';
                      },
                      showCheckmark: false,
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('酷我'),
                      selected: source == 'kuwo',
                      onSelected: (selected) {
                        if (selected) ref.read(networkSearchSourceProvider.notifier).state = 'kuwo';
                      },
                      showCheckmark: false,
                    ),
                  ],
                ),
              ),
            ),

            // Results List
            Expanded(
              child: query.isEmpty
                  ? Center(child: Text('输入关键词以搜索网络音源', style: TextStyle(color: colorScheme.onSurfaceVariant)))
                  : resultsAsync.when(
                      data: (results) {
                        if (results.isEmpty) {
                          return const Center(child: Text('没有匹配的结果'));
                        }
                        return ListView.builder(
                          padding: const EdgeInsets.only(bottom: 20),
                          itemCount: results.length,
                          itemBuilder: (context, index) {
                            final track = results[index];
                            return ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: track.coverUrl != null
                                    ? Image.network(
                                        track.coverUrl!,
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => _buildFallbackCover(colorScheme),
                                      )
                                    : _buildFallbackCover(colorScheme),
                              ),
                              title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text(
                                '${track.artist} · ${track.album}${track.year != null ? ' · ${track.year}' : ''}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    (track.source ?? '').toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: colorScheme.outline,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.download_rounded),
                                    color: colorScheme.primary,
                                    onPressed: () => _showDownloadOptions(track),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, stack) => Center(child: Text('搜索出错：$err')),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackCover(ColorScheme colorScheme) {
    return Container(
      width: 50,
      height: 50,
      color: colorScheme.surfaceContainerHighest,
      child: Icon(Icons.music_note, color: colorScheme.primary),
    );
  }
}
