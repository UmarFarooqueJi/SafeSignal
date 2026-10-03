// -----------------------------------------------------------------------------
// SafeSignal Mobile Security Suite
// Module: Community Threat Intelligence Service (100% On-Device Engine)
// Author: Umar Farooque (umarfarooque@safesignal.app)
// Copyright (c) 2026 SafeSignal Technologies. All rights reserved.
// -----------------------------------------------------------------------------

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/threat_report.dart';

/// On-Device Threat Intelligence Service.
/// Runs completely air-gapped on local storage. Zero telemetry transmitted.
class CrowdIntelService {
  static final CrowdIntelService _instance = CrowdIntelService._internal();
  factory CrowdIntelService() => _instance;
  CrowdIntelService._internal();

  static const _cacheKey = 'local_blocklist_cache';

  // In-memory cache for fast lookups
  Set<String> _localBlocklist = {};
  bool _initialized = false;

  // ─── Initialize local blocklist ─────────────────────────────────────────
  Future<void> init() async {
    if (_initialized) return;
    await _loadLocalCache();
    _initialized = true;
  }

  Future<void> _loadLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_cacheKey);
      if (json != null) {
        final list = jsonDecode(json) as List;
        _localBlocklist = Set<String>.from(list.map((e) => e.toString()));
      }
    } catch (e) {
      debugPrint('[CrowdIntel] Local cache load error: $e');
    }
  }

  // ─── Fast local blocklist lookup (Zero network) ─────────────────────────
  bool isKnownThreat(String rawValue) {
    final hash = ThreatReport.hashValue(rawValue);
    return _localBlocklist.contains(hash);
  }

  Future<ThreatReport?> lookup(String rawValue) async {
    final hash = ThreatReport.hashValue(rawValue);
    if (!_localBlocklist.contains(hash)) return null;

    return ThreatReport(
      id: hash,
      type: 'local',
      valueHash: hash,
      verdict: 'SCAM',
      reporterCount: 1,
      confidence: 0.95,
      status: 'verified',
      createdAt: DateTime.now(),
    );
  }

  // ─── Save threat to local database ──────────────────────────────────────
  Future<bool> reportThreat({
    required String rawValue,
    required String type,
    required String verdict,
  }) async {
    final hash = ThreatReport.hashValue(rawValue);
    if (verdict == 'SCAM') {
      _localBlocklist.add(hash);
      await _saveLocalCache();
    }
    return true;
  }

  Future<void> _saveLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(_localBlocklist.toList()));
    } catch (e) {
      debugPrint('[CrowdIntel] Cache save error: $e');
    }
  }

  // ─── Local Stats for Dashboard ──────────────────────────────────────────
  Future<Map<String, int>> getStats() async {
    return {
      'total': _localBlocklist.length,
      'scams': _localBlocklist.length,
      'cachedThreats': _localBlocklist.length,
    };
  }
}
