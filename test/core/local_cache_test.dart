import 'package:flutter_test/flutter_test.dart';

/// Упрощённый аналог локального кэша (SharedPreferences).
class InMemoryStringCache {
  final _data = <String, String>{};

  Future<void> setString(String key, String value) async {
    _data[key] = value;
  }

  Future<String?> getString(String key) async => _data[key];

  Future<void> remove(String key) async {
    _data.remove(key);
  }
}

void main() {
  group('проверка локального кэширования на клиенте', () {
    late InMemoryStringCache cache;

    setUp(() {
      cache = InMemoryStringCache();
    });

    test('сохраняет и читает строковые данные по ключу', () async {
      await cache.setString('auth_token', 'abc');
      expect(await cache.getString('auth_token'), 'abc');
    });

    test('перезапись ключа обновляет значение', () async {
      await cache.setString('nick', 'old');
      await cache.setString('nick', 'new');
      expect(await cache.getString('nick'), 'new');
    });

    test('удаление ключа делает значение недоступным', () async {
      await cache.setString('tmp', 'x');
      await cache.remove('tmp');
      expect(await cache.getString('tmp'), isNull);
    });
  });
}
