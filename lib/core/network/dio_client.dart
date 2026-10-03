// -----------------------------------------------------------------------------
// SafeSignal Mobile Security Suite
// Module: HTTP Client Factory (Dio)
// Author: Umar Farooque (https://github.com/UmarFarooqueJi)
// Copyright (c) 2026 Umar Farooque (https://github.com/UmarFarooqueJi). All rights reserved.
// -----------------------------------------------------------------------------

import 'package:dio/dio.dart';
import '../constants.dart';

class DioClient {
  static Dio? _dio;

  static Dio get instance {
    _dio ??= _createDio();
    return _dio!;
  }

  static Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.apiBaseUrlRelease,
        connectTimeout: const Duration(seconds: AppConstants.apiTimeoutSeconds),
        receiveTimeout:
            const Duration(seconds: AppConstants.deepAnalysisTimeoutSeconds),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Logging interceptor
    dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        error: true,
      ),
    );

    // Retry interceptor
    dio.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException e, ErrorInterceptorHandler handler) async {
          if (e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout) {
            // Could add retry logic here
          }
          handler.next(e);
        },
      ),
    );

    return dio;
  }

  static void resetInstance() {
    _dio = null;
  }
}
