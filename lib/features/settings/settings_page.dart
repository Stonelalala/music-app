import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_service.dart';
import '../../core/http/api_client.dart';
import '../../core/player/cache_service.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/modern_toast.dart';
import 'settings_provider.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _neteaseCookieCtrl = TextEditingController();
  final _qqCookieCtrl = TextEditingController();
  final _cacheSectionKey = GlobalKey();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadInitialConfig();
  }

  @override
  void dispose() {
    _neteaseCookieCtrl.dispose();
    _qqCookieCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitialConfig() async {
    setState(() => _isLoading = true);
    try {
      final config = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>('/api/settings/config');
      if (config['success'] == true) {
        final data = config['data'] as Map<String, dynamic>;
        _neteaseCookieCtrl.text = data['neteaseCookie'] as String? ?? '';
        _qqCookieCtrl.text = data['qqCookie'] as String? ?? '';
      }
    } catch (e) {
      debugPrint('Failed to load config: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveConfig() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(apiClientProvider).post(
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
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authServiceProvider);
    final currentTheme = ref.watch(themeTypeProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
        centerTitle: false,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        children: [
          _buildSectionTitle(context, '快捷入口'),
          const SizedBox(height: 12),
          _buildQuickActionsRow(context),
          const SizedBox(height: 28),
          _buildSectionTitle(context, '主题外观'),
          const SizedBox(height: 12),
          _buildThemeGrid(context, ref, currentTheme),
          const SizedBox(height: 28),
          _buildSectionTitle(context, '离线缓存'),
          const SizedBox(height: 12),
          _buildCacheSection(context, ref),
          const SizedBox(height: 28),
          _buildSectionTitle(context, '账户信息'),
          const SizedBox(height: 12),
          _buildInfoTile(context, '当前用户', auth.username ?? '访客'),
          _buildInfoTile(context, '服务器地址', auth.baseUrl ?? '未连接'),
          const SizedBox(height: 28),
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
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _isLoading ? null : _saveConfig,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: const Text('保存所有配置'),
          ),
          const SizedBox(height: 36),
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
        ],
      ),
    );
  }

  Widget _buildQuickActionsRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildQuickAction(
            context,
            icon: Icons.search_rounded,
            label: '扫描',
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
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildQuickAction(
            context,
            icon: Icons.auto_awesome_rounded,
            label: '刮削',
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
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildQuickAction(
            context,
            icon: Icons.task_alt_rounded,
            label: '任务',
            color: Colors.orange,
            onTap: () => context.push('/tasks'),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.24),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeGrid(
    BuildContext context,
    WidgetRef ref,
    ThemeType activeType,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final itemWidth = (MediaQuery.of(context).size.width - 52) / 2;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: AppTheme.allThemes.map((theme) {
        final isSelected = theme.type == activeType;
        return GestureDetector(
          onTap: () => ref.read(themeTypeProvider.notifier).setTheme(theme.type),
          child: Container(
            width: itemWidth.clamp(140.0, 220.0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected
                  ? colorScheme.primaryContainer.withValues(alpha: 0.24)
                  : colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.outlineVariant.withValues(alpha: 0.24),
                width: isSelected ? 1.8 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: theme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    theme.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle_rounded,
                    color: colorScheme.primary,
                    size: 18,
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCacheSection(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      key: _cacheSectionKey,
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
            max: 4096,
            divisions: 31,
            label: '${settings.maxCacheSizeMB} MB',
            onChanged: (val) {
              ref.read(settingsProvider.notifier).setMaxCacheSize(val.round());
            },
          ),
          const Divider(height: 32),
          Consumer(
            builder: (context, ref, child) {
              final cachedAsync = ref.watch(cachedTracksProvider);
              return cachedAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('加载缓存失败: $e'),
                data: (tracks) {
                  return FutureBuilder<int>(
                    future: ref.read(cacheServiceProvider).getTotalCacheSize(),
                    builder: (context, snapshot) {
                      final totalSize = snapshot.data ?? 0;
                      final sizeDisplay = (totalSize / (1024 * 1024))
                          .toStringAsFixed(1);
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
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colorScheme.primary.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: colorScheme.primary.withValues(
                                            alpha: 0.2,
                                          ),
                                        ),
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
                                ModernToast.show(
                                  context,
                                  '缓存已清空',
                                  icon: Icons.delete_outline,
                                );
                              }
                            },
                            icon: const Icon(Icons.delete_sweep_rounded),
                            label: const Text('清理缓存'),
                            style: TextButton.styleFrom(
                              foregroundColor: colorScheme.error,
                            ),
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

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: TextStyle(
        color: Theme.of(context).colorScheme.primary,
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _buildInfoTile(BuildContext context, String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCookieField(
    BuildContext context,
    String label,
    TextEditingController controller,
    String hint,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: 3,
          minLines: 1,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
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
                      loading: () => const Center(
                        child: CircularProgressIndicator(),
                      ),
                      error: (e, _) => Center(child: Text('加载失败: $e')),
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
                              title: Text(track.title),
                              subtitle: Text(track.artist),
                              leading: const Icon(Icons.music_note_rounded),
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
}
