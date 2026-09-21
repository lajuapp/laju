import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laju_mobile/features/settings/domain/data_storage_controller.dart';
import 'package:laju_mobile/features/settings/presentation/screens/data_storage_screen.dart';
import 'package:laju_mobile/features/settings/presentation/screens/manage_storage_screen.dart';
import 'package:laju_mobile/features/settings/presentation/screens/network_usage_screen.dart';
import 'package:laju_mobile/features/settings/presentation/screens/proxy_settings_screen.dart';

Widget _createTestWidget(Widget child) {
  return MaterialApp(
    locale: const Locale('en'),
    home: child,
  );
}

void main() {
  group('DataStorageController Tests', () {
    test('Format bytes correctly', () {
      expect(DataStorageController.formatBytes(0), '0 B');
      expect(DataStorageController.formatBytes(1024), '1.0 KB');
      expect(DataStorageController.formatBytes(1024 * 1024), '1.0 MB');
      expect(DataStorageController.formatBytes(1024 * 1024 * 1024), '1.0 GB');
    });

    test('Clear cache resets cache bytes to 0', () {
      final controller = DataStorageController.instance;
      expect(controller.lajuCacheBytes, greaterThan(0));
      controller.clearCache();
      expect(controller.lajuCacheBytes, equals(0));
    });

    test('Clear chat media updates chat storage and total media', () {
      final controller = DataStorageController.instance;
      final chat = controller.chatStorageList.first;
      expect(chat.totalBytes, greaterThan(0));

      controller.clearEntireChat(chat.id);
      expect(chat.totalBytes, equals(0));
    });

    test('Reset network statistics zeroes all network counters', () {
      final controller = DataStorageController.instance;
      controller.resetNetworkStats();
      expect(controller.totalNetworkSent, equals(0));
      expect(controller.totalNetworkReceived, equals(0));
      expect(controller.callsCount, equals(0));
      expect(controller.messagesCountSent, equals(0));
    });

    test('Auto-download preferences update correctly', () {
      final controller = DataStorageController.instance;
      controller.setMobileDataTypes({'photos', 'videos'});
      expect(controller.mobileDataTypes, contains('photos'));
      expect(controller.mobileDataTypes, contains('videos'));
      expect(controller.mobileDataTypes.contains('documents'), isFalse);
    });

    test('Proxy config updates correctly', () {
      final controller = DataStorageController.instance;
      controller.setUseProxy(true);
      expect(controller.useProxy, isTrue);

      controller.updateProxyConfig(
        host: '192.168.1.10',
        port: 8080,
        secret: 'test_token',
      );
      expect(controller.proxyHost, '192.168.1.10');
      expect(controller.proxyPort, 8080);
      expect(controller.proxySecret, 'test_token');
    });
  });

  group('Data & Storage Screens Widget Tests', () {
    testWidgets('DataStorageScreen renders correctly', (tester) async {
      await tester.pumpWidget(_createTestWidget(const DataStorageScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Data and Storage'), findsOneWidget);
      expect(find.text('Manage storage'), findsOneWidget);
      expect(find.text('Network usage'), findsOneWidget);
      expect(find.text('Media auto-download'), findsOneWidget);
      expect(find.text('When using mobile data'), findsOneWidget);
      expect(find.text('When connected on Wi-Fi'), findsOneWidget);
      expect(find.text('When roaming'), findsOneWidget);
      expect(find.text('Proxy'), findsNWidgets(2));
    });

    testWidgets('ManageStorageScreen renders and searches chats', (tester) async {
      await tester.pumpWidget(_createTestWidget(const ManageStorageScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Manage storage'), findsOneWidget);
      expect(find.text('Device Storage'), findsOneWidget);
      expect(find.text('Encrypted Media'), findsOneWidget);
      expect(find.text('Database & Keys'), findsOneWidget);
      expect(find.text('Cached Files'), findsOneWidget);
      expect(find.text('Chats Storage'), findsOneWidget);
      expect(find.text('Dimas'), findsOneWidget);

      // Test search filter
      await tester.enterText(find.byType(TextField), 'Dimas');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'Dimas'), findsOneWidget);
      expect(find.text('Komando Alpha'), findsNothing);
    });

    testWidgets('NetworkUsageScreen renders summary and categories', (tester) async {
      await tester.pumpWidget(_createTestWidget(const NetworkUsageScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Network usage'), findsOneWidget);
      expect(find.text('Total Sent'), findsOneWidget);
      expect(find.text('Total Received'), findsOneWidget);
      expect(find.text('Encrypted Calls'), findsOneWidget);
      expect(find.text('Media'), findsOneWidget);
      expect(find.text('Messages'), findsOneWidget);
      expect(find.text('Reset Statistics'), findsOneWidget);
    });

    testWidgets('ProxySettingsScreen renders form controls', (tester) async {
      await tester.pumpWidget(_createTestWidget(const ProxySettingsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Proxy'), findsOneWidget);
      expect(find.text('Use Proxy'), findsOneWidget);
      expect(find.text('Connection Status'), findsOneWidget);
      expect(find.text('Proxy Configuration'), findsOneWidget);
      expect(find.text('Server Host / IP'), findsOneWidget);
      expect(find.text('Port'), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(find.text('Save Settings'), findsOneWidget);
    });
  });
}
