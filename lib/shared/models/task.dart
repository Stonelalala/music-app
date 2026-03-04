class TaskItem {
  final String id;
  final String? parentId;
  final String type;
  final String status;
  final double progress;
  final String? message;
  final String? logs;
  final DateTime createdAt;

  const TaskItem({
    required this.id,
    this.parentId,
    required this.type,
    required this.status,
    required this.progress,
    this.message,
    this.logs,
    required this.createdAt,
  });

  factory TaskItem.fromJson(Map<String, dynamic> json) => TaskItem(
    id: json['id'] as String,
    parentId: json['parentId'] as String?,
    type: (json['type'] as String?) ?? 'unknown',
    status: (json['status'] as String?) ?? 'pending',
    progress: ((json['progress'] as num?) ?? 0).toDouble(),
    message: json['message'] as String?,
    logs: json['logs'] as String?,
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
  );

  bool get isRunning => status == 'running' || status == 'pending';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
  bool get isCancelled => status == 'cancelled';
  bool get isDone => isCompleted || isFailed || isCancelled;

  String get typeLabel {
    const labels = {
      'scan': '扫描',
      'scrape': '刮削元数据',
      'download_netease': '网易云下载',
      'download_qq': 'QQ音乐下载',
      'organize': '整理文件',
      'rename': '批量重命名',
      'playlist_import': '导入歌单',
    };
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
