import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_service.dart';

class ApiClient {
  ApiClient(this._auth, this.baseUrl) {
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
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            await _auth.logout();
          }
          handler.next(error);
        },
      ),
    );
  }

  late final Dio _dio;
  final AuthService _auth;
  final String baseUrl;

  Dio get dio => _dio;

  Future<T> get<T>(String path, {Map<String, dynamic>? params}) async {
    final response = await _dio.get(path, queryParameters: params);
    return response.data as T;
  }

  Future<T> post<T>(String path, {dynamic data}) async {
    final response = await _dio.post(path, data: data);
    return response.data as T;
  }

  Future<T> put<T>(String path, {dynamic data}) async {
    final response = await _dio.put(path, data: data);
    return response.data as T;
  }

  Future<T> delete<T>(String path) async {
    final response = await _dio.delete(path);
    return response.data as T;
  }

  Future<Map<String, String>> authHeaders() async {
    final token = await _auth.getToken();
    if (token == null) {
      return {};
    }
    return {'Authorization': 'Bearer $token'};
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  final authState = ref.watch(authServiceProvider);
  final auth = ref.read(authServiceProvider.notifier);
  final baseUrl = authState.baseUrl ?? 'http://10.0.2.2:8002';
  return ApiClient(auth, baseUrl);
});
