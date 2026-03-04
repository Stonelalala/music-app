import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_service.dart';

class ApiClient {
  late final Dio _dio;
  final AuthService _auth;

  ApiClient(this._auth, String baseUrl) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _auth.getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (e, handler) async {
          if (e.response?.statusCode == 401) {
            await _auth.logout();
          }
          handler.next(e);
        },
      ),
    );
  }

  Dio get dio => _dio;

  /// GET 请求封装
  Future<T> get<T>(String path, {Map<String, dynamic>? params}) async {
    final res = await _dio.get(path, queryParameters: params);
    return res.data as T;
  }

  /// POST 请求封装
  Future<T> post<T>(String path, {dynamic data}) async {
    final res = await _dio.post(path, data: data);
    return res.data as T;
  }

  /// DELETE 请求封装
  Future<T> delete<T>(String path) async {
    final res = await _dio.delete(path);
    return res.data as T;
  }

  /// 构建带 token 的 Headers（用于 CachedNetworkImage / just_audio）
  Future<Map<String, String>> authHeaders() async {
    final token = await _auth.getToken();
    if (token == null) return {};
    return {'Authorization': 'Bearer $token'};
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  final authState = ref.watch(authServiceProvider);
  final auth = ref.read(authServiceProvider.notifier);
  final baseUrl = authState.baseUrl ?? 'http://localhost:3000';
  return ApiClient(auth, baseUrl);
});
