import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../constants/api_constants.dart';
import '../utils/storage_helper.dart';
import 'api_exception.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  late Dio _dio;

  factory ApiClient() {
    return _instance;
  }

  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Interceptors: Auth → Retry → Logging → Error
    _dio.interceptors.add(_AuthInterceptor());
    _dio.interceptors.add(_RetryInterceptor(_dio));
    _dio.interceptors.add(_LoggingInterceptor());
    _dio.interceptors.add(_ErrorInterceptor());
  }

  Dio get dio => _dio;

  // GET request
  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
      );
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  // POST request
  Future<Response<dynamic>> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  // PUT request
  Future<Response<dynamic>> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  // DELETE request
  Future<Response<dynamic>> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}

// Token ekleyen interceptor. Her istekte suffix + tokenTail loglanır.
// Karar ağacı: (1) Login response A/B için userId farklı mı? Hayır→backend bug. Evet→
// (2) suffix logları A/B'de farklı mı? Hayır→StorageHelper cache/save temizliği. Evet→
// (3) Hive box adları A/B'de farklı mı? Hayır→suffix/box naming. Evet→UI reset/init veya provider cache.
class _AuthInterceptor extends Interceptor {
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    final token = StorageHelper.getToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
      if (kDebugMode) {
        final suffix = StorageHelper.getUserStorageSuffix();
        final tokenTail = token.length >= 6 ? token.substring(token.length - 6) : token;
        debugPrint('API request: suffix=$suffix tokenTail=...$tokenTail path=${options.path}');
      }
    }
    handler.next(options);
  }
}

// Retry interceptor - exponential backoff (network optimizasyonu)
class _RetryInterceptor extends Interceptor {
  final Dio _dio;
  _RetryInterceptor(this._dio);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (_shouldRetry(err)) {
      final opts = err.requestOptions;
      final retryCount = opts.extra['retry_count'] as int? ?? 0;
      if (retryCount < 2) {
        final delay = Duration(milliseconds: 500 * (1 << retryCount));
        await Future.delayed(delay);
        opts.extra['retry_count'] = retryCount + 1;
        try {
          final response = await _dio.fetch(opts);
          handler.resolve(response);
        } catch (e) {
          handler.next(err);
        }
        return;
      }
    }
    handler.next(err);
  }

  bool _shouldRetry(DioException err) {
    return err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError ||
        (err.response?.statusCode ?? 0) >= 500;
  }
}

// Logging interceptor - sadece debug modda (performans için release'de kapalı)
class _LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('🚀 REQUEST[${options.method}] => PATH: ${options.path}');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('✅ RESPONSE[${response.statusCode}] => ${response.requestOptions.path}');
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      final fullUrl = '${err.requestOptions.baseUrl}${err.requestOptions.path}';
      debugPrint('❌ ERROR[${err.response?.statusCode}] => ${err.requestOptions.path}');
      if (err.response == null) {
        debugPrint('   Bağlantı kurulamadı. Kullanılan adres: $fullUrl');
        debugPrint('   Backend çalışıyor mu? Telefon ve PC aynı WiFi\'de mi?');
      }
    }
    handler.next(err);
  }
}

// Error interceptor
class _ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // 401 Unauthorized - Token geçersiz veya süresi dolmuş
    if (err.response?.statusCode == 401) {
      // Token'ı temizle ve logout yap
      StorageHelper.clearUserData();
    }
    handler.next(err);
  }
}
