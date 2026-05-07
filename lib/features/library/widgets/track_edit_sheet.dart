import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/http/api_client.dart';
import '../../../shared/models/track.dart';
import '../../../core/player/player_service.dart';
import '../../../shared/widgets/modern_toast.dart';

class TrackEditSheet extends ConsumerStatefulWidget {
  final Track track;
  final VoidCallback? onSaved;

  const TrackEditSheet({super.key, required this.track, this.onSaved});

  static Future<void> show(
    BuildContext context,
    Track track, {
    VoidCallback? onSaved,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(
          top: false,
          child: FractionallySizedBox(
            heightFactor: 0.84,
            child: TrackEditSheet(track: track, onSaved: onSaved),
          ),
        ),
      ),
    );
  }

  @override
  ConsumerState<TrackEditSheet> createState() => _TrackEditSheetState();
}

class _TrackEditSheetState extends ConsumerState<TrackEditSheet> {
  late TextEditingController _titleCtrl;
  late TextEditingController _artistCtrl;
  late TextEditingController _albumCtrl;
  late TextEditingController _yearCtrl;
  late TextEditingController _lyricsCtrl;
  bool _isSaving = false;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.track.title);
    _artistCtrl = TextEditingController(text: widget.track.artist);
    _albumCtrl = TextEditingController(text: widget.track.album);
    _yearCtrl = TextEditingController(text: widget.track.year ?? '');

    // Lyrics are fetched separately as they might be large
    _lyricsCtrl = TextEditingController();
    _loadLyrics();
  }

  Future<void> _loadLyrics() async {
    try {
      final res = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>('/api/tracks/${widget.track.id}/lyrics');
      if (res['success'] == true && res['lyrics'] != null) {
        if (mounted) {
          _lyricsCtrl.text = res['lyrics'] as String;
        }
      }
    } catch (_) {
      // Ignore
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _artistCtrl.dispose();
    _albumCtrl.dispose();
    _yearCtrl.dispose();
    _lyricsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) return;

    setState(() => _isSaving = true);
    try {
      await ref
          .read(apiClientProvider)
          .post(
            '/api/tracks/${widget.track.id}',
            data: {
              'title': _titleCtrl.text.trim(),
              'artist': _artistCtrl.text.trim(),
              'album': _albumCtrl.text.trim(),
              'year': _yearCtrl.text.trim().isEmpty
                  ? null
                  : _yearCtrl.text.trim(),
              'lyrics': _lyricsCtrl.text.trim(),
            },
          );

      if (mounted) {
        // 创建更新后的 Track 对象
        final updatedTrack = Track(
          id: widget.track.id,
          title: _titleCtrl.text.trim(),
          artist: _artistCtrl.text.trim(),
          album: _albumCtrl.text.trim(),
          year: _yearCtrl.text.trim().isEmpty ? null : _yearCtrl.text.trim(),
          extension: widget.track.extension,
          duration: widget.track.duration,
          size: widget.track.size,
          scrapeStatus: 1, // 修改后状态通常设为已抓取/成功
          hasLyrics: _lyricsCtrl.text.trim().isNotEmpty,
          filepath: widget.track.filepath,
          relativePath: widget.track.relativePath,
        );

        // 通知播放服务更新当前状态
        ref.read(playerHandlerProvider).refreshTrackMetadata(updatedTrack);

        ModernToast.show(context, '保存成功', icon: Icons.check_circle_outline);
        widget.onSaved?.call();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ModernToast.show(
          context,
          '保存失败: $e',
          isError: true,
          icon: Icons.error_outline,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _scrapeSource = 'netease';

  Future<void> _searchMetadata() async {
    final query = '${_titleCtrl.text} ${_artistCtrl.text}'.trim();
    if (query.isEmpty) return;

    setState(() => _isSearching = true);
    try {
      final res = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>(
            '/api/search-metadata?q=${Uri.encodeComponent(query)}&source=$_scrapeSource',
          );

      if (!mounted) return;

      final results = res['results'] as List<dynamic>? ?? [];
      if (results.isEmpty) {
        ModernToast.show(context, '未找到匹配的元数据。', icon: Icons.search_off_rounded);
        return;
      }

      _showSearchResults(results.cast<Map<String, dynamic>>());
    } catch (e) {
      if (mounted) {
        ModernToast.show(
          context,
          '搜索失败: $e',
          isError: true,
          icon: Icons.error_outline,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _showSearchResults(List<Map<String, dynamic>> results) {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.18),
        ),
      ),
      builder: (ctx) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                '选择匹配的数据',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: results.length,
                separatorBuilder: (_, index) => Divider(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.18),
                  height: 1,
                ),
                itemBuilder: (ctx, i) {
                  final item = results[i];
                  return ListTile(
                    leading: item['coverUrl'] != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.network(
                              '${ref.read(apiClientProvider).baseUrl}/api/proxy-image?url=${Uri.encodeComponent(item['coverUrl'])}',
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              errorBuilder: (_, error, stackTrace) => Container(
                                width: 40,
                                height: 40,
                                color: colorScheme.surfaceContainerHighest,
                                child: Icon(
                                  Icons.music_note,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ),
                          )
                        : Icon(Icons.music_note, color: colorScheme.primary),
                    title: Text(
                      item['title'] ?? '未知标题',
                      style: TextStyle(color: colorScheme.onSurface),
                    ),
                    subtitle: Text(
                      '${item['artist'] ?? ''} - ${item['album'] ?? ''}',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() {
                        if (item['title'] != null) {
                          _titleCtrl.text = item['title'];
                        }
                        if (item['artist'] != null) {
                          _artistCtrl.text = item['artist'];
                        }
                        if (item['album'] != null) {
                          _albumCtrl.text = item['album'];
                        }
                        if (item['year'] != null) {
                          _yearCtrl.text = item['year'].toString();
                        }
                      });

                      // 选中数据后异步抓取歌词
                      _fetchLyricsForSelection(item);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '编辑曲目信息',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _isSearching ? null : _searchMetadata,
                  icon: _isSearching
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_download_outlined, size: 18),
                  label: const Text('从网络刮削'),
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.primary,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: colorScheme.onSurfaceVariant),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 刮削设置 (Scrape Source)
                  Text(
                    '刮削设置 (选择来源)',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildSourceChip('网易云', 'netease'),
                      const SizedBox(width: 8),
                      _buildSourceChip('QQ音乐', 'qq'),
                      const SizedBox(width: 8),
                      _buildSourceChip('iTunes', 'itunes'),
                    ],
                  ),
                  const SizedBox(height: 20),

                  _buildTextField('标题', _titleCtrl, isRequired: true),
                  const SizedBox(height: 16),
                  _buildTextField('艺术家', _artistCtrl),
                  const SizedBox(height: 16),
                  _buildTextField('专辑', _albumCtrl),
                  const SizedBox(height: 16),
                  _buildTextField('年份', _yearCtrl),
                  const SizedBox(height: 16),
                  _buildTextField(
                    '歌词 (LRC)',
                    _lyricsCtrl,
                    maxLines: 6,
                    suffix: _isFetchingLyrics
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Footer
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  minimumSize: const Size(double.infinity, 50),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        '保存更改',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isFetchingLyrics = false;

  Future<void> _fetchLyricsForSelection(Map<String, dynamic> item) async {
    setState(() => _isFetchingLyrics = true);
    try {
      final title = item['title'] ?? '';
      final artist = item['artist'] ?? '';
      final id = item['id']?.toString() ?? '';

      final url =
          '/api/lyrics/search-web?title=${Uri.encodeComponent(title)}&artist=${Uri.encodeComponent(artist)}&source=$_scrapeSource&id=$id';

      final res = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>(url);
      if (res['success'] == true &&
          res['lyrics'] != null &&
          res['lyrics'].toString().isNotEmpty) {
        if (mounted) {
          setState(() {
            _lyricsCtrl.text = res['lyrics'] as String;
          });
          ModernToast.show(context, '歌词抓取成功', icon: Icons.lyrics_outlined);
        }
      } else {
        if (mounted) {
          ModernToast.show(
            context,
            '未找到该曲目的歌词',
            icon: Icons.warning_amber_rounded,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ModernToast.show(context, '歌词抓取失败: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isFetchingLyrics = false);
      }
    }
  }

  Widget _buildSourceChip(String label, String value) {
    final isSelected = _scrapeSource == value;
    final colorScheme = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _scrapeSource = value);
        }
      },
      selectedColor: colorScheme.primary.withValues(alpha: 0.16),
      labelStyle: TextStyle(
        color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected
              ? colorScheme.primary
              : colorScheme.outlineVariant.withValues(alpha: 0.42),
        ),
      ),
      showCheckmark: false,
      backgroundColor: colorScheme.surfaceContainerHigh.withValues(alpha: 0.3),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool isRequired = false,
    int maxLines = 1,
    Widget? suffix,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (isRequired)
              Text(
                ' *',
                style: TextStyle(color: colorScheme.error, fontSize: 13),
              ),
            const Spacer(),
            if (suffix != null) ...[suffix],
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: TextStyle(color: colorScheme.onSurface, fontSize: 15),
          decoration: InputDecoration(
            filled: true,
            fillColor: colorScheme.surfaceContainerHigh.withValues(alpha: 0.55),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.42),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.42),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colorScheme.primary, width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: maxLines > 1 ? 16 : 0,
            ),
          ),
        ),
      ],
    );
  }
}
