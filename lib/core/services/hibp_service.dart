import 'package:dio/dio.dart';

class BreachInfo {
  final String title;
  final String domain;
  final String breachDate;
  final int pwnCount;
  final String description;
  final List<String> dataClasses;
  final bool isVerified;
  final String logoPath; 

  BreachInfo({
    required this.title,
    required this.domain,
    required this.breachDate,
    required this.pwnCount,
    required this.description,
    required this.dataClasses,
    required this.isVerified,
    required this.logoPath,
  });
}

class HibpService {
  final Dio _dio = Dio();

  // Using XposedOrNot API as a completely free alternative to HIBP.
  // It returns real data breaches without requiring an API key.
  Future<List<BreachInfo>> checkEmail(String email) async {
    int retries = 3;
    int delayMs = 1000;

    while (retries > 0) {
      try {
        final response = await _dio.get(
          'https://api.xposedornot.com/v1/check-email/${Uri.encodeComponent(email)}',
          options: Options(
            headers: {'User-Agent': 'SafeSignal-App'},
            receiveTimeout: const Duration(seconds: 10),
          ),
        );

        if (response.statusCode == 200) {
          final data = response.data;
          
          if (data.containsKey('Error') && data['Error'] == 'Not found') {
            return [];
          }
          
          if (data.containsKey('breaches') && data['breaches'] != null) {
            final breachesArray = data['breaches'] as List;
            if (breachesArray.isNotEmpty && breachesArray.first is List) {
              final List<dynamic> breachNames = breachesArray.first;
                final strName = name.toString().trim();
                final domain = strName.contains('.')
                    ? strName
                    : '${strName.replaceAll(RegExp(r'\s+'), '').toLowerCase()}.com';
                return BreachInfo(
                  title: strName,
                  domain: domain,
                  breachDate: 'Historical Leak',
                pwnCount: 0,
                description: 'Your data was exposed in the $name data breach. We strongly advise changing your password.',
                dataClasses: ['Email addresses', 'Passwords'],
                isVerified: true,
                logoPath: 'https://haveibeenpwned.com/Content/Images/PwnedLogo.png',
              )).toList();
            }
          }
          return [];
        } else {
          throw Exception('XposedOrNot Error: ${response.statusCode}');
        }
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) {
          return [];
        } else if (e.response?.statusCode == 429) {
          retries--;
          if (retries == 0) rethrow;
          await Future.delayed(Duration(milliseconds: delayMs));
          delayMs *= 2;
        } else {
          retries--;
          if (retries == 0) rethrow;
          await Future.delayed(Duration(milliseconds: delayMs));
        }
      } catch (e) {
        retries--;
        if (retries == 0) rethrow;
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }
    return [];
  }
}
