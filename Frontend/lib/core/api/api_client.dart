import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'
    show GlobalKey, NavigatorState, ScaffoldMessenger, SnackBar, Text;
import '../constants/api_constants.dart';
import '../utils/storage_helper.dart';
import 'api_exception.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  late Dio _dio;

  /// main.dart'tan set edilir; 401'de login'e yönlendirmek için kullanılır.
  static GlobalKey<NavigatorState>? navigatorKey;

  factory ApiClient() {
    return _instance;
  }

  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Interceptors: Auth -> Retry -> Logging -> Error
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

  // PATCH request
  Future<Response<dynamic>> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.patch(
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

// Token ekleyen interceptor. Her istekte suffix + tokenTail loglanir.
// Karar agaci: (1) Login response A/B icin userId farkli mi? Hayir -> backend bug. Evet ->
// (2) suffix loglari A/B'de farkli mi? Hayir -> StorageHelper cache/save temizligi. Evet ->
// (3) Hive box adlari A/B'de farkli mi? Hayir -> suffix/box naming. Evet -> UI reset/init veya provider cache.
class _AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = StorageHelper.getToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
      if (kDebugMode) {
        final suffix = StorageHelper.getUserStorageSuffix();
        final tokenTail = token.length >= 6
            ? token.substring(token.length - 6)
            : token;
        debugPrint(
          'API request: suffix=$suffix tokenTail=...$tokenTail path=${options.path}',
        );
      }
    } else if (kDebugMode) {
      debugPrint('API request: token missing path=${options.path}');
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
    final method = err.requestOptions.method.toUpperCase();
    final isIdempotent =
        method == 'GET' || method == 'HEAD' || method == 'OPTIONS';
    if (!isIdempotent) {
      return false;
    }

    return err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError ||
        (err.response?.statusCode ?? 0) >= 500;
  }
}

// Logging interceptor - sadece debug modda (performans icin release'de kapali)
class _LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('REQUEST[${options.method}] => PATH: ${options.path}');
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    if (kDebugMode) {
      debugPrint(
        'RESPONSE[${response.statusCode}] => ${response.requestOptions.path}',
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      final fullUrl = '${err.requestOptions.baseUrl}${err.requestOptions.path}';
      debugPrint(
        'ERROR[${err.response?.statusCode}] => ${err.requestOptions.path}',
      );
      if (err.response?.data != null) {
        debugPrint('   RESPONSE BODY: ${err.response?.data}');
      }
      if (err.response == null) {
        if (err.type == DioExceptionType.connectionError) {
          debugPrint('   Baglanti kurulamadi. Kullanilan adres: $fullUrl');
          debugPrint(
            '   Backend calisiyor mu? Telefon ve PC ayni WiFi\'de mi?',
          );
        } else if (err.type == DioExceptionType.connectionTimeout ||
            err.type == DioExceptionType.receiveTimeout ||
            err.type == DioExceptionType.sendTimeout) {
          debugPrint(
            '   Istek zaman asimina ugradi. AI coach icin daha uzun sure gerekebilir.',
          );
        } else if (err.type == DioExceptionType.cancel) {
          debugPrint('   Istek iptal edildi.');
        } else {
          debugPrint('   Istek yanit donmeden basarisiz oldu. URL: $fullUrl');
        }
      }
    }
    handler.next(err);
  }
}

// Error interceptor — 401 alındığında token temizle ve login'e yönlendir.
class _ErrorInterceptor extends Interceptor {
  // Auth endpoint'leri 401 dönebilir (yanlış şifre vb.), oturum temizlenmemeli.
  static const _authPaths = {'/api/auth/login', '/api/auth/register'};

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      final path = err.requestOptions.path;
      final isAuthEndpoint = _authPaths.any((p) => path.endsWith(p));
      if (!isAuthEndpoint) {
        // Token süresi dolmuş veya geçersiz → oturumu kapat.
        StorageHelper.clearUserData();
        final ctx = ApiClient.navigatorKey?.currentContext;
        if (ctx != null) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            const SnackBar(
              content: Text('Oturumunuz sona erdi. Lütfen tekrar giriş yapın.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        ApiClient.navigatorKey?.currentState?.pushNamedAndRemoveUntil(
          '/login',
          (route) => false,
        );
      }
    }
    handler.next(err);
  }
}
