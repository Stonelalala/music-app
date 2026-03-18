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
      final data = await apiClient.get<Map<String, dynamic>>(
        '/api/tasks',
        params: {'limit': 80},
      );
      final list = data['data'] as List<dynamic>? ?? const [];
      final tasks = list
          .map((item) => TaskItem.fromJson(item as Map<String, dynamic>))
          .toList();
      yield tasks;

      final hasActiveTasks = tasks.any((task) => task.isRunning);
      await Future.delayed(
        hasActiveTasks
            ? const Duration(milliseconds: 1500)
            : const Duration(seconds: 5),
      );
    } catch (_) {
      yield const [];
      await Future.delayed(const Duration(seconds: 5));
    }
  }
});

enum _TaskFilter { all, active, failed, done }

class TasksPage extends ConsumerStatefulWidget {
  const TasksPage({super.key});

  @override
  ConsumerState<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends ConsumerState<TasksPage> {
  _TaskFilter _filter = _TaskFilter.all;

  @override
  Widget build(BuildContext context) {
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
        error: (error, _) => Center(
          child: Text(
            '加载失败: $error',
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
        ),
        data: (tasks) {
          final filteredTasks = _applyFilter(tasks);
          return Column(
            children: [
              _TaskFilterBar(
                current: _filter,
                onChanged: (value) => setState(() => _filter = value),
              ),
              Expanded(
                child: filteredTasks.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.task_alt_rounded,
                              color: AppTheme.textSecondary,
                              size: 48,
                            ),
                            SizedBox(height: 12),
                            Text(
                              '暂无任务',
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        color: AppTheme.accent,
                        backgroundColor: AppTheme.surface,
                        onRefresh: () async =>
                            ref.invalidate(tasksListProvider),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredTasks.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) => _TaskCard(
                            task: filteredTasks[index],
                            onChanged: () => ref.invalidate(tasksListProvider),
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<TaskItem> _applyFilter(List<TaskItem> tasks) {
    return switch (_filter) {
      _TaskFilter.all => tasks,
      _TaskFilter.active => tasks.where((task) => task.isRunning).toList(),
      _TaskFilter.failed => tasks.where((task) => task.isFailed).toList(),
      _TaskFilter.done => tasks.where((task) => task.isDone).toList(),
    };
  }
}

class _TaskFilterBar extends StatelessWidget {
  const _TaskFilterBar({required this.current, required this.onChanged});

  final _TaskFilter current;
  final ValueChanged<_TaskFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          _FilterChip(
            label: '全部',
            selected: current == _TaskFilter.all,
            onTap: () => onChanged(_TaskFilter.all),
          ),
          _FilterChip(
            label: '进行中',
            selected: current == _TaskFilter.active,
            onTap: () => onChanged(_TaskFilter.active),
          ),
          _FilterChip(
            label: '失败',
            selected: current == _TaskFilter.failed,
            onTap: () => onChanged(_TaskFilter.failed),
          ),
          _FilterChip(
            label: '已完成',
            selected: current == _TaskFilter.done,
            onTap: () => onChanged(_TaskFilter.done),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
      ),
    );
  }
}

class _TaskCard extends ConsumerWidget {
  const _TaskCard({required this.task, required this.onChanged});

  final TaskItem task;
  final VoidCallback onChanged;

  Color get _statusColor {
    if (task.isCompleted) {
      return AppTheme.successColor;
    }
    if (task.isFailed) {
      return AppTheme.errorColor;
    }
    if (task.isCancelled) {
      return AppTheme.textSecondary;
    }
    return AppTheme.accent;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _showTaskDetails(context),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    task.typeLabel,
                    style: TextStyle(
                      color: _statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _PriorityBadge(priority: task.priority),
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
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (task.isRunning && task.progress > 0) ...[
              const SizedBox(height: 10),
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
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                if (task.canAdjustPriority)
                  _MiniActionButton(
                    icon: Icons.arrow_downward_rounded,
                    label: '降级',
                    onTap: () => _updatePriority(ref, task.priority - 1),
                  ),
                if (task.canAdjustPriority)
                  _MiniActionButton(
                    icon: Icons.arrow_upward_rounded,
                    label: '升级',
                    onTap: () => _updatePriority(ref, task.priority + 1),
                  ),
                _MiniActionButton(
                  icon: Icons.notes_rounded,
                  label: '日志',
                  onTap: () => _showTaskDetails(context),
                ),
                if (task.canRetry)
                  _MiniActionButton(
                    icon: Icons.refresh_rounded,
                    label: '重试',
                    onTap: () async {
                      await ref
                          .read(apiClientProvider)
                          .post('/api/tasks/${task.id}/retry');
                      onChanged();
                    },
                  ),
                if (task.isRunning)
                  _MiniActionButton(
                    icon: Icons.close_rounded,
                    label: '取消',
                    foregroundColor: AppTheme.errorColor,
                    onTap: () async {
                      await ref
                          .read(apiClientProvider)
                          .post('/api/tasks/${task.id}/cancel');
                      onChanged();
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updatePriority(WidgetRef ref, int nextPriority) async {
    await ref
        .read(apiClientProvider)
        .post(
          '/api/tasks/${task.id}/priority',
          data: {'priority': nextPriority},
        );
    onChanged();
  }

  Future<void> _showTaskDetails(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.45,
        builder: (context, controller) => Container(
          color: AppTheme.surface,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      task.typeLabel,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  _PriorityBadge(priority: task.priority),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                task.statusLabel,
                style: TextStyle(
                  color: _statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (task.message?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                Text(
                  task.message!,
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ],
              const SizedBox(height: 16),
              const Text(
                '运行日志',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.border, width: 0.5),
                  ),
                  child: SingleChildScrollView(
                    controller: controller,
                    child: SelectableText(
                      task.logs?.trim().isNotEmpty == true
                          ? task.logs!.trim()
                          : '暂无日志',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority});

  final int priority;

  @override
  Widget build(BuildContext context) {
    final isHigh = priority > 0;
    final isLow = priority < 0;
    final color = isHigh
        ? AppTheme.accent
        : isLow
        ? AppTheme.textSecondary
        : AppTheme.textPrimary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '优先级 ${priority >= 0 ? '+' : ''}$priority',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MiniActionButton extends StatelessWidget {
  const _MiniActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.foregroundColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final color = foregroundColor ?? AppTheme.textPrimary;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.18)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
