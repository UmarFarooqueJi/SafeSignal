import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Helper extracting the exact logic implemented in _loadOrInitScoreHistory
Future<List<int>> loadOrInitScoreHistory(int currentScore) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    List<String>? stored = prefs.getStringList('safesignal_score_history_7d');
    List<int> history;
    if (stored != null && stored.isNotEmpty) {
      history = stored.map((s) => int.tryParse(s) ?? currentScore).toList();
      while (history.length < 7) {
        history.insert(0, currentScore);
      }
      if (history.length > 7) {
        history = history.sublist(history.length - 7);
      }
      history[history.length - 1] = currentScore;
    } else {
      history = List.filled(7, currentScore);
    }
    await prefs.setStringList('safesignal_score_history_7d', history.map((e) => e.toString()).toList());
    return history;
  } catch (_) {
    return List.filled(7, currentScore);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Device Audit Score History', () {
    test('Initial run creates honest baseline without synthetic jitter or fake dips', () async {
      SharedPreferences.setMockInitialValues({});

      final history = await loadOrInitScoreHistory(82);

      expect(history.length, equals(7));
      expect(history, equals([82, 82, 82, 82, 82, 82, 82]));

      // Verify no synthetic subtraction (-8, -4, -12, etc.) occurred
      expect(history.every((score) => score == 82), isTrue);
    });

    test('Preserves existing recorded scans and appends latest scan at today slot', () async {
      SharedPreferences.setMockInitialValues({
        'safesignal_score_history_7d': ['70', '72', '75', '80', '82', '85', '85'],
      });

      final history = await loadOrInitScoreHistory(88);

      expect(history.length, equals(7));
      expect(history.last, equals(88));
      expect(history[0], equals(70));
      expect(history[1], equals(72));
    });

    test('Pads short historical lists honestly without fabricating volatility', () async {
      SharedPreferences.setMockInitialValues({
        'safesignal_score_history_7d': ['75', '80'],
      });

      final history = await loadOrInitScoreHistory(90);

      expect(history.length, equals(7));
      expect(history.last, equals(90));
      // First slots are padded flatly
      expect(history[0], equals(90));
    });
  });
}
