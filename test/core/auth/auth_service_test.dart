import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music/core/auth/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthService.init', () {
    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
    });

    test('does not keep an expired stored token as authenticated', () async {
      FlutterSecureStorage.setMockInitialValues({
        'jwt_token': 'expired-token',
        'server_base_url': 'http://example.com',
      });

      final auth = _ExpiredSessionAuthService();
      await auth.init();

      expect(auth.isAuthenticated, isFalse);
      expect(auth.token, isNull);
    });
  });
}

class _ExpiredSessionAuthService extends AuthService {
  @override
  Future<bool> ensureActiveSession() async {
    await Future<void>.delayed(Duration.zero);
    await logout();
    return false;
  }
}
