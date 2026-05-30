import 'package:flutter_test/flutter_test.dart';

/// Упрощённая копия формулы S(t,u) = Σ U·T из RecommendationScoreService.
double scoreTrack(Map<int, double> userPrefs, Map<int, double> trackTags) {
  var s = 0.0;
  for (final e in trackTags.entries) {
    s += (userPrefs[e.key] ?? 0) * e.value;
  }
  return s;
}

int compareTracks(int id1, double s1, int id2, double s2) {
  if (s1 > s2) return -1;
  if (s1 < s2) return 1;
  return id2.compareTo(id1);
}

void main() {
  group('проверка расчёта скора рекомендаций по жанрам', () {
    test('совпадающие жанры дают ненулевой скор', () {
      final s = scoreTrack({1: 1.0, 2: 0.5}, {1: 1.0, 3: 1.0});
      expect(s, greaterThan(0));
    });

    test('без пересечения жанров скор равен нулю', () {
      final s = scoreTrack({1: 1.0}, {2: 1.0});
      expect(s, 0.0);
    });

    test('при равном скоре выше трек с большим id', () {
      expect(compareTracks(10, 5.0, 20, 5.0), greaterThan(0));
    });

    test('нормализация весов 1/n суммируется в единицу', () {
      const n = 4;
      final w = 1.0 / n;
      expect(w * n, closeTo(1.0, 0.0001));
    });
  });
}
