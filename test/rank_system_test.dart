import 'package:flutter_test/flutter_test.dart';
import 'package:fbla_member_app/models/fbla_rank.dart';

void main() {
  group('FBLARankSystem.rankForCoins', () {
    test('zero coins is the entry tier (Intern)', () {
      expect(FBLARankSystem.rankForCoins(0).name, 'Intern');
    });

    test('just below a threshold keeps the lower tier', () {
      expect(FBLARankSystem.rankForCoins(99).name, 'Intern');
    });

    test('exactly on a threshold promotes', () {
      expect(FBLARankSystem.rankForCoins(100).name, 'Assistant');
      expect(FBLARankSystem.rankForCoins(250).name, 'Coordinator');
    });

    test('very high coin counts clamp to the top tier (CEO)', () {
      expect(FBLARankSystem.rankForCoins(999999).name, 'CEO');
    });
  });

  group('FBLARankSystem.indexForRank / tierByName', () {
    test('indexForRank is order-aligned and case-insensitive', () {
      expect(FBLARankSystem.indexForRank('Intern'), 0);
      expect(FBLARankSystem.indexForRank('assistant'), 1);
    });

    test('unknown rank name resolves to the first tier', () {
      expect(FBLARankSystem.tierByName('Nonexistent').name, 'Intern');
    });
  });

  group('FBLARankSystem.progressToNextRank', () {
    test('is 0 at the start of a tier', () {
      // Exactly at Assistant (100); next is Coordinator (250).
      expect(FBLARankSystem.progressToNextRank(100), 0.0);
    });

    test('is halfway between two thresholds', () {
      // Intern(0) -> Assistant(100); 50 coins is halfway.
      expect(FBLARankSystem.progressToNextRank(50), 0.5);
    });

    test('is 1.0 at the top tier (no next rank)', () {
      expect(FBLARankSystem.progressToNextRank(999999), 1.0);
    });
  });

  group('FBLARankSystem.coinsToNextRank', () {
    test('reports the gap to the next threshold', () {
      // At 50 coins, Assistant is at 100 -> 50 to go.
      expect(FBLARankSystem.coinsToNextRank(50), 50);
    });

    test('is 0 at the top tier', () {
      expect(FBLARankSystem.coinsToNextRank(999999), 0);
    });
  });
}
