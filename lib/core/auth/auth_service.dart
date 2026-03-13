import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _kToken = 'jwt_token';
const _kBaseUrl = 'server_base_url';
const _kUsername = 'username';

class AuthState {
  final String? token;
  final String? baseUrl;
  final String? username;
  final bool isAuthenticated;

  const AuthState({
    this.token,
    this.baseUrl,
    this.username,
    this.isAuthenticated = false,
  });

  AuthState copyWith({
    String? token,
    String? baseUrl,
    String? username,
    bool? isAuthenticated,
  }) => AuthState(
    token: token ?? this.token,
    baseUrl: baseUrl ?? this.baseUrl,
    username: username ?? this.username,
    isAuthenticated: isAuthenticated ?? this.isAuthenticated,
  );
}

class AuthService extends StateNotifier<AuthState> {
  static final _storage = FlutterSecureStorage();

  AuthService() : super(const AuthState());

  /// 初始化：从存储中恢复 token 和 baseUrl
  Future<void> init() async {
    final token = await _storage.read(key: _kToken);
    final baseUrl = await _storage.read(key: _kBaseUrl);
    final username = await _storage.read(key: _kUsername);
    state = AuthState(
      token: token,
      baseUrl: baseUrl,
      username: username,
      isAuthenticated: token != null,
    );
  }

  /// 保存登录结果
  Future<void> saveLogin({
    required String token,
    required String baseUrl,
    required String username,
  }) async {
    await _storage.write(key: _kToken, value: token);
    await _storage.write(key: _kBaseUrl, value: baseUrl);
    await _storage.write(key: _kUsername, value: username);
    state = AuthState(
      token: token,
      baseUrl: baseUrl,
      username: username,
      isAuthenticated: true,
    );
  }

  /// 退出登录
  Future<void> logout() async {
    await _storage.deleteAll();
    state = const AuthState();
  }

  Future<String?> getToken() async => _storage.read(key: _kToken);

  String? get baseUrl => state.baseUrl;
  String? get token => state.token;
  bool get isAuthenticated => state.isAuthenticated;
}

// 手动定义 keepAlive 的 StateNotifierProvider
final authServiceProvider = StateNotifierProvider<AuthService, AuthState>(
  (ref) => AuthService(),
);
