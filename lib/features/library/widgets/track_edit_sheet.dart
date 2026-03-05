import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/http/api_client.dart';
import '../../../shared/models/track.dart';
import '../../../shared/theme/app_theme.dart';
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
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: TrackEditSheet(track: track, onSaved: onSaved),
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
  late TextEditingController _lyricsCtrl;
  bool _isSaving = false;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.track.title);
    _artistCtrl = TextEditingController(text: widget.track.artist);
    _albumCtrl = TextEditingController(text: widget.track.album);

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
              'lyrics': _lyricsCtrl.text.trim(),
            },
          );

      if (mounted) {
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

  Future<void> _searchMetadata() async {
    final query = '${_titleCtrl.text} ${_artistCtrl.text}'.trim();
    if (query.isEmpty) return;

    setState(() => _isSearching = true);
    try {
      final res = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>(
            '/api/search-metadata?q=${Uri.encodeComponent(query)}',
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
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                '选择匹配的数据',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: results.length,
                separatorBuilder: (_, __) =>
                    const Divider(color: AppTheme.border, height: 1),
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
                              errorBuilder: (_, __, ___) => Container(
                                width: 40,
                                height: 40,
                                color: AppTheme.surface,
                                child: const Icon(
                                  Icons.music_note,
                                  color: AppTheme.accent,
                                ),
                              ),
                            ),
                          )
                        : const Icon(Icons.music_note),
                    title: Text(
                      item['title'] ?? '未知标题',
                      style: const TextStyle(color: AppTheme.textPrimary),
                    ),
                    subtitle: Text(
                      '${item['artist'] ?? ''} - ${item['album'] ?? ''}',
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() {
                        if (item['title'] != null)
                          _titleCtrl.text = item['title'];
                        if (item['artist'] != null)
                          _artistCtrl.text = item['artist'];
                        if (item['album'] != null)
                          _albumCtrl.text = item['album'];
                      });
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
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 16, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '编辑曲目信息',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
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
                  style: TextButton.styleFrom(foregroundColor: AppTheme.accent),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.textSecondary),
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
                  _buildTextField('标题', _titleCtrl, isRequired: true),
                  const SizedBox(height: 16),
                  _buildTextField('艺术家', _artistCtrl),
                  const SizedBox(height: 16),
                  _buildTextField('专辑', _albumCtrl),
                  const SizedBox(height: 16),
                  _buildTextField('歌词 (LRC)', _lyricsCtrl, maxLines: 6),
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
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.white,
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

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool isRequired = false,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (isRequired)
              const Text(
                ' *',
                style: TextStyle(color: AppTheme.errorColor, fontSize: 13),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppTheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.accent, width: 2),
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
