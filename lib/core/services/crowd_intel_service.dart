import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../constants.dart';
import '../models/threat_report.dart';

/// Crowd-sourced Threat Intelligence Service.
/// Connects to Supabase — 1 user's report protects all users.
class CrowdIntelService {
  static final CrowdIntelService _instance = CrowdIntelService._internal();
  factory CrowdIntelService() => _instance;
  CrowdIntelService._internal();

  SupabaseClient? get _supabase {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  static const _cacheKey = 'crowd_blocklist_cache';
  static const _cacheTimestampKey = 'crowd_blocklist_timestamp';
  static const _cacheMaxAge = Duration(hours: 6);

  // In-memory cache for fast lookups
  Set<String> _localBlocklist = {};
  bool _initialized = false;

  // ─── Initialize & sync blocklist ─────────────────────────────────────────
  Future<void> init() async {
    if (_initialized) return;
    await _loadLocalCache();
    _initialized = true;
    // Sync from Supabase in background (don't block startup)
    _syncBlocklistInBackground();
  }

  Future<void> _loadLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_cacheKey);
      if (json != null) {
        final list = jsonDecode(json) as List;
        _localBlocklist = Set<String>.from(list.map((e) => e.toString()));
        debugPrint('[CrowdIntel] Loaded ${_localBlocklist.length} cached hashes');
      }
    } catch (e) {
      debugPrint('[CrowdIntel] Cache load error: $e');
    }
  }

  void _syncBlocklistInBackground() async {
    final client = _supabase;
    if (client == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final tsString = prefs.getString(_cacheTimestampKey);
      if (tsString != null) {
        final cached = DateTime.tryParse(tsString);
        if (cached != null && DateTime.now().difference(cached) < _cacheMaxAge) {
          debugPrint('[CrowdIntel] Cache is fresh, skipping sync');
          return;
        }
      }

      final response = await client
          .from('blocklist')
          .select('value_hash')
          .gte('confidence', 0.7);

      final hashes = (response as List)
          .map((e) => e['value_hash'] as String)
          .toSet();

      _localBlocklist = hashes;

      // Save to local cache
      await prefs.setString(_cacheKey, jsonEncode(hashes.toList()));
      await prefs.setString(_cacheTimestampKey, DateTime.now().toIso8601String());

      debugPrint('[CrowdIntel] Synced ${hashes.length} verified threats from server');
    } catch (e) {
      debugPrint('[CrowdIntel] Sync error (non-critical): $e');
    }
  }

  // ─── Fast local blocklist lookup (no network) ─────────────────────────────
  bool isKnownThreat(String rawValue) {
    final hash = ThreatReport.hashValue(rawValue);
    return _localBlocklist.contains(hash);
  }

  /// Returns threat details if known, null otherwise
  Future<ThreatReport?> lookup(String rawValue) async {
    final client = _supabase;
    if (client == null) return null;

    final hash = ThreatReport.hashValue(rawValue);

    // Check local cache first
    if (!_localBlocklist.contains(hash)) return null;

    try {
      final response = await client
          .from('threat_reports')
          .select()
          .eq('value_hash', hash)
          .eq('status', 'verified')
          .limit(1)
          .maybeSingle();

      if (response != null) {
        return ThreatReport.fromJson(Map<String, dynamic>.from(response as Map));
      }
    } catch (e) {
      debugPrint('[CrowdIntel] Lookup error: $e');
    }
    return null;
  }

  // ─── Submit a crowd report ───────────────────────────────────────────────
  Future<bool> reportThreat({
    required String rawValue,
    required String type,
    required String verdict,
  }) async {
    final client = _supabase;
    if (client == null) return false;

    final hash = ThreatReport.hashValue(rawValue);
    try {
      // Direct upsert — works without stored procedures
      await client.from('threat_reports').upsert(
        {
          'type': type,
          'value_hash': hash,
          'verdict': verdict,
          'reporter_count': 1,
          'confidence': verdict == 'SCAM' ? 0.75 : 0.55,
          'status': 'pending',
        },
        onConflict: 'value_hash',
        ignoreDuplicates: false,
      );

      // Add to local cache immediately
      if (verdict == 'SCAM') {
        _localBlocklist.add(hash);
        _saveLocalCache();
      }

      debugPrint('[CrowdIntel] Report submitted for $type (hash: ${hash.substring(0, 8)}...)');
      return true;
    } catch (e) {
      debugPrint('[CrowdIntel] Report error (non-critical): $e');
      return false;
    }
  }

  Future<void> _saveLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(_localBlocklist.toList()));
    } catch (e) {
      debugPrint('[CrowdIntel] Cache save error: $e');
    }
  }

  // ─── Stats for home screen ───────────────────────────────────────────────
  Future<Map<String, int>> getStats() async {
    final client = _supabase;
    if (client == null) {
      return {'total': 0, 'scams': 0, 'cachedThreats': _localBlocklist.length};
    }

    try {
      final response = await client
          .from('threat_reports')
          .select('verdict')
          .limit(AppConstants.feedPageSize * 5);

      final list = response as List;
      final scamCount = list.where((e) => e['verdict'] == 'SCAM').length;
      return {
        'total': list.length,
        'scams': scamCount,
        'cachedThreats': _localBlocklist.length,
      };
    } catch (e) {
      return {'total': 0, 'scams': 0, 'cachedThreats': _localBlocklist.length};
    }
  }
}
