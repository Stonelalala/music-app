import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_service.dart';

String resolveApiBaseUrl(String? rawBaseUrl) {
  final normalized = rawBaseUrl?.trim() ?? '';
  if (normalized.isEmpty) {
    return '';
  }
  return normalized.replaceFirst(RegExp(r'/+$'), '');
}

class ApiClient {
  ApiClient(this._auth, this.baseUrl) {
    _dio = _createDio();
  }

  late Dio _dio;
  final AuthService _auth;
  final String baseUrl;

  bool get isConfigured => baseUrl.isNotEmpty;

  Never _throwMissingBaseUrl() {
    throw StateError('服务器地址未配置，请重新登录或检查连接设置');
  }

  Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    dio.interceptors.add(
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
            final alreadyRetried =
                error.requestOptions.extra['authRetried'] == true;
            if (!alreadyRetried) {
              final refreshedToken = await _auth.reauthenticateIfPossible();
              if (refreshedToken != null) {
                final requestOptions = error.requestOptions;
                requestOptions.headers['Authorization'] =
                    'Bearer $refreshedToken';
                requestOptions.extra['authRetried'] = true;
                try {
                  final response = await _dio.fetch(requestOptions);
                  return handler.resolve(response);
                } on DioException catch (retryError) {
                  if (retryError.response?.statusCode == 401) {
                    await _auth.logout();
                  }
                  return handler.next(retryError);
                } catch (_) {}
              }
            }
            await _auth.logout();
          }

          if (_shouldRetryNetworkError(error)) {
            final alreadyRetried =
                error.requestOptions.extra['networkRetried'] == true;
            if (!alreadyRetried) {
              final retried = await _retryWithFreshConnection(
                error.requestOptions,
              );
              if (retried != null) {
                return handler.resolve(retried);
              }
            }
          }

          handler.next(error);
        },
      ),
    );

    return dio;
  }

  Dio get dio => _dio;

  Future<void> refreshConnection() async {
    _dio.close(force: true);
    _dio = _createDio();
  }

  bool _shouldRetryNetworkError(DioException error) {
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return true;
    }

    return error.error is SocketException;
  }

  Future<Response<dynamic>?> _retryWithFreshConnection(
    RequestOptions requestOptions,
  ) async {
    await refreshConnection();
    requestOptions.extra['networkRetried'] = true;
    final token = await _auth.getToken();
    if (token != null) {
      requestOptions.headers['Authorization'] = 'Bearer $token';
    } else {
      requestOptions.headers.remove('Authorization');
    }

    try {
      return await _dio.fetch(requestOptions);
    } on DioException {
      return null;
    }
  }

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? params,
    CancelToken? cancelToken,
  }) async {
    if (!isConfigured) {
      _throwMissingBaseUrl();
    }
    final response = await _dio.get(
      path,
      queryParameters: params,
      cancelToken: cancelToken,
    );
    return response.data as T;
  }

  Future<T> post<T>(String path, {dynamic data}) async {
    if (!isConfigured) {
      _throwMissingBaseUrl();
    }
    final response = await _dio.post(path, data: data);
    return response.data as T;
  }

  Future<T> put<T>(String path, {dynamic data}) async {
    if (!isConfigured) {
      _throwMissingBaseUrl();
    }
    final response = await _dio.put(path, data: data);
    return response.data as T;
  }

  Future<T> delete<T>(String path) async {
    if (!isConfigured) {
      _throwMissingBaseUrl();
    }
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
  final baseUrl = resolveApiBaseUrl(authState.baseUrl);
  return ApiClient(auth, baseUrl);
});
