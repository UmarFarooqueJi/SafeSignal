import 'package:dio/dio.dart';
import '../constants.dart';

class DioClient {
  static Dio? _dio;
  static Dio? _secureDio;

  static Dio get instance {
    _dio ??= _createDio(baseUrl: AppConstants.apiBaseUrl);
    return _dio!;
  }

  // For external APIs like VirusTotal, SafeBrowsing etc - with better timeout
  static Dio get secureInstance {
    _secureDio ??= _createDio(
      baseUrl: '',
      connectTimeout: 8,
      receiveTimeout: 10,
    );
    return _secureDio!;
  }

  static Dio _createDio({
    required String baseUrl,
    int connectTimeout = AppConstants.apiTimeoutSeconds,
    int receiveTimeout = AppConstants.deepAnalysisTimeoutSeconds,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: Duration(seconds: connectTimeout),
        receiveTimeout: Duration(seconds: receiveTimeout),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-App-Name': 'SafeSignal',
          'X-App-Version': '1.0.0',
        },
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    // Security + Logging interceptor
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // Add request ID for tracing
          options.headers['X-Request-ID'] = DateTime.now().millisecondsSinceEpoch.toString();
          handler.next(options);
        },
        onResponse: (response, handler) {
          handler.next(response);
        },
        onError: (DioException e, ErrorInterceptorHandler handler) async {
          // Retry logic for timeouts - 1 retry only
          if ((e.type == DioExceptionType.connectionTimeout ||
                  e.type == DioExceptionType.receiveTimeout) &&
              e.requestOptions.extra['retry'] != true) {
            e.requestOptions.extra['retry'] = true;
            try {
              final response = await dio.fetch(e.requestOptions);
              return handler.resolve(response);
            } catch (_) {}
          }
          handler.next(e);
        },
      ),
    );

    // Only log in debug mode
    dio.interceptors.add(
      LogInterceptor(
        requestBody: false,
        responseBody: false,
        error: true,
        logPrint: (o) {
          // Avoid printing in release
          assert(() {
            // ignore: avoid_print
            print(o);
            return true;
          }());
        },
      ),
    );

    return dio;
  }

  static void resetInstance() {
    _dio?.close();
    _secureDio?.close();
    _dio = null;
    _secureDio = null;
  }
}
