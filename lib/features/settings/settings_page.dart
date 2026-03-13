import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_service.dart';
import '../../core/http/api_client.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/modern_toast.dart';
import 'package:go_router/go_router.dart';
import '../settings/settings_provider.dart';
import '../../core/player/cache_service.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _neteaseCookieCtrl = TextEditingController();
  final _qqCookieCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadInitialConfig();
  }

  Future<void> _loadInitialConfig() async {
    setState(() => _isLoading = true);
    try {
      final config = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>('/api/settings/config');
      if (config['success'] == true) {
        final data = config['data'] as Map<String, dynamic>;
        _neteaseCookieCtrl.text = data['neteaseCookie'] ?? '';
        _qqCookieCtrl.text = data['qqCookie'] ?? '';
      }
    } catch (e) {
      debugPrint('Failed to load config: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveConfig() async {
    setState(() => _isLoading = true);
    try {
      await ref
          .read(apiClientProvider)
          .post(
            '/api/settings/config',
            data: {
              'neteaseCookie': _neteaseCookieCtrl.text,
              'qqCookie': _qqCookieCtrl.text,
            },
          );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('配置已保存')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存失败: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authServiceProvider);
    final currentTheme = ref.watch(themeTypeProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        centerTitle: false,
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildSectionTitle(context, '系统工具'),
          const SizedBox(height: 12),
          _buildToolCard(
            context,
            icon: Icons.search_rounded,
            title: '扫描音乐库',
            subtitle: '扫描本地目录并同步到数据库',
            color: Colors.blue,
            onTap: () async {
              try {
                await ref.read(apiClientProvider).post('/api/trigger-scan');
                if (context.mounted) {
                  ModernToast.show(
                    context,
                    '扫描任务已从后台启动',
                    icon: Icons.playlist_add_check_rounded,
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ModernToast.show(context, '启动失败: $e', isError: true);
                }
              }
            },
          ),
          const SizedBox(height: 16),
          _buildToolCard(
            context,
            icon: Icons.auto_awesome_rounded,
            title: '启动刮削',
            subtitle: '全量搜索元数据、歌词与封面',
            color: Colors.purple,
            onTap: () async {
              try {
                await ref.read(apiClientProvider).post('/api/trigger-scrape');
                if (context.mounted) {
                  ModernToast.show(
                    context,
                    '刮削任务已开始运行',
                    icon: Icons.auto_awesome_rounded,
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ModernToast.show(context, '启动失败: $e', isError: true);
                }
              }
            },
          ),
          const SizedBox(height: 16),
          _buildToolCard(
            context,
            icon: Icons.task_alt_rounded,
            title: '任务进度与历史',
            subtitle: '查看当前运行中的任务与过往记录',
            color: Colors.orange,
            onTap: () => context.push('/tasks'),
          ),
          const SizedBox(height: 32),
          _buildSectionTitle(context, '界面外观'),
          const SizedBox(height: 12),
          ...AppTheme.allThemes
              .map(
                (theme) => _buildThemeItem(context, ref, theme, currentTheme),
              )
              ,
          const SizedBox(height: 32),
          _buildSectionTitle(context, '离线缓存'),
          const SizedBox(height: 12),
          _buildCacheSection(context, ref),
          const SizedBox(height: 32),
          _buildSectionTitle(context, '账户信息'),
          _buildInfoTile(context, '当前用户', auth.username ?? '访客'),
          _buildInfoTile(context, '服务器地址', auth.baseUrl ?? '未连接'),
          const SizedBox(height: 32),
          _buildSectionTitle(context, '元数据与下载'),
          const SizedBox(height: 12),
          _buildCookieField(
            context,
            '网易云 Cookie',
            _neteaseCookieCtrl,
            '用于获取每日推荐与下载',
          ),
          const SizedBox(height: 16),
          _buildCookieField(
            context,
            'QQ 音乐 Cookie',
            _qqCookieCtrl,
            '用于解析 QQ 音乐链接',
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isLoading ? null : _saveConfig,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
            child: const Text('保存所有配置'),
          ),
          const SizedBox(height: 48),
          _buildSectionTitle(context, '危险区域'),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => ref.read(authServiceProvider.notifier).logout(),
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.error,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text(
              '退出当前账号',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildCacheSection(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '最大缓存空间',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                '${settings.maxCacheSizeMB} MB',
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Slider(
            value: settings.maxCacheSizeMB.toDouble(),
            min: 128,
            max: 4096, // 最大支持 4GB
            divisions: 31,
            label: '${settings.maxCacheSizeMB} MB',
            onChanged: (val) {
              ref
                  .read(settingsProvider.notifier)
                  .setMaxCacheSize(val.round());
            },
          ),
          const Divider(height: 32),
          Consumer(
            builder: (context, ref, child) {
              final cachedAsync = ref.watch(cachedTracksProvider);
              return cachedAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, stackTrace) => Text('加载缓存失败: $e'),
                data: (tracks) {
                  // 实际上我们需要实时计算文件大小，但这里暂用 tracks 计算或通过 getTotalCacheSize
                  return FutureBuilder<int>(
                    future: ref.read(cacheServiceProvider).getTotalCacheSize(),
                    builder: (context, snapshot) {
                      final totalSize = snapshot.data ?? 0;
                      final sizeDisplay = (totalSize / (1024 * 1024)).toStringAsFixed(1);
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('当前占用', style: TextStyle(fontSize: 13)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    '$sizeDisplay MB',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  GestureDetector(
                                    onTap: () => _showCachedTracks(context, ref),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: colorScheme.primary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: colorScheme.primary.withValues(alpha: 0.2)),
                                      ),
                                      child: Text(
                                        '查看详情',
                                        style: TextStyle(
                                          color: colorScheme.primary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              await ref.read(cacheServiceProvider).clearAllCache();
                              if (context.mounted) {
                                ModernToast.show(context, '缓存已清空',
                                    icon: Icons.delete_outline);
                              }
                            },
                            icon: const Icon(Icons.delete_sweep_rounded),
                            label: const Text('清理缓存'),
                            style: TextButton.styleFrom(foregroundColor: colorScheme.error),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToolCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeItem(
    BuildContext context,
    WidgetRef ref,
    ThemeInfo theme,
    ThemeType activeType,
  ) {
    final isSelected = theme.type == activeType;
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => ref.read(themeTypeProvider.notifier).setTheme(theme.type),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer.withValues(alpha: 0.2)
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outlineVariant.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: theme.primaryColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                theme.name,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 16,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: colorScheme.primary),
          ],
        ),
      ),
    );
  }

  void _showCachedTracks(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    const Icon(Icons.download_done_rounded, size: 28),
                    const SizedBox(width: 16),
                    const Text(
                      '已缓存歌曲',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Consumer(
                  builder: (context, ref, child) {
                    final cachedAsync = ref.watch(cachedTracksProvider);
                    return cachedAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, stackTrace) => Center(child: Text('加载失败: $e')),
                      data: (tracks) {
                        if (tracks.isEmpty) {
                          return const Center(child: Text('暂无已缓存歌曲'));
                        }
                        return ListView.builder(
                          controller: scrollController,
                          itemCount: tracks.length,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemBuilder: (context, index) {
                            final track = tracks[index];
                            return ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  '${ref.read(authServiceProvider).baseUrl}/api/tracks/${track.id}/cover?auth=${ref.read(authServiceProvider).token}',
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, error, stackTrace) => Container(
                                    color: Theme.of(context).colorScheme.surfaceContainer,
                                    child: const Icon(Icons.music_note),
                                  ),
                                ),
                              ),
                              title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text(track.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
                              trailing: Text(
                                track.sizeText,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 13,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildInfoTile(BuildContext context, String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: colorScheme.onSurfaceVariant)),
          Text(
            value,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCookieField(
    BuildContext context,
    String label,
    TextEditingController ctrl,
    String hint,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
          ),
        ),
        TextField(
          controller: ctrl,
          maxLines: 2,
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }
}
