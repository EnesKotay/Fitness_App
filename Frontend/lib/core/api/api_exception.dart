import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../constants/api_constants.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  ApiException({required this.message, this.statusCode, this.data});

  @override
  String toString() => message;

  factory ApiException.fromDioError(dynamic error) {
    if (error is DioException) {
      if (error.response != null) {
        // Backend'den gelen hata
        final statusCode = error.response!.statusCode;
        final data = error.response!.data;

        String message = 'Bir hata oluştu';

        if (data is Map && data.containsKey('error')) {
          message = data['error'].toString();
        } else if (data is String) {
          message = data;
        }

        return ApiException(
          message: message,
          statusCode: statusCode,
          data: data,
        );
      } else if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        // Timeout hatası
        return ApiException(
          message: 'Bağlantı zaman aşımına uğradı. Lütfen tekrar deneyin.',
          statusCode: null,
        );
      } else if (error.type == DioExceptionType.connectionError) {
        // İnternet / sunucu bağlantı hatası (fiziksel cihazda sık: yanlış IP veya backend kapalı)
        final hint = kDebugMode
            ? ' Backend adresi: ${ApiConstants.baseUrl} — Backend çalışıyor ve telefon aynı WiFi\'de mi?'
            : '';
        return ApiException(
          message: 'Sunucuya bağlanılamadı. İnternet bağlantınızı kontrol edin.$hint',
          statusCode: null,
        );
      } else {
        // Diğer hatalar
        return ApiException(
          message: error.message?.toString() ?? 'Beklenmeyen bir hata oluştu',
          statusCode: null,
        );
      }
    } else {
      // DioException değilse
      return ApiException(
        message: error.toString(),
        statusCode: null,
      );
    }
  }
}
