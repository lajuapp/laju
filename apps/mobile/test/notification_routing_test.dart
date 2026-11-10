import 'package:flutter_test/flutter_test.dart';
import 'package:laju_mobile/core/services/app_update_controller.dart';
import 'package:laju_mobile/features/auth/domain/auth_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Notification Routing & Instant Startup Tests', () {
    test('AuthController loads cached user instantly without network wait', () async {
      SharedPreferences.setMockInitialValues({
        'laju_is_authenticated': true,
        'laju_auth_token': 'mock_jwt_token',
        'laju_device_id': 'mock_device_123',
        'laju_user_id': 'user_abc',
        'laju_username': 'john_doe',
        'laju_phone': '+628123456789',
        'laju_email': 'john@example.com',
        'laju_2fa': false,
        'laju_avatar_url': 'https://example.com/avatar.png',
      });

      await AuthController.instance.initSession();

      expect(AuthController.instance.isAuthenticated, isTrue);
      expect(AuthController.instance.currentUser?.username, 'john_doe');
      expect(AuthController.instance.currentUser?.id, 'user_abc');
      expect(AuthController.instance.currentUser?.avatarUrl, 'https://example.com/avatar.png');
    });

    test('AppUpdateController init is non-blocking and loads version safely', () async {
      final ctrl = AppUpdateController.instance;
      await ctrl.init();
      // Should not throw and controller should be initialized
      expect(ctrl.currentVersion, isNotEmpty);
      expect(ctrl.targetVersion, isNotEmpty);
    });
  });
}
