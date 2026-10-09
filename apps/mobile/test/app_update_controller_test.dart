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
        'latestAndroidVersion': '1.0.1',
        'forceUpdate': false,
        'maintenanceMode': false,
        'apkUrl': '/admin/app-config/download-apk',
        'apkSize': 1234567,
        'releaseNotes': 'Perbaikan performa dan keamanan.',
      };

      final config = AppSystemConfig.fromJson(json);
      expect(config.minAndroidVersion, '1.0.1');
      expect(config.latestAndroidVersion, '1.0.1');
      expect(config.forceUpdate, false);
      expect(config.maintenanceMode, false);
      expect(config.apkUrl, '/admin/app-config/download-apk');
      expect(config.apkSize, 1234567);
      expect(config.releaseNotes, 'Perbaikan performa dan keamanan.');
    });
  });
}
