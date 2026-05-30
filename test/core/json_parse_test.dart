import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> parseRecommendationEventJson(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Expected JSON object');
  }
  return decoded;
}

void main() {
  group('проверка парсинга JSON ответов API', () {
    test('корректно парсит событие рекомендации', () {
      const raw = '{"surface":"for_you","targetType":"track","targetId":1}';
      final m = parseRecommendationEventJson(raw);
      expect(m['surface'], 'for_you');
      expect(m['targetType'], 'track');
    });

    test('кидает FormatException при неверном формате JSON', () {
      expect(() => parseRecommendationEventJson('not json'), throwsFormatException);
    });
  });
}
