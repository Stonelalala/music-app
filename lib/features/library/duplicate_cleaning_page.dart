import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/http/api_client.dart';
import '../../shared/widgets/modern_toast.dart';
import 'duplicate_cleaning_logic.dart';

final duplicateTracksProvider =
    FutureProvider.autoDispose<List<DuplicateGroup>>((ref) async {
      final res = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>('/api/tracks/duplicates');
      if (res['success'] == true) {
        final data = (res['data'] as List<dynamic>? ?? const []);
        return data
            .map(
              (item) => DuplicateGroup.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(growable: false);
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

  void _setFileSelection(String id, bool selected) {
    setState(() {
      if (selected) {
        _selectedIds.add(id);
      } else {
        _selectedIds.remove(id);
      }
    });
  }

  void _applyRecommendedSelection(List<DuplicateGroup> groups) {
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(buildRecommendedSelection(groups));
    });
  }

  void _clearSelection() {
    if (_selectedIds.isEmpty) return;
    setState(_selectedIds.clear);
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;

    final pageContext = context;
    final confirm = await showDialog<bool>(
      context: pageContext,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surfaceContainerHigh,
        title: Text(
          '物理删除确认',
          style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface),
        ),
        content: Text(
          '确认为选中的 ${_selectedIds.length} 个曲目执行物理删除吗？此操作无法撤销。',
          style: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('确认删除', style: TextStyle(color: Colors.red)),
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
        title: Text('查杀重复歌曲'),
        actions: [
          if (_selectedIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: TextButton.icon(
                onPressed: _isDeleting ? null : _deleteSelected,
                icon: Icon(Icons.delete_sweep_rounded, color: Colors.red),
                label: Text(
                  '删除 (${_selectedIds.length})',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ),
        ],
      ),
      body: duplicatesAsync.when(
        loading: () => Center(child: CircularProgressIndicator()),
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
                  Text(
                    '您的曲库非常整洁，没有发现重复项',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            );
          }

          final recommendedIds = buildRecommendedSelection(groups);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: _SelectionToolbar(
                  groupCount: groups.length,
                  selectedCount: _selectedIds.length,
                  recommendedCount: recommendedIds.length,
                  onSelectRecommended: () => _applyRecommendedSelection(groups),
                  onClearSelection: _clearSelection,
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    return _DuplicateGroupCard(
                      group: group,
                      selectedIds: _selectedIds,
                      onSelectionChanged: _setFileSelection,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SelectionToolbar extends StatelessWidget {
  const _SelectionToolbar({
    required this.groupCount,
    required this.selectedCount,
    required this.recommendedCount,
    required this.onSelectRecommended,
    required this.onClearSelection,
  });

  final int groupCount;
  final int selectedCount;
  final int recommendedCount;
  final VoidCallback onSelectRecommended;
  final VoidCallback onClearSelection;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '发现 $groupCount 组疑似重复',
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '智能推荐可直接勾选 $recommendedCount 个待清理文件，当前已选择 $selectedCount 个。',
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              FilledButton.tonalIcon(
                onPressed: onSelectRecommended,
                icon: Icon(Icons.auto_fix_high_rounded),
                label: Text('智能勾选'),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: selectedCount == 0 ? null : onClearSelection,
                icon: Icon(Icons.deselect_rounded),
                label: Text('清空选择'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DuplicateGroupCard extends StatelessWidget {
  final DuplicateGroup group;
  final Set<String> selectedIds;
  final void Function(String id, bool selected) onSelectionChanged;

  const _DuplicateGroupCard({
    required this.group,
    required this.selectedIds,
    required this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final files = group.files;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
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
                        group.title,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        group.artist,
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurfaceVariant,
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
          Divider(height: 1, color: colorScheme.outlineVariant),
          ...files.map((file) => _buildFileItem(context, file)),
        ],
      ),
    );
  }

  Widget _buildFileItem(BuildContext context, DuplicateFile file) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = selectedIds.contains(file.id);
    final sizeMb = (file.size / (1024 * 1024)).toStringAsFixed(1);
    final isRecommendedKeep =
        file.isRecommendedKeep ||
        group.recommendedKeepId == file.id ||
        group.files.first.id == file.id;
    final meta = <String>[
      file.extension.replaceAll('.', '').toUpperCase(),
      '$sizeMb MB',
      if (file.bitrate > 0) '${file.bitrate} kbps',
      if (file.duration > 0) _formatDuration(file.duration),
    ];

    return InkWell(
      onTap: () {
        onSelectionChanged(file.id, !isSelected);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Checkbox(
              value: isSelected,
              onChanged: (value) => onSelectionChanged(file.id, value == true),
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
                    file.filename,
                    style: TextStyle(
                      color: isSelected ? Colors.red : colorScheme.onSurface,
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
                      if (file.isLossless) ...[
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
                          child: Text(
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
                      Expanded(
                        child: Text(
                          meta.join(' • '),
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20)
            else if (isRecommendedKeep)
              Text(
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

String _formatDuration(double seconds) {
  final totalSeconds = seconds.round();
  final minutes = totalSeconds ~/ 60;
  final remainSeconds = totalSeconds % 60;
  final secondsText = remainSeconds.toString().padLeft(2, '0');
  return '$minutes:$secondsText';
}
