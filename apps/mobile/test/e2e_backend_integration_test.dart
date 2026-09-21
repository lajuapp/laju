import 'package:flutter_test/flutter_test.dart';
import 'package:laju_mobile/core/core.dart';
import 'package:laju_mobile/features/auth/domain/auth_controller.dart';
import 'package:laju_mobile/features/conversations/domain/conversation_service.dart';
import 'package:laju_mobile/features/conversations/domain/group_controller.dart';
import 'package:laju_mobile/features/settings/domain/account_controller.dart';

void main() {
  group('EnvConfig & Network Layer Tests', () {
    test('EnvConfig resolves default platform base URL and timeout', () {
      final config = EnvConfig.instance;
      expect(config.apiBaseUrl, isNotEmpty);
      expect(config.apiTimeout.inSeconds, greaterThan(0));
      expect(config.enableMockFallback, isTrue);
    });

    test('EnvConfig transforms HTTP base URL to WebSocket URL', () {
      final config = EnvConfig.instance;
      config.setApiBaseUrl('http://10.0.2.2:3000');
      expect(config.websocketUrl, equals('ws://10.0.2.2:3000'));

      config.setApiBaseUrl('https://api.laju.id');
      expect(config.websocketUrl, equals('wss://api.laju.id'));

      config.resetOverride();
    });

    test('ApiClient maintains auth state and headers', () {
      final client = ApiClient.instance;
      client.setAuth(
        token: 'mock-jwt-token-xyz',
        deviceId: 'dev-device-123',
        userId: 'usr-456',
      );

      expect(client.authToken, equals('mock-jwt-token-xyz'));
      expect(client.deviceId, equals('dev-device-123'));
      expect(client.userId, equals('usr-456'));

      client.clearAuth();
      expect(client.authToken, isNull);
      expect(client.deviceId, isNull);
      expect(client.userId, isNull);
    });

    test('ApiResponse parses success and error payloads correctly', () {
      final successResp = ApiResponse<Map<String, dynamic>>.success(
        200,
        {'status': 'ok'},
        {'status': 'ok'},
      );
      expect(successResp.isSuccess, isTrue);
      expect(successResp.statusCode, equals(200));
      expect(successResp.data?['status'], equals('ok'));

      final errorResp = ApiResponse<dynamic>.error(
        401,
        'Unauthorized access',
        {'message': 'Unauthorized access'},
      );
      expect(errorResp.isSuccess, isFalse);
      expect(errorResp.statusCode, equals(401));
      expect(errorResp.errorMessage, equals('Unauthorized access'));
    });
  });

  group('ConversationService Data Contract Tests', () {
    test('UserDirectoryItem deserializes from backend JSON', () {
      final json = {
        'id': 'usr-789',
        'username': 'jhon_doe',
        'email': 'satria@laju.id',
        'phoneNumber': '+628123456789',
        'status': 'Active Duty • Quantum Shield Active',
      };

      final item = UserDirectoryItem.fromJson(json);
      expect(item.id, equals('usr-789'));
      expect(item.username, equals('jhon_doe'));
      expect(item.email, equals('satria@laju.id'));
      expect(item.phoneNumber, equals('+628123456789'));
      expect(item.status, contains('Quantum Shield'));
    });

    test('ConversationService generates valid message payload', () async {
      final service = ConversationService.instance;
      final msg = await service.sendMessage(
        conversationId: 'conv-test-123',
        text: 'Encrypted tactical update',
        clientMessageId: 'custom-client-id-001',
      );

      expect(msg, isNotNull);
      expect(msg!.content, equals('Encrypted tactical update'));
      expect(msg.id, equals('custom-client-id-001'));
      expect(msg.isOutgoing, isTrue);
    });
  });

  group('AuthController Backend Flow Tests', () {
    test('AuthController registers and initializes user state', () async {
      final auth = AuthController.instance;
      auth.sendOtp(
        identifier: 'e2e_user@laju.id',
        username: 'e2e_tester',
        password: 'Password123!',
        isRegister: true,
      );

      expect(auth.pendingIdentifier, equals('e2e_user@laju.id'));
      expect(auth.pendingUsername, equals('e2e_tester'));
      expect(auth.pendingIsRegister, isTrue);

      final verified = auth.verifyOtp('123456');
      expect(verified, isTrue);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.currentUser?.username, equals('e2e_tester'));
    });

    test('AuthController 2FA challenge flow', () async {
      final auth = AuthController.instance;
      AccountController.instance.setTwoStepVerification(true, pin: '654321');

      auth.sendOtp(identifier: '+62811223344');
      final verified = auth.verifyOtp('123456');
      expect(verified, isTrue);
      expect(auth.requiresTwoFactor, isTrue);

      final pinVerified = auth.verifyTwoFactorPin('654321');
      expect(pinVerified, isTrue);
      expect(auth.requiresTwoFactor, isFalse);
      expect(auth.isAuthenticated, isTrue);

      // Clean up
      AccountController.instance.setTwoStepVerification(false);
    });
  });

  group('GroupController Async Backend Flow Tests', () {
    test('createGroupAsync creates group and retains admin ownership', () async {
      final gc = GroupController.instance;
      final group = await gc.createGroupAsync(
        name: 'E2E Tactical Squad',
        description: 'End-to-End verified group',
        members: [
          const GroupMemberItem(
            id: 'm-dimas',
            name: 'Dimas',
            phone: '+62812345678',
            role: 'Officer',
          ),
        ],
      );

      expect(group.name, equals('E2E Tactical Squad'));
      expect(group.members, hasLength(2)); // Anda (creator) + Dimas
      expect(gc.isCurrentUserAdmin(group.id), isTrue);
    });
  });
}
