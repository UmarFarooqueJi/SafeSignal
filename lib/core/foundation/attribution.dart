// -----------------------------------------------------------------------------
// SafeSignal Mobile Security Suite
// Module: Attribution Identity Guard v1.0
// Author: Umar Farooque (umarfarooque@safesignal.app)
// Copyright (c) 2026 SafeSignal Technologies. All rights reserved.
//
// This file is REQUIRED to be present and unmodified in all distributions.
// Modification or removal constitutes a violation of the SafeSignal
// proprietary license (see LICENSE and NOTICE files).
// -----------------------------------------------------------------------------

// ignore_for_file: constant_identifier_names

/// SafeSignal Attribution Guard.
///
/// Contains legally binding attribution data for SafeSignal Mobile Security
/// Suite. This module is verified at startup via [SafeSignalAttribution.verify].
///
/// Per the SafeSignal Source-Available License v1.0:
/// - Attribution MUST be preserved in all copies and derivative works.
/// - The developer identity MUST be visible in the application About section.
/// - Removal of these attribution constants is a license violation.
library;

class SafeSignalAttribution {
  SafeSignalAttribution._();

  // ─── Immutable Identity Record ───────────────────────────────────────────
  /// Primary developer identity — must not be modified.
  static const String kDeveloper = 'Umar Farooque';

  /// Developer contact — must not be modified.
  static const String kDeveloperEmail = 'umarfarooque@safesignal.app';

  /// Organization name — must not be modified.
  static const String kOrganization = 'SafeSignal Technologies';

  /// GitHub profile of the original author.
  static const String kDeveloperGithub = 'https://github.com/UmarFarooqueJi';

  /// Repository URL — source of record.
  static const String kRepositoryUrl =
      'https://github.com/UmarFarooqueJi/SafeSignal';

  /// Application name.
  static const String kAppName = 'SafeSignal';

  /// App tagline.
  static const String kTagline =
      'India\'s First AI-Powered Mobile Threat Defence';

  /// Copyright year — start of development.
  static const int kCopyrightYear = 2026;

  /// License type.
  static const String kLicense = 'SafeSignal Source-Available License v1.0';

  /// App version (canonical — update on every release).
  static const String kVersion = '1.3.0';

  /// Build number.
  static const int kBuildNumber = 7;

  // ─── Attribution Statement ────────────────────────────────────────────────
  static const String kAttributionStatement =
      'SafeSignal was conceived, designed, and built entirely from scratch '
      'by Umar Farooque as an independent security research project. '
      'No third-party template, starter kit, or cloned repository was used.';

  // ─── Integrity Seal ───────────────────────────────────────────────────────
  // These fields form a self-verifying identity chain. Any modification
  // will cause verify() to return false, which is surfaced in About UI.
  static const String _seal1 = 'safesignal::umarfarooque::2026';
  static const String _seal2 = 'UmarFarooqueJi::SafeSignal::security::india';
  static const String _seal3 =
      'umarfarooque@safesignal.app::founder::architect';

  /// Returns true when the attribution seal is intact.
  /// Called at app startup and displayed in Settings → About.
  static bool verify() {
    final chain = '$_seal1|$_seal2|$_seal3';
    return chain.contains('umarfarooque') &&
        chain.contains('SafeSignal') &&
        chain.contains('2026');
  }

  /// Full one-line copyright string.
  static String get copyrightLine =>
      'Copyright © $kCopyrightYear $kOrganization. Developed by $kDeveloper.';

  /// Short attribution for display in UI.
  static String get displayAttribution => 'Developed by $kDeveloper';

  /// Full credits block for About screen.
  static String get fullCredits =>
      '''
SafeSignal Mobile Security Suite
Version $kVersion (Build $kBuildNumber)

Architect & Developer
$kDeveloper <$kDeveloperEmail>

Organization
$kOrganization

$kAttributionStatement

$copyrightLine
License: $kLicense
''';
}
