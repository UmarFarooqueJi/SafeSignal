// -----------------------------------------------------------------------------
// SafeSignal Mobile Security Suite
// Module: Identity Exposure & Dark Web Intelligence Service
// Author: Umar Farooque (https://github.com/UmarFarooqueJi)
// Copyright (c) 2026 SafeSignal Technologies. All rights reserved.
// XposedOrNot breach analytics for dark-web credential monitoring.
// -----------------------------------------------------------------------------
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class BreachInfo {
  final String title;
  final String domain;
  final String breachDate;
  final int pwnCount;
  final String description;
  final List<String> dataClasses;
  final bool isVerified;
  final String logoPath;
  final String industry;
  final String passwordRisk;
  final String? referenceUrl;

  const BreachInfo({
    required this.title,
    required this.domain,
    required this.breachDate,
    required this.pwnCount,
    required this.description,
    required this.dataClasses,
    required this.isVerified,
    required this.logoPath,
    this.industry = 'General',
    this.passwordRisk = 'unknown',
    this.referenceUrl,
  });
}

class HibpService {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 12),
      validateStatus: (status) => true,
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) SafeSignal/1.0',
        'Accept': 'application/json',
      },
    ),
  );

  Future<List<BreachInfo>> checkEmail(String email) async {
    final cleanEmail = email.trim().toLowerCase();

    // 1. Try Deep Breach-Analytics endpoint (returns full details, logos, dates, data fields)
    try {
      final res = await _dio.get(
        'https://api.xposedornot.com/v1/breach-analytics',
        queryParameters: {'email': cleanEmail},
      );

      if (res.statusCode == 200 && res.data is Map) {
        final data = res.data as Map;

        // Check if no breach found
        if (data.containsKey('Error') &&
            data['Error'].toString().toLowerCase().contains('not found')) {
          return [];
        }

        final exposed = data['ExposedBreaches'];
        if (exposed == null) {
          // Clean email: no breaches recorded on dark web databases
          return [];
        }
        if (exposed is Map && exposed['breaches_details'] is List) {
          final list = exposed['breaches_details'] as List;
          final result = <BreachInfo>[];

          for (final item in list) {
            if (item is Map) {
              final title =
                  item['breach']?.toString().trim() ?? 'Unknown Breach';
              final domain = item['domain']?.toString().trim() ?? '';
              final details =
                  item['details']?.toString().trim() ??
                  'Data records compromised in unauthorized access.';
              final logo = item['logo']?.toString().trim() ?? '';
              final industry =
                  item['industry']?.toString().trim() ?? 'Technology';
              final passRisk =
                  item['password_risk']?.toString().trim() ?? 'unknown';
              final rawDate = item['xposed_date']?.toString().trim() ?? '';
              final date = rawDate.isNotEmpty ? rawDate : 'Historical';
              final records =
                  int.tryParse(item['xposed_records']?.toString() ?? '0') ?? 0;
              final ref = item['references']?.toString().trim();
              final verified =
                  item['verified']?.toString().toLowerCase() == 'yes';

              final rawData =
                  item['xposed_data']?.toString() ??
                  'Email addresses;Passwords';
              final dataClasses = rawData
                  .split(';')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList();

              result.add(
                BreachInfo(
                  title: title,
                  domain: domain.isNotEmpty
                      ? domain
                      : '$title.com'.toLowerCase(),
                  breachDate: date,
                  pwnCount: records,
                  description: details,
                  dataClasses: dataClasses.isNotEmpty
                      ? dataClasses
                      : ['Email addresses', 'Passwords'],
                  isVerified: verified,
                  logoPath: logo.isNotEmpty
                      ? logo
                      : 'https://xposedornot.com/static/logos/$title.png',
                  industry: industry,
                  passwordRisk: passRisk,
                  referenceUrl: (ref != null && ref.startsWith('http'))
                      ? ref
                      : null,
                ),
              );
            }
          }

          if (result.isNotEmpty) return result;
        }
      }
    } catch (e) {
      debugPrint('breach-analytics query error: $e');
    }

    // 2. Fallback to basic check-email endpoint if analytics is busy or rate-limited
    try {
      final res = await _dio.get(
        'https://api.xposedornot.com/v1/check-email/${Uri.encodeComponent(cleanEmail)}',
      );

      if (res.statusCode == 200 && res.data is Map) {
        final data = res.data as Map;
        if (data['Error'] != null &&
            data['Error'].toString().toLowerCase().contains('not found')) {
          return [];
        }

        if (data.containsKey('breaches') && data['breaches'] != null) {
          final breachesArray = data['breaches'] as List;
          if (breachesArray.isNotEmpty && breachesArray.first is List) {
            final List<dynamic> breachNames = breachesArray.first;
            return breachNames.map((name) {
              final strName = name.toString().trim();
              final domain = strName.contains('.')
                  ? strName
                  : '${strName.replaceAll(RegExp(r'\s+'), '').toLowerCase()}.com';
              return BreachInfo(
                title: strName,
                domain: domain,
                breachDate: 'Verified Leak Record',
                pwnCount: 0,
                description:
                    'Your account credentials associated with $strName were identified in public dark web leak databases.',
                dataClasses: [
                  'Email addresses',
                  'Encrypted Passwords',
                  'Account Credentials',
                ],
                isVerified: true,
                logoPath: 'https://xposedornot.com/static/logos/$strName.png',
                industry: 'Online Service',
                passwordRisk: 'encrypted',
              );
            }).toList();
          }
        }
      }
    } catch (e) {
      debugPrint('check-email fallback error: $e');
    }

    return [];
  }
}
