/*
 * SafeSignal Mobile Security Suite
 * Module: Real Call Shield & Telecom Fraud Defense Center
 * Author: Umar Farooque (https://github.com/UmarFarooqueJi)
 * Copyright (c) 2026 Umar Farooque (https://github.com/UmarFarooqueJi). All rights reserved.
 *
 * Backed by native Android CallScreeningService:
 * Intercepts incoming calls pre-ring, drops TRAI 140/160 telemarketers,
 * rejects international VoIP spoofers, and maintains live interception logs.
 */
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

class CallShieldScreen extends StatefulWidget {
  const CallShieldScreen({super.key});

  @override
  State<CallShieldScreen> createState() => _CallShieldScreenState();
}

class _BlockedCall {
  final String number;
  final String reason;
  final String formattedTime;

  const _BlockedCall({
    required this.number,
    required this.reason,
    required this.formattedTime,
  });

  factory _BlockedCall.fromJson(Map<String, dynamic> json) {
    return _BlockedCall(
      number: json['number'] as String? ?? 'Private Number',
      reason: json['reason'] as String? ?? 'Unknown Scam Pattern',
      formattedTime: json['formattedTime'] as String? ?? 'Just now',
    );
  }
}

class _CallShieldScreenState extends State<CallShieldScreen> with WidgetsBindingObserver {
  static const _channel = MethodChannel('safesignal/call_shield');

  bool _isScreeningActive = false;
  bool _blockTrai = true;
  bool _blockInternational = true;
  bool _isLoading = true;
  List<_BlockedCall> _blockedCalls = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadState();
    }
  }

  Future<void> _loadState() async {
    try {
      final active = await _channel.invokeMethod<bool>('isCallScreeningActive') ?? false;
      final settings = await _channel.invokeMapMethod<String, dynamic>('getCallShieldSettings');
      final logJson = await _channel.invokeMethod<String>('getBlockedCalls') ?? '[]';

      List<_BlockedCall> logs = [];
      try {
        final decoded = jsonDecode(logJson) as List;
        logs = decoded.map((e) => _BlockedCall.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      } catch (_) {}

      if (mounted) {
        setState(() {
          _isScreeningActive = active;
          if (settings != null) {
            _blockTrai = settings['blockTrai'] as bool? ?? true;
            _blockInternational = settings['blockInternational'] as bool? ?? true;
          }
          _blockedCalls = logs;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _requestScreeningRole() async {
    HapticFeedback.mediumImpact();
    try {
      await _channel.invokeMethod('requestCallScreeningRole');
      // Refresh status after slight delay
      await Future.delayed(const Duration(seconds: 1));
      _loadState();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not request Call Screening role: $e')),
        );
      }
    }
  }

  Future<void> _updateSetting({bool? blockTrai, bool? blockInternational}) async {
    HapticFeedback.selectionClick();
    setState(() {
      if (blockTrai != null) _blockTrai = blockTrai;
      if (blockInternational != null) _blockInternational = blockInternational;
    });

    try {
      await _channel.invokeMethod('updateCallShieldSettings', {
        'blockTrai': _blockTrai,
        'blockInternational': _blockInternational,
      });
    } catch (_) {}
  }

  Future<void> _clearLogs() async {
    HapticFeedback.mediumImpact();
    try {
      await _channel.invokeMethod('clearBlockedCalls');
      setState(() => _blockedCalls = []);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF080C14) : const Color(0xFFF1F5F9);
    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;
    final textMain = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSub = isDark ? Colors.white60 : const Color(0xFF64748B);
    final borderCol = isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textMain, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Call Shield Engine',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: textMain),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: textMain),
            tooltip: 'Refresh Status',
            onPressed: _loadState,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadState,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Active Shield Status Banner ──
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _isScreeningActive
                              ? [const Color(0xFF064E3B), const Color(0xFF065F46)]
                              : [const Color(0xFF1E293B), const Color(0xFF334155)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: (_isScreeningActive ? const Color(0xFF10B981) : Colors.black).withValues(alpha: 0.2),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _isScreeningActive ? Icons.shield_rounded : Icons.shield_outlined,
                                  color: _isScreeningActive ? const Color(0xFF34D399) : const Color(0xFFCBD5E1),
                                  size: 32,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _isScreeningActive ? 'CALL SHIELD ARMED' : 'CALL SHIELD STANDBY',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _isScreeningActive
                                          ? 'Default Call Screening Service active. Unsolicited calls dropped pre-ring.'
                                          : 'SafeSignal must be set as Default Spam Screening app to drop calls.',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.8),
                                        fontSize: 12,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (!_isScreeningActive) ...[
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _requestScreeningRole,
                                icon: const Icon(Icons.verified_user_rounded, size: 18),
                                label: const Text('ACTIVATE NATIVE CALL SHIELD'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ).animate().fadeIn().slideY(begin: 0.05),

                    const SizedBox(height: 24),

                    // ── Active Screening Rules Card ──
                    Text(
                      'ACTIVE INTERCEPTION RULES',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: textSub,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 10),

                    Container(
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: borderCol),
                      ),
                      child: Column(
                        children: [
                          SwitchListTile(
                            value: _blockTrai,
                            onChanged: (val) => _updateSetting(blockTrai: val),
                            activeColor: const Color(0xFF10B981),
                            title: Text(
                              'Block TRAI 140/160 Telemarketers',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textMain),
                            ),
                            subtitle: Text(
                              'Auto-drops commercial advertising and telemarketing prefixes registered with TRAI.',
                              style: TextStyle(fontSize: 11.5, color: textSub),
                            ),
                            secondary: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.campaign_outlined, color: Color(0xFF3B82F6), size: 22),
                            ),
                          ),
                          Divider(height: 1, color: borderCol),
                          SwitchListTile(
                            value: _blockInternational,
                            onChanged: (val) => _updateSetting(blockInternational: val),
                            activeColor: const Color(0xFF10B981),
                            title: Text(
                              'Block International VoIP Spoofing',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textMain),
                            ),
                            subtitle: Text(
                              'Silently drops unsolicited calls from +92, +84, +234, +4470, +93 spoof series.',
                              style: TextStyle(fontSize: 11.5, color: textSub),
                            ),
                            secondary: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.public_off_rounded, color: Color(0xFFEF4444), size: 22),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Live Intercepted Calls Log ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'INTERCEPTED CALLS (${_blockedCalls.length})',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: textSub,
                            letterSpacing: 1.5,
                          ),
                        ),
                        if (_blockedCalls.isNotEmpty)
                          TextButton(
                            onPressed: _clearLogs,
                            child: const Text('Clear Log', style: TextStyle(fontSize: 12, color: Color(0xFFEF4444))),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (_blockedCalls.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: borderCol),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.call_end_rounded, color: textSub.withValues(alpha: 0.5), size: 36),
                            const SizedBox(height: 10),
                            Text(
                              'No Blocked Calls Yet',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textMain),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'When an incoming call matches TRAI or spoof rules, it will be automatically dropped and logged here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 11.5, color: textSub),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _blockedCalls.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final call = _blockedCalls[idx];
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: borderCol),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.phone_disabled_rounded, color: Color(0xFFEF4444), size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        call.number,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: textMain,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        call.reason,
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFFEF4444),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  call.formattedTime,
                                  style: TextStyle(fontSize: 11, color: textSub),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                    const SizedBox(height: 24),

                    // ── Threat Advisory: Digital Arrest ──
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1428) : const Color(0xFFFAF5FF),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isDark ? const Color(0xFF4C1D95) : const Color(0xFFE9D5FF),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.gavel_rounded, color: Color(0xFF9333EA), size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'CBI / Police Digital Arrest Advisory',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : const Color(0xFF581C87),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Government of India warning: Indian law enforcement NEVER puts citizens under "digital arrest" via Skype, WhatsApp, or video calls. Disconnect immediately and dial 1930.',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: isDark ? Colors.white70 : const Color(0xFF6B21A8),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }
}
