import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_service.dart';
import '../../core/http/api_client.dart';
import '../../shared/theme/app_theme.dart';

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

    return Scaffold(
      backgroundColor: AppTheme.bgBase,
      appBar: AppBar(
        title: const Text('Settings'),
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
          _buildSectionTitle('ACCOUNT'),
          _buildInfoTile('Username', auth.username ?? 'Unknown'),
          _buildInfoTile('Server', auth.baseUrl ?? 'Not set'),
          const SizedBox(height: 24),
          _buildSectionTitle('METADATA & DOWNLOAD'),
          const SizedBox(height: 12),
          _buildCookieField(
            'Netease Cookie',
            _neteaseCookieCtrl,
            'Paste NetEase Music Cookie here',
          ),
          const SizedBox(height: 16),
          _buildCookieField(
            'QQ Music Cookie',
            _qqCookieCtrl,
            'Paste QQ Music Cookie here',
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isLoading ? null : _saveConfig,
            child: const Text('Save Configuration'),
          ),
          const SizedBox(height: 40),
          _buildSectionTitle('DANGER ZONE'),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => ref.read(authServiceProvider.notifier).logout(),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.errorColor,
              side: const BorderSide(color: AppTheme.errorColor),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child: const Text(
              'Logout',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: AppTheme.accent,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCookieField(
    String label,
    TextEditingController ctrl,
    String hint,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ),
        TextField(
          controller: ctrl,
          maxLines: 3,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            fillColor: AppTheme.surfaceElevated,
          ),
        ),
      ],
    );
  }
}
