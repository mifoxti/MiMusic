import 'package:flutter_test/flutter_test.dart';

import 'package:mimusic/core/studio/studio_constants.dart';

void main() {
  group('проверка нормализации жанровых тегов', () {
    test('алиас «Поп» преобразуется в id pop', () {
      expect(normalizeStudioGenreId('Поп'), 'pop');
    });

    test('normalizeStudioGenreList убирает дубликаты', () {
      expect(
        normalizeStudioGenreList(['rock', 'Rock', 'metal']),
        ['rock', 'metal'],
      );
    });

    test('неизвестная строка не попадает в список', () {
      expect(
        normalizeStudioGenreList(['unknown_genre_xyz']),
        isEmpty,
      );
    });
  });
}
