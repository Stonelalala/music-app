import 'package:flutter_test/flutter_test.dart';
import 'package:music/core/http/api_client.dart';

void main() {
  group('resolveApiBaseUrl', () {
    test('returns empty string when base url is missing', () {
      expect(resolveApiBaseUrl(null), '');
      expect(resolveApiBaseUrl(''), '');
      expect(resolveApiBaseUrl('   '), '');
    });

    test('trims whitespace and trailing slash', () {
      expect(
        resolveApiBaseUrl(' https://music.example.com/ '),
        'https://music.example.com',
      );
    });
  });
}
