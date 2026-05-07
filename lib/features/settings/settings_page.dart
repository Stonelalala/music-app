import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_service.dart';
import '../../core/http/api_client.dart';
import '../../core/player/player_service.dart';
import '../../core/player/cache_service.dart';
import '../../core/repositories/collection_repository.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/modern_toast.dart';
import '../my/collection_providers.dart';
import 'settings_provider.dart';

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
          _buildProfileHero(
            context,
            auth.username ?? '访客',
            auth.baseUrl ?? '未连接',
          ),
          const SizedBox(height: 24),
          _buildSectionTitle(context, '快捷入口'),
          const SizedBox(height: 12),
          _buildQuickActionsRow(context),
          const SizedBox(height: 28),
          _buildSectionTitle(context, '智能歌单'),
          const SizedBox(height: 12),
          _buildSmartPlaylistSection(context, ref),
          const SizedBox(height: 28),
          _buildSectionTitle(context, '主题外观'),
          const SizedBox(height: 12),
          _buildThemeGrid(context, ref, currentTheme),
          const SizedBox(height: 28),
          _buildSectionTitle(context, '离线缓存'),
          const SizedBox(height: 12),
          _buildCacheSection(context, ref),
          const SizedBox(height: 28),
          _buildSectionTitle(context, '元数据与下载'),
          const SizedBox(height: 12),
          _buildSurfaceCard(
            context,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCookieField(
                  context,
                  '网易云 Cookie',
                  _neteaseCookieCtrl,
                  '用于获取推荐和下载',
                ),
                const SizedBox(height: 16),
                _buildCookieField(
                  context,
                  'QQ 音乐 Cookie',
                  _qqCookieCtrl,
                  '用于解析 QQ 音乐链接',
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _saveConfig,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text('保存所有配置'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _buildSectionTitle(context, '数据备份'),
          const SizedBox(height: 12),
          _buildBackupSection(context, ref),
          const SizedBox(height: 28),
          _buildSectionTitle(context, '账户信息'),
          const SizedBox(height: 12),
          _buildInfoTile(context, '当前用户', auth.username ?? '访客'),
          _buildInfoTile(context, '服务器地址', auth.baseUrl ?? '未连接'),
          const SizedBox(height: 28),
          _buildSectionTitle(context, '危险区域'),
          const SizedBox(height: 12),
          _buildSurfaceCard(
            context,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextButton(
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
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHero(
    BuildContext context,
    String username,
    String server,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient(colorScheme),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.person_rounded,
                  color: colorScheme.primary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '个人音乐中心',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildHeroTag(
                context,
                icon: Icons.cloud_done_rounded,
                text: server,
              ),
              _buildHeroTag(
                context,
                icon: Icons.palette_outlined,
                text: '主题与快捷入口',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroTag(
    BuildContext context, {
    required IconData icon,
    required String text,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.30),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.primary),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSurfaceCard(
    BuildContext context, {
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.surfaceContainerHigh.withValues(alpha: 0.88),
            colorScheme.surfaceContainer.withValues(alpha: 0.78),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
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
      borderRadius: BorderRadius.circular(24),
      child: _buildSurfaceCard(
        context,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 21, color: color),
            ),
            const SizedBox(height: 14),
            Text(
              label,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmartPlaylistSection(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final smartAsync = ref.watch(smartPlaylistsProvider);

    return smartAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) =>
          _buildSurfaceCard(context, child: Text('加载智能歌单失败: $error')),
      data: (playlists) {
        if (playlists.isEmpty) {
          return _buildSurfaceCard(
            context,
            child: Text(
              '当前还没有可用的智能歌单',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          );
        }

        return Column(
          children: playlists.map((playlist) {
            final icon = switch (playlist.id) {
              'smart:most-played' => Icons.graphic_eq_rounded,
              'smart:recent-added' => Icons.schedule_rounded,
              _ => Icons.explore_rounded,
            };
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () =>
                    _showSmartPlaylistDetail(context, ref, playlist.id),
                child: _buildSurfaceCard(
                  context,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: Icon(icon, color: colorScheme.primary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              playlist.name,
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              playlist.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildBackupSection(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return _buildSurfaceCard(
      context,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '可导出收藏、歌单与最近播放，也支持将 JSON 备份再导入当前账号。',
            style: TextStyle(color: colorScheme.onSurfaceVariant, height: 1.45),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isLoading ? null : () => _exportUserData(ref),
                  icon: const Icon(Icons.ios_share_rounded),
                  label: const Text('导出备份'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : () => _showImportDialog(ref),
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('导入备份'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _exportUserData(WidgetRef ref) async {
    setState(() => _isLoading = true);
    try {
      final payload = await ref.read(collectionRepositoryProvider).exportData();
      final jsonText = const JsonEncoder.withIndent('  ').convert(payload);
      await Clipboard.setData(ClipboardData(text: jsonText));

      if (!mounted) {
        return;
      }

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.66,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '备份已复制',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('备份 JSON 已复制到剪贴板，你也可以先在下面快速确认内容。'),
                  const SizedBox(height: 12),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 280),
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        jsonText,
                        style: const TextStyle(fontSize: 12, height: 1.4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      if (mounted) {
        ModernToast.show(context, '备份已复制到剪贴板');
      }
    } catch (error) {
      if (mounted) {
        ModernToast.show(context, '导出备份失败: $error', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showImportDialog(WidgetRef ref) async {
    final controller = TextEditingController();
    var replace = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('导入备份'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('粘贴导出的 JSON 内容后即可恢复数据。'),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  minLines: 8,
                  maxLines: 14,
                  decoration: const InputDecoration(hintText: '粘贴备份 JSON'),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('覆盖现有数据'),
                  subtitle: const Text('关闭时为合并导入'),
                  value: replace,
                  onChanged: (value) => setDialogState(() => replace = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('开始导入'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) {
      return;
    }

    final raw = controller.text.trim();
    if (raw.isEmpty) {
      if (mounted) {
        ModernToast.show(context, '请先粘贴备份内容', isError: true);
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      await ref
          .read(collectionRepositoryProvider)
          .importData(decoded, replace: replace);
      ref.invalidate(favoritesProvider);
      ref.invalidate(playlistsProvider);
      ref.invalidate(playStatsProvider);
      ref.invalidate(recentHistoryProvider);
      ref.invalidate(smartPlaylistsProvider);
      if (mounted) {
        ModernToast.show(context, '备份导入完成');
      }
    } catch (error) {
      if (mounted) {
        ModernToast.show(context, '导入失败: $error', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showSmartPlaylistDetail(
    BuildContext context,
    WidgetRef ref,
    String playlistId,
  ) async {
    final pageContext = context;
    final colorScheme = Theme.of(context).colorScheme;
    final auth = ref.read(authServiceProvider);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => Consumer(
        builder: (context, ref, child) {
          final detailAsync = ref.watch(
            smartPlaylistDetailProvider(playlistId),
          );
          return detailAsync.when(
            loading: () => SizedBox(
              height: MediaQuery.of(sheetContext).size.height * 0.45,
              child: const Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Padding(
              padding: const EdgeInsets.all(24),
              child: Text('加载失败: $error'),
            ),
            data: (detail) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(sheetContext).size.height * 0.72,
                  ),
                  child: DefaultTextStyle.merge(
                    style: TextStyle(color: colorScheme.onSurface),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHigh.withValues(
                              alpha: 0.88,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: colorScheme.outlineVariant.withValues(
                                alpha: 0.18,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: colorScheme.primary.withValues(
                                        alpha: 0.14,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Icon(switch (playlistId) {
                                      'smart:most-played' =>
                                        Icons.graphic_eq_rounded,
                                      'smart:recent-added' =>
                                        Icons.schedule_rounded,
                                      _ => Icons.explore_rounded,
                                    }, color: colorScheme.primary),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          detail.name,
                                          style: TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w800,
                                            color: colorScheme.onSurface,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${detail.trackCount} 首歌曲',
                                          style: TextStyle(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: detail.tracks.isEmpty
                                      ? null
                                      : () async {
                                          await ref
                                              .read(playerHandlerProvider)
                                              .loadQueue(
                                                detail.tracks,
                                                startIndex: 0,
                                              );
                                          if (sheetContext.mounted) {
                                            Navigator.of(sheetContext).pop();
                                          }
                                          if (pageContext.mounted) {
                                            pageContext.push('/player');
                                          }
                                        },
                                  icon: const Icon(
                                    Icons.play_circle_fill_rounded,
                                  ),
                                  label: const Text('播放全部'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Flexible(
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: detail.tracks.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final track = detail.tracks[index];
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(
                                    color: colorScheme.outlineVariant
                                        .withValues(alpha: 0.14),
                                  ),
                                ),
                                tileColor: colorScheme.surfaceContainerHigh
                                    .withValues(alpha: 0.84),
                                minLeadingWidth: 58,
                                textColor: colorScheme.onSurface,
                                iconColor: colorScheme.onSurfaceVariant,
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: CachedNetworkImage(
                                    imageUrl:
                                        '${auth.baseUrl}/api/tracks/${track.id}/cover?auth=${auth.token}',
                                    cacheKey: 'cover_${track.id}',
                                    width: 52,
                                    height: 52,
                                    fit: BoxFit.cover,
                                    errorWidget: (context, url, error) =>
                                        Container(
                                          width: 52,
                                          height: 52,
                                          color: colorScheme
                                              .surfaceContainerHighest,
                                          alignment: Alignment.center,
                                          child: Icon(
                                            Icons.music_note_rounded,
                                            color: colorScheme.primary,
                                          ),
                                        ),
                                  ),
                                ),
                                title: Text(
                                  track.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                subtitle: Text(
                                  track.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right_rounded,
                                ),
                                onTap: () async {
                                  await ref
                                      .read(playerHandlerProvider)
                                      .loadQueue(
                                        detail.tracks,
                                        startIndex: index,
                                      );
                                  if (sheetContext.mounted) {
                                    Navigator.of(sheetContext).pop();
                                  }
                                  if (pageContext.mounted) {
                                    pageContext.push('/player');
                                  }
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
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
          onTap: () =>
              ref.read(themeTypeProvider.notifier).setTheme(theme.type),
          child: Container(
            width: itemWidth.clamp(140.0, 220.0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  isSelected
                      ? colorScheme.primaryContainer.withValues(alpha: 0.28)
                      : colorScheme.surfaceContainerHigh.withValues(
                          alpha: 0.82,
                        ),
                  isSelected
                      ? colorScheme.primary.withValues(alpha: 0.08)
                      : colorScheme.surfaceContainer.withValues(alpha: 0.74),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isSelected
                    ? colorScheme.primary.withValues(alpha: 0.72)
                    : colorScheme.outlineVariant.withValues(alpha: 0.20),
                width: isSelected ? 1.6 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: theme.primaryColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: theme.primaryColor.withValues(alpha: 0.28),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    theme.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w800
                          : FontWeight.w600,
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

    return _buildSurfaceCard(
      context,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '最大缓存空间',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '${settings.maxCacheSizeMB} MB',
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w800,
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
          const SizedBox(height: 8),
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
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '当前占用',
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '$sizeDisplay MB',
                                  style: TextStyle(
                                    color: colorScheme.onSurface,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  onPressed: () =>
                                      _showCachedTracks(context, ref),
                                  icon: const Icon(Icons.folder_open_rounded),
                                  label: const Text('查看详情'),
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    foregroundColor: colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: () async {
                              await ref
                                  .read(cacheServiceProvider)
                                  .clearAllCache();
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
                            style: OutlinedButton.styleFrom(
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
    final colorScheme = Theme.of(context).colorScheme;
    return Text(
      title,
      style: TextStyle(
        color: colorScheme.onSurface,
        fontSize: 22,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.5,
      ),
    );
  }

  Widget _buildInfoTile(BuildContext context, String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _buildSurfaceCard(
        context,
        child: Row(
          children: [
            SizedBox(
              width: 92,
              child: Text(
                label,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
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
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: 3,
          minLines: 1,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: colorScheme.surface.withValues(alpha: 0.34),
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
      useSafeArea: true,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.62,
        maxChildSize: 0.82,
        minChildSize: 0.36,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.18),
            ),
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
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
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
                    final auth = ref.watch(authServiceProvider);
                    final cachedAsync = ref.watch(cachedTracksProvider);
                    return cachedAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('加载失败: $e')),
                      data: (tracks) {
                        if (tracks.isEmpty) {
                          return const Center(child: Text('暂无已缓存歌曲'));
                        }
                        return ListView.builder(
                          controller: scrollController,
                          itemCount: tracks.length,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                          itemBuilder: (context, index) {
                            final track = tracks[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHigh
                                    .withValues(alpha: 0.84),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant
                                      .withValues(alpha: 0.14),
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: CachedNetworkImage(
                                    imageUrl:
                                        '${auth.baseUrl}/api/tracks/${track.id}/cover?auth=${auth.token}',
                                    cacheKey: 'cached_cover_${track.id}',
                                    width: 52,
                                    height: 52,
                                    fit: BoxFit.cover,
                                    errorWidget: (context, url, error) =>
                                        Container(
                                          width: 52,
                                          height: 52,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.surfaceContainerHighest,
                                          alignment: Alignment.center,
                                          child: Icon(
                                            Icons.music_note_rounded,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                          ),
                                        ),
                                  ),
                                ),
                                title: Text(
                                  track.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                subtitle: Text(
                                  track.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Icon(
                                  Icons.offline_pin_rounded,
                                  color: Theme.of(context).colorScheme.primary,
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
}
