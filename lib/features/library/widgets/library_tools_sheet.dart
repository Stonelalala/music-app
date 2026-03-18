import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/http/api_client.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/modern_toast.dart';

class LibraryToolsSheet extends ConsumerStatefulWidget {
  final BuildContext navContext;

  const LibraryToolsSheet({super.key, required this.navContext});

  static Future<void> show(BuildContext context) {
    // 先保存外部 context（Library 页面的 context），用于后续导航
    final navContext = context;
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => LibraryToolsSheet(navContext: navContext),
    );
  }

  @override
  ConsumerState<LibraryToolsSheet> createState() => _LibraryToolsSheetState();
}

class _LibraryToolsSheetState extends ConsumerState<LibraryToolsSheet> {
  bool _organizeByArtist = true;
  bool _organizeByAlbum = true;
  bool _isProcessing = false;

  Future<void> _startRename() async {
    setState(() => _isProcessing = true);
    try {
      await ref.read(apiClientProvider).post('/api/batch-rename', data: {});
      if (mounted) {
        Navigator.pop(context);
        ModernToast.show(
          context,
          '已启动批量重命名任务',
          icon: Icons.check_circle_rounded,
        );
      }
    } catch (e) {
      if (mounted) {
        ModernToast.show(
          context,
          '启动失败: $e',
          isError: true,
          icon: Icons.error_outline_rounded,
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _startOrganize() async {
    setState(() => _isProcessing = true);
    try {
      await ref
          .read(apiClientProvider)
          .post(
            '/api/tracks/organize',
            data: {
              'levels': [
                if (_organizeByArtist) 'artist',
                if (_organizeByAlbum) 'album',
              ],
            },
          );
      if (mounted) {
        Navigator.pop(context);
        ModernToast.show(context, '已启动库整理任务', icon: Icons.auto_awesome_rounded);
      }
    } catch (e) {
      if (mounted) {
        ModernToast.show(
          context,
          '启动失败: $e',
          isError: true,
          icon: Icons.error_outline_rounded,
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '库管理工具',
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
          const SizedBox(height: 24),

          _buildToolSection(
            icon: Icons.drive_file_rename_outline_rounded,
            title: '批量重命名',
            description: '基于歌曲元数据（歌手 - 标题）重命名所有物理文件。',
            onTap: _isProcessing ? null : _startRename,
          ),

          const Divider(height: 32, color: AppTheme.border),

          const Text(
            '整理文件层级',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '按照歌手和专辑名自动创建文件夹并移动文件。',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildModernChip(
                '按艺术家',
                _organizeByArtist,
                (v) => setState(() => _organizeByArtist = v),
              ),
              const SizedBox(width: 12),
              _buildModernChip(
                '按专辑',
                _organizeByAlbum,
                (v) => setState(() => _organizeByAlbum = v),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isProcessing ? null : _startOrganize,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent.withValues(alpha: 0.1),
              foregroundColor: AppTheme.accent,
              elevation: 0,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              '开始整理库结构',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),

          const Divider(height: 32, color: AppTheme.border),

          _buildToolSection(
            icon: Icons.cleaning_services_rounded,
            title: '查找重复歌曲',
            description: '分析曲库并聚合相同的歌曲，您可以手动选择并清理多余版本。',
            onTap: () {
              // 先关闭 sheet，再用外部（Library 页面）的 context 执行导航
              // BottomSheet 内部的 context 无法正确触发 GoRouter 跳转
              Navigator.pop(context);
              widget.navContext.push('/library/duplicates');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToolSection({
    required IconData icon,
    required String title,
    required String description,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppTheme.accent),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppTheme.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernChip(
    String label,
    bool isSelected,
    Function(bool) onSelected,
  ) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: onSelected,
      backgroundColor: AppTheme.surface,
      selectedColor: AppTheme.accent.withValues(alpha: 0.2),
      checkmarkColor: AppTheme.accent,
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
        fontSize: 13,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected ? AppTheme.accent : AppTheme.border,
          width: 0.5,
        ),
      ),
    );
  }
}
