import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_service.dart';
import '../../core/player/player_service.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _serverCtrl = TextEditingController(text: 'http://');
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // 预填充历史登录信息
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = ref.read(authServiceProvider);
      if (auth.baseUrl != null) {
        _serverCtrl.text = auth.baseUrl!;
      }
      if (auth.username != null) {
        _userCtrl.text = auth.username!;
      }
      if (auth.password != null) {
        _passCtrl.text = auth.password!;
      }
    });
  }

  @override
  void dispose() {
    _serverCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final baseUrl = _serverCtrl.text.trim().replaceAll(RegExp(r'/$'), '');
      final username = _userCtrl.text.trim();
      final password = _passCtrl.text;

      debugPrint('Attempting login to: $baseUrl/api/auth/login');
      final dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 30),
          headers: const {'Content-Type': 'application/json'},
        ),
      );

      final res = await dio.post(
        '/api/auth/login',
        data: {'username': username, 'password': password},
      );

      final token = res.data['token'] as String;
      final serverUsername = res.data['user']['username'] as String;

      final auth = ref.read(authServiceProvider.notifier);
      await auth.saveLogin(
        token: token,
        baseUrl: baseUrl,
        username: serverUsername,
        password: password,
      );

      // 更新 PlayerHandler 认证信息
      ref.read(playerHandlerProvider).setAuth(token, baseUrl);

      if (mounted) context.go('/home');
    } on DioException catch (e) {
      debugPrint('Login DioError: ${e.type} - ${e.message}');
      debugPrint('Login DioError Response: ${e.response}');
      setState(() {
        _error =
            e.response?.data?['error'] as String? ?? '无法连接到服务器 (${e.type})';
      });
    } catch (e) {
      debugPrint('Login GenericError: $e');
      setState(() {
        _error = '登录失败: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () {},
        ),
        title: Text('Server Setup'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                // Logo
                Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(
                        alpha: 0.34,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.waves_rounded,
                        color: colorScheme.primary,
                        size: 60,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'SonicStream',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Connect to your private cloud library',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 48),

                // Server URL
                _buildLabel('SERVER URL'),
                TextFormField(
                  controller: _serverCtrl,
                  style: TextStyle(color: colorScheme.onSurface),
                  decoration: const InputDecoration(
                    hintText: 'https://stream.yourcloud.com',
                    prefixIcon: Icon(Icons.dns_outlined, size: 20),
                  ),
                  keyboardType: TextInputType.url,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return '请输入服务端地址';
                    if (!v.trim().startsWith('http')) return '地址须以 http(s) 开头';
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Username
                _buildLabel('USERNAME'),
                TextFormField(
                  controller: _userCtrl,
                  style: TextStyle(color: colorScheme.onSurface),
                  decoration: const InputDecoration(
                    hintText: 'your_username',
                    prefixIcon: Icon(Icons.person_outline, size: 20),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? '请输入用户名' : null,
                ),
                const SizedBox(height: 24),

                // Password
                _buildLabel('PASSWORD'),
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  style: TextStyle(color: colorScheme.onSurface),
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    prefixIcon: Icon(Icons.lock_outline, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility,
                        size: 20,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? '请输入密码' : null,
                ),

                if (_error != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: colorScheme.onErrorContainer,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],

                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: _loading ? null : _login,
                  child: _loading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.onPrimary,
                          ),
                        )
                      : Text('Test Connection'),
                ),
                const SizedBox(height: 32),
                Center(
                  child: Text.rich(
                    TextSpan(
                      text: 'Need help with setup? ',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                      children: [
                        TextSpan(
                          text: 'View Documentation',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
