import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/http/api_client.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/modern_toast.dart';

final duplicateTracksProvider = FutureProvider.autoDispose<List<dynamic>>((
  ref,
) async {
  final res = await ref
      .read(apiClientProvider)
      .get<Map<String, dynamic>>('/api/tracks/duplicates');
  if (res['success'] == true) {
    return res['data'] as List<dynamic>;
  }
  throw res['error'] ?? '数据获取失败';
});

class DuplicateCleaningPage extends ConsumerStatefulWidget {
  const DuplicateCleaningPage({super.key});

  @override
  ConsumerState<DuplicateCleaningPage> createState() =>
      _DuplicateCleaningPageState();
}

class _DuplicateCleaningPageState extends ConsumerState<DuplicateCleaningPage> {
  final Set<String> _selectedIds = {};
  bool _isDeleting = false;

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;

    final pageContext = context;
    final confirm = await showDialog<bool>(
      context: pageContext,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        title: const Text(
          '物理删除确认',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: Text(
          '确认为选中的 ${_selectedIds.length} 个曲目执行物理删除吗？此操作无法撤销。',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isDeleting = true);
    try {
      final res = await ref
          .read(apiClientProvider)
          .post('/api/tracks/delete', data: {'ids': _selectedIds.toList()});

      if (!pageContext.mounted) return;
      if (res['success'] == true) {
        ModernToast.show(
          pageContext,
          '成功清理 ${res['count']} 个项目',
          icon: Icons.cleaning_services_rounded,
        );
        _selectedIds.clear();
        ref.invalidate(duplicateTracksProvider);
      }
    } catch (e) {
      if (!pageContext.mounted) return;
      ModernToast.show(pageContext, '清理失败: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final duplicatesAsync = ref.watch(duplicateTracksProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('查杀重复歌曲'),
        actions: [
          if (_selectedIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: TextButton.icon(
                onPressed: _isDeleting ? null : _deleteSelected,
                icon: const Icon(Icons.delete_sweep_rounded, color: Colors.red),
                label: Text(
                  '删除 (${_selectedIds.length})',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
        ],
      ),
      body: duplicatesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (groups) {
          if (groups.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 64,
                    color: colorScheme.primary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '您的曲库非常整洁，没有发现重复项',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              return _DuplicateGroupCard(
                group: group,
                selectedIds: _selectedIds,
                onSelectionChanged: () => setState(() {}),
              );
            },
          );
        },
      ),
    );
  }
}

class _DuplicateGroupCard extends StatelessWidget {
  final Map<String, dynamic> group;
  final Set<String> selectedIds;
  final VoidCallback onSelectionChanged;

  const _DuplicateGroupCard({
    required this.group,
    required this.selectedIds,
    required this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final files = group['files'] as List<dynamic>;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group['title'] ?? '未知标题',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        group['artist'] ?? '未知艺术家',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${files.length} 个版本',
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.border),
          ...files.map((file) => _buildFileItem(context, file)),
        ],
      ),
    );
  }

  Widget _buildFileItem(BuildContext context, Map<String, dynamic> file) {
    final isSelected = selectedIds.contains(file['id']);
    final sizeMb = (file['size'] / (1024 * 1024)).toStringAsFixed(1);
    final isHighQuality =
        (file['extension'] as String).toLowerCase() == '.flac';

    return InkWell(
      onTap: () {
        if (isSelected) {
          selectedIds.remove(file['id']);
        } else {
          selectedIds.add(file['id']);
        }
        onSelectionChanged();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Checkbox(
              value: isSelected,
              onChanged: (val) {
                if (val == true) {
                  selectedIds.add(file['id']);
                } else {
                  selectedIds.remove(file['id']);
                }
                onSelectionChanged();
              },
              activeColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file['filename'] ?? '未知文件',
                    style: TextStyle(
                      color: isSelected ? Colors.red : AppTheme.textPrimary,
                      fontSize: 14,
                      decoration: isSelected
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      if (isHighQuality) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Colors.amber.withValues(alpha: 0.3),
                              width: 0.5,
                            ),
                          ),
                          child: const Text(
                            'LOSSLESS',
                            style: TextStyle(
                              color: Colors.amber,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        '${file['extension'].toUpperCase()} • $sizeMb MB',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.delete_outline_rounded,
                color: Colors.red,
                size: 20,
              )
            else if (group['files'].indexOf(file) == 0)
              const Text(
                '建议保留',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
