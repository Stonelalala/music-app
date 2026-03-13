import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/http/api_client.dart';
import '../../shared/models/task.dart';
import '../../shared/theme/app_theme.dart';

final tasksListProvider = StreamProvider.autoDispose<List<TaskItem>>((
  ref,
) async* {
  final apiClient = ref.watch(apiClientProvider);

  while (true) {
    try {
      final data = await apiClient.get<Map<String, dynamic>>('/api/tasks');
      final list = data['data'] as List<dynamic>? ?? [];
      final tasks = list
          .map((e) => TaskItem.fromJson(e as Map<String, dynamic>))
          .toList();
      yield tasks;

      // Stop polling early if all tasks are completed/failed/cancelled
      final hasActiveTasks = tasks.any((t) => t.isRunning);
      if (!hasActiveTasks) {
        // Slow down polling when idle to save bandwidth, but keep watching for new tasks triggered elsewhere
        await Future.delayed(const Duration(seconds: 5));
      } else {
        // Fast polling when there are active tasks
        await Future.delayed(const Duration(milliseconds: 1500));
      }
    } catch (e) {
      // Yield previous state or empty list on error to prevent UI flicker
      yield [];
      await Future.delayed(const Duration(seconds: 5));
    }
  }
});

class TasksPage extends ConsumerWidget {
  const TasksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksListProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgBase,
      appBar: AppBar(
        title: const Text('任务中心'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: '刷新',
            onPressed: () => ref.invalidate(tasksListProvider),
          ),
          IconButton(
            icon: const Icon(Icons.cleaning_services_outlined),
            tooltip: '清理已完成',
            onPressed: () async {
              await ref.read(apiClientProvider).post('/api/tasks/cleanup');
              ref.invalidate(tasksListProvider);
            },
          ),
        ],
      ),
      body: tasksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            '加载失败: $e',
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
        ),
        data: (tasks) {
          if (tasks.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.task_alt, color: AppTheme.textSecondary, size: 48),
                  SizedBox(height: 12),
                  Text('暂无任务', style: TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
            );
          }
          return RefreshIndicator(
            color: AppTheme.accent,
            backgroundColor: AppTheme.surface,
            onRefresh: () async => ref.invalidate(tasksListProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: tasks.length,
              separatorBuilder: (_, index) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) => _TaskCard(task: tasks[i]),
            ),
          );
        },
      ),
    );
  }
}

class _TaskCard extends ConsumerWidget {
  final TaskItem task;
  const _TaskCard({required this.task});

  Color get _statusColor {
    if (task.isCompleted) return AppTheme.successColor;
    if (task.isFailed) return AppTheme.errorColor;
    if (task.isCancelled) return AppTheme.textSecondary;
    return AppTheme.accent;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  task.typeLabel,
                  style: TextStyle(
                    color: _statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                task.statusLabel,
                style: TextStyle(color: _statusColor, fontSize: 12),
              ),
              if (task.isRunning) ...[
                const SizedBox(width: 6),
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _statusColor,
                  ),
                ),
              ],
            ],
          ),
          if (task.message != null) ...[
            const SizedBox(height: 8),
            Text(
              task.message!,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (task.isRunning && task.progress > 0) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: task.progress / 100,
              backgroundColor: AppTheme.border,
              color: AppTheme.accent,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 4),
            Text(
              '${task.progress.toStringAsFixed(0)}%',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
          if (task.isRunning) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () async {
                  await ref
                      .read(apiClientProvider)
                      .post('/api/tasks/${task.id}/cancel');
                  ref.invalidate(tasksListProvider);
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.errorColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                ),
                child: const Text('取消', style: TextStyle(fontSize: 13)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
