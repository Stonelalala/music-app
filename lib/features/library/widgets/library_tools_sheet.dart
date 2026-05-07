import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/http/api_client.dart';
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
      useSafeArea: true,
      isDismissible: true,
      enableDrag: true,
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
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
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
              Text(
                '库管理工具',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: colorScheme.onSurfaceVariant),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 24),

          _buildToolSection(
            context,
            icon: Icons.drive_file_rename_outline_rounded,
            title: '批量重命名',
            onTap: _isProcessing ? null : _startRename,
          ),

          Divider(height: 32, color: colorScheme.outlineVariant),

          Text(
            '整理文件层级',
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildModernChip(
                context,
                '按艺术家',
                _organizeByArtist,
                (v) => setState(() => _organizeByArtist = v),
              ),
              const SizedBox(width: 12),
              _buildModernChip(
                context,
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
              backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
              foregroundColor: colorScheme.primary,
              elevation: 0,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              '开始整理库结构',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),

          Divider(height: 32, color: colorScheme.outlineVariant),

          _buildToolSection(
            context,
            icon: Icons.cleaning_services_rounded,
            title: '查找重复歌曲',
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

  Widget _buildToolSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    VoidCallback? onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
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
                color: colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: colorScheme.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: colorScheme.onSurfaceVariant,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernChip(
    BuildContext context,
    String label,
    bool isSelected,
    Function(bool) onSelected,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: onSelected,
      backgroundColor: colorScheme.surfaceContainerHighest,
      selectedColor: colorScheme.primary.withValues(alpha: 0.18),
      checkmarkColor: colorScheme.primary,
      labelStyle: TextStyle(
        color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
        fontSize: 13,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
          width: 0.5,
        ),
      ),
    );
  }
}
