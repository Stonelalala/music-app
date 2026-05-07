import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _kToken = 'jwt_token';
const _kBaseUrl = 'server_base_url';
const _kUsername = 'username';
const _kPassword = 'password';

class AuthState {
  final String? token;
  final String? baseUrl;
  final String? username;
  final String? password;
  final bool isAuthenticated;

  const AuthState({
    this.token,
    this.baseUrl,
    this.username,
    this.password,
    this.isAuthenticated = false,
  });

  AuthState copyWith({
    String? token,
    String? baseUrl,
    String? username,
    String? password,
    bool? isAuthenticated,
  }) => AuthState(
    token: token ?? this.token,
    baseUrl: baseUrl ?? this.baseUrl,
    username: username ?? this.username,
    password: password ?? this.password,
    isAuthenticated: isAuthenticated ?? this.isAuthenticated,
  );
}

class AuthService extends StateNotifier<AuthState> {
  static final _storage = FlutterSecureStorage();

  AuthService() : super(const AuthState());

  Dio _buildAuthDio(String baseUrl, {String? token}) {
    return Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );
  }

  /// 初始化：从存储中恢复 token 和 baseUrl
  Future<void> init() async {
    final token = await _storage.read(key: _kToken);
    final baseUrl = await _storage.read(key: _kBaseUrl);
    final username = await _storage.read(key: _kUsername);
    final password = await _storage.read(key: _kPassword);
    state = AuthState(
      token: token,
      baseUrl: baseUrl,
      username: username,
      password: password,
      isAuthenticated: token != null,
    );

    if (token != null && baseUrl != null) {
      await ensureActiveSession();
    }
  }

  /// 保存登录结果
  Future<void> saveLogin({
    required String token,
    required String baseUrl,
    required String username,
    required String password,
  }) async {
    await _storage.write(key: _kToken, value: token);
    await _storage.write(key: _kBaseUrl, value: baseUrl);
    await _storage.write(key: _kUsername, value: username);
    await _storage.write(key: _kPassword, value: password);
    state = AuthState(
      token: token,
      baseUrl: baseUrl,
      username: username,
      password: password,
      isAuthenticated: true,
    );
  }

  /// 退出登录
  Future<void> logout() async {
    await _storage.delete(key: _kToken);
    state = AuthState(
      baseUrl: state.baseUrl,
      username: state.username,
      password: state.password,
      isAuthenticated: false,
    );
  }

  Future<bool> ensureActiveSession() async {
    final token = state.token ?? await _storage.read(key: _kToken);
    final baseUrl = state.baseUrl ?? await _storage.read(key: _kBaseUrl);
    if (token == null || baseUrl == null) {
      return false;
    }

    try {
      await _buildAuthDio(baseUrl, token: token).get('/api/auth/check');
      if (state.token != token ||
          state.baseUrl != baseUrl ||
          !state.isAuthenticated) {
        state = state.copyWith(
          token: token,
          baseUrl: baseUrl,
          isAuthenticated: true,
        );
      }
      return true;
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        final refreshedToken = await reauthenticateIfPossible();
        if (refreshedToken != null) {
          return true;
        }
        await logout();
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<String?> reauthenticateIfPossible() async {
    final baseUrl = state.baseUrl ?? await _storage.read(key: _kBaseUrl);
    final username = state.username ?? await _storage.read(key: _kUsername);
    final password = state.password ?? await _storage.read(key: _kPassword);

    if (baseUrl == null ||
        username == null ||
        username.isEmpty ||
        password == null ||
        password.isEmpty) {
      return null;
    }

    try {
      final response = await _buildAuthDio(baseUrl).post(
        '/api/auth/login',
        data: {'username': username, 'password': password},
      );

      final token = response.data['token'] as String?;
      final serverUsername =
          response.data['user']?['username'] as String? ?? username;
      if (token == null || token.isEmpty) {
        return null;
      }

      await saveLogin(
        token: token,
        baseUrl: baseUrl,
        username: serverUsername,
        password: password,
      );
      return token;
    } catch (_) {
      return null;
    }
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
