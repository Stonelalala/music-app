import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/http/api_client.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/modern_toast.dart';

class MusicDownloaderSheet extends ConsumerStatefulWidget {
  const MusicDownloaderSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: const MusicDownloaderSheet(),
      ),
    );
  }

  @override
  ConsumerState<MusicDownloaderSheet> createState() =>
      _MusicDownloaderSheetState();
}

class _MusicDownloaderSheetState extends ConsumerState<MusicDownloaderSheet> {
  final TextEditingController _urlCtrl = TextEditingController();
  bool _isParsing = false;
  bool _isDownloading = false;

  Map<String, dynamic>? _parsedData;
  String _selectedLevel = 'exhigh';

  final List<Map<String, String>> _levels = [
    {'id': 'standard', 'name': '标准 (128k)'},
    {'id': 'higher', 'name': '较高 (192k)'},
    {'id': 'exhigh', 'name': '极高 (320k)'},
    {'id': 'lossless', 'name': '无损 (FLAC)'},
    {'id': 'hires', 'name': 'Hi-Res (高解析)'},
  ];

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _parseUrl() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _isParsing = true;
      _parsedData = null;
    });

    try {
      final endpoint = url.contains('qq.com')
          ? '/api/qq/parse'
          : '/api/netease/parse';
      final res = await ref
          .read(apiClientProvider)
          .post(endpoint, data: {'url': url});

      if (!mounted) return;

      if (res['success'] == true) {
        setState(() {
          // If it's a song, we take the first one
          if (res['type'] == 'song' &&
              res['data'] is List &&
              (res['data'] as List).isNotEmpty) {
            _parsedData = (res['data'] as List).first as Map<String, dynamic>;
          } else {
            // Placeholder for playlists or other types
            ModernToast.show(context, '目前仅支持单曲解析下载', icon: Icons.info_outline);
          }
        });
      } else {
        throw res['error'] ?? '解析失败';
      }
    } catch (e) {
      if (mounted) {
        ModernToast.show(
          context,
          '解析出错: $e',
          isError: true,
          icon: Icons.error_outline,
        );
      }
    } finally {
      if (mounted) setState(() => _isParsing = false);
    }
  }

  Future<void> _startDownload() async {
    if (_parsedData == null) return;

    setState(() => _isDownloading = true);
    try {
      final isQQ = _urlCtrl.text.contains('qq.com');
      final endpoint = isQQ ? '/api/qq/download' : '/api/netease/download';

      await ref
          .read(apiClientProvider)
          .post(
            endpoint,
            data: {
              'id': _parsedData!['neteaseId'] ?? _parsedData!['id'],
              'level': _selectedLevel,
            },
          );

      if (mounted) {
        Navigator.pop(context);
        ModernToast.show(context, '已加入下载队列', icon: Icons.download_done_rounded);
      }
    } catch (e) {
      if (mounted) {
        ModernToast.show(
          context,
          '下载失败: $e',
          isError: true,
          icon: Icons.error_outline,
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '音乐下载器',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _urlCtrl,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: '粘贴网易云或QQ音乐链接...',
              hintStyle: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
              filled: true,
              fillColor: AppTheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              suffixIcon: _isParsing
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      icon: const Icon(Icons.bolt, color: AppTheme.accent),
                      onPressed: _parseUrl,
                    ),
            ),
            onSubmitted: (_) => _parseUrl(),
          ),

          if (_parsedData != null) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    '${ref.read(apiClientProvider).baseUrl}/api/proxy-image?url=${Uri.encodeComponent(_parsedData!['coverUrl'] ?? '')}',
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (_, error, stackTrace) => Container(
                      width: 80,
                      height: 80,
                      color: AppTheme.surface,
                      child: const Icon(
                        Icons.music_note,
                        color: AppTheme.accent,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _parsedData!['title'] ?? '未知标题',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _parsedData!['artist'] ?? '未知艺术家',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              '选择下载音质',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _levels.map((lvl) {
                final isSelected = _selectedLevel == lvl['id'];
                return ChoiceChip(
                  label: Text(lvl['name']!),
                  selected: isSelected,
                  onSelected: (val) {
                    if (val) setState(() => _selectedLevel = lvl['id']!);
                  },
                  backgroundColor: AppTheme.surface,
                  selectedColor: AppTheme.accent.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: isSelected
                        ? AppTheme.accent
                        : AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: isSelected ? AppTheme.accent : AppTheme.border,
                      width: 0.5,
                    ),
                  ),
                  showCheckmark: false,
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isDownloading ? null : _startDownload,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isDownloading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      '开始下载并加入库',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
