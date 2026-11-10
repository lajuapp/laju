import 'package:flutter_test/flutter_test.dart';
import 'package:laju_mobile/core/services/app_update_controller.dart';

void main() {
  group('AppUpdateController - Semver comparison', () {
    test('compares identical versions', () {
      expect(AppUpdateController.compareSemver('1.0.0', '1.0.0'), 0);
      expect(AppUpdateController.compareSemver('1.0.1', '1.0.1'), 0);
      expect(AppUpdateController.compareSemver('v1.0.1', '1.0.1'), 0);
      expect(AppUpdateController.compareSemver('1.0.1+2', '1.0.1'), 0);
    });

    test('detects older version correctly (1.0.0 vs 1.0.1)', () {
      expect(AppUpdateController.compareSemver('1.0.0', '1.0.1'), -1);
      expect(AppUpdateController.compareSemver('1.0.0', '1.1.0'), -1);
      expect(AppUpdateController.compareSemver('0.9.9', '1.0.0'), -1);
      expect(AppUpdateController.compareSemver('1.0.0+1', '1.0.1+2'), -1);
    });

    test('detects newer version correctly', () {
      expect(AppUpdateController.compareSemver('1.0.1', '1.0.0'), 1);
      expect(AppUpdateController.compareSemver('2.0.0', '1.9.9'), 1);
      expect(AppUpdateController.compareSemver('1.0.2', '1.0.1'), 1);
    });
  });

  group('AppSystemConfig serialization', () {
    test('parses json correctly with default values', () {
      final json = {
        'minAndroidVersion': '1.0.1',
        'latestAndroidVersion': '1.0.2',
        'minIosVersion': '1.0.0',
        'latestIosVersion': '1.0.2',
        'forceUpdate': false,
        'maintenanceMode': false,
        'playStoreUrl': 'market://details?id=com.laju.mobile',
        'appStoreUrl': 'https://apps.apple.com/app/laju/id6740000000',
        'releaseNotes': 'Perbaikan performa dan keamanan.',
      };

      final config = AppSystemConfig.fromJson(json);
      expect(config.minAndroidVersion, '1.0.1');
      expect(config.latestAndroidVersion, '1.0.2');
      expect(config.minIosVersion, '1.0.0');
      expect(config.latestIosVersion, '1.0.2');
      expect(config.forceUpdate, false);
      expect(config.maintenanceMode, false);
      expect(config.playStoreUrl, 'market://details?id=com.laju.mobile');
      expect(config.appStoreUrl, 'https://apps.apple.com/app/laju/id6740000000');
      expect(config.releaseNotes, 'Perbaikan performa dan keamanan.');
    });
  });
}
