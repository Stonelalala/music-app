import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_service.dart';
import '../../core/http/api_client.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/modern_toast.dart';
import 'package:go_router/go_router.dart';

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
              .toList(),
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
          color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colorScheme.outlineVariant.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
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
                      color: colorScheme.onSurfaceVariant.withOpacity(0.8),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: colorScheme.onSurfaceVariant.withOpacity(0.5),
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
              ? colorScheme.primaryContainer.withOpacity(0.2)
              : colorScheme.surfaceContainerHighest.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outlineVariant.withOpacity(0.2),
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
        color: colorScheme.surfaceContainerHighest.withOpacity(0.2),
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
