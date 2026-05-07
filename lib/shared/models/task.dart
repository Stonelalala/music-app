class TaskItem {
  final String id;
  final String? parentId;
  final String type;
  final String status;
  final int priority;
  final double progress;
  final String? message;
  final String? logs;
  final DateTime createdAt;

  const TaskItem({
    required this.id,
    this.parentId,
    required this.type,
    required this.status,
    required this.priority,
    required this.progress,
    this.message,
    this.logs,
    required this.createdAt,
  });

  factory TaskItem.fromJson(Map<String, dynamic> json) => TaskItem(
    id: json['id'] as String,
    parentId: (json['parentId'] ?? json['parent_id']) as String?,
    type: (json['type'] as String?) ?? 'unknown',
    status: (json['status'] as String?) ?? 'pending',
    priority: ((json['priority'] as num?) ?? 0).toInt(),
    progress: ((json['progress'] as num?) ?? 0).toDouble(),
    message: json['message'] as String?,
    logs: json['logs'] as String?,
    createdAt:
        DateTime.tryParse(
              (json['createdAt'] ?? json['created_at']) as String? ?? '',
            ) ??
            DateTime.now(),
  );

  bool get isRunning => status == 'running' || status == 'pending';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
  bool get isCancelled => status == 'cancelled';
  bool get isDone => isCompleted || isFailed || isCancelled;
  bool get canRetry =>
      isFailed &&
      const {
        'scan',
        'scrape',
        'download_netease',
        'download_qq',
        'download_kugou',
        'download_kuwo',
      }.contains(type);
  bool get canAdjustPriority => !isDone;

  String get typeLabel {
    const labels = {
      'scan': '扫描',
      'scrape': '刮削',
      'download_netease': '网易云下载',
      'download_qq': 'QQ 音乐下载',
      'download_kugou': '酷狗下载',
      'download_kuwo': '酷我下载',
      'organize': '整理文件',
      'rename': '批量重命名',
      'playlist_import': '导入歌单',
    };
    labels['netease_daily_sync'] = '网易云日更同步';
    return labels[type] ?? type;
  }

  String get statusLabel {
    const labels = {
      'pending': '等待中',
      'running': '进行中',
      'completed': '已完成',
      'failed': '失败',
      'cancelled': '已取消',
    };
    return labels[status] ?? status;
  }
}
