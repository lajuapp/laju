import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laju_mobile/core/core.dart';
import 'package:laju_mobile/features/auth/domain/auth_controller.dart';
import 'package:laju_mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:laju_mobile/features/auth/presentation/screens/otp_verification_screen.dart';
import 'package:laju_mobile/features/auth/presentation/screens/register_screen.dart';
import 'package:laju_mobile/features/auth/presentation/screens/two_factor_verify_screen.dart';
import 'package:laju_mobile/features/settings/domain/account_controller.dart';

Widget _buildTestApp(Widget child) {
  return MaterialApp(
    locale: const Locale('en'),
    home: child,
  );
}

void main() {
  setUp(() {
    AuthController.instance.resetState();
    AppLockController.instance.setAppLockEnabled(true);
    AppLockController.instance.lockApp();
    AccountController.instance.setTwoStepVerification(true, pin: '123456');
  });

  group('AuthController Unit Tests', () {
    test('sendOtp sets pendingIdentifier and generates demo code', () {
      final auth = AuthController.instance;
      final sent = auth.sendOtp(
        identifier: 'test@cyber.gov.id',
        username: 'cyber_agent',
        isRegister: true,
      );

      expect(sent, isTrue);
      expect(auth.pendingIdentifier, 'test@cyber.gov.id');
      expect(auth.pendingUsername, 'cyber_agent');
      expect(auth.pendingIsRegister, isTrue);
      expect(auth.isIdentifierEmail, isTrue);
      expect(auth.activeOtpCode, '123456');
    });

    test('sendOtp handles phone number identifiers', () {
      final auth = AuthController.instance;
      auth.sendOtp(
        identifier: '+62 812 9988 7766',
        username: 'recon_lead',
        isRegister: true,
      );

      expect(auth.pendingIdentifier, '+62 812 9988 7766');
      expect(auth.isIdentifierEmail, isFalse);
    });

    test('verifyOtp succeeds with valid code and triggers 2FA when enabled', () {
      final auth = AuthController.instance;
      auth.sendOtp(identifier: 'satria@cyber.gov.id', username: 'jhon_doe');

      // 2FA is enabled in setUp
      final verified = auth.verifyOtp('123456');
      expect(verified, isTrue);
      expect(auth.requiresTwoFactor, isTrue);
    });

    test('verifyOtp fails with incorrect code', () {
      final auth = AuthController.instance;
      auth.sendOtp(identifier: 'satria@cyber.gov.id');

      final verified = auth.verifyOtp('000000');
      expect(verified, isFalse);
    });

    test('verifyTwoFactorPin verifies 6-digit PIN and completes authentication', () {
      final auth = AuthController.instance;
      auth.sendOtp(identifier: 'satria@cyber.gov.id', username: 'jhon_doe');
      auth.verifyOtp('123456');
      expect(auth.requiresTwoFactor, isTrue);

      final pinVerified = auth.verifyTwoFactorPin('123456');
      expect(pinVerified, isTrue);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.requiresTwoFactor, isFalse);
      expect(auth.currentUser?.username, 'jhon_doe');
    });

    test('verifyTwoFactorBiometric completes authentication', () {
      final auth = AuthController.instance;
      auth.sendOtp(identifier: '+62 812 3456 7890');
      auth.verifyOtp('123456');

      final bioVerified = auth.verifyTwoFactorBiometric();
      expect(bioVerified, isTrue);
      expect(auth.isAuthenticated, isTrue);
    });

    test('loginWithPassword triggers 2FA and verifies', () {
      final auth = AuthController.instance;
      final loggedIn = auth.loginWithPassword(
        identifier: 'jhon_doe',
        password: 'SecurePass123!',
      );

      expect(loggedIn, isTrue);
      expect(auth.requiresTwoFactor, isTrue);

      final pinResult = auth.verifyTwoFactorPin('123456');
      expect(pinResult, isTrue);
      expect(auth.isAuthenticated, isTrue);
    });
  });

  group('AppLockController Security Tests', () {
    test('AppLock starts locked when enabled and unlocks', () {
      final lock = AppLockController.instance;
      lock.setAppLockEnabled(true);
      lock.lockApp();
      expect(lock.isCurrentlyLocked, isTrue);

      lock.unlockApp();
      expect(lock.isCurrentlyLocked, isFalse);
    });

    test('Disabling AppLock automatically unlocks', () {
      final lock = AppLockController.instance;
      lock.setAppLockEnabled(true);
      lock.lockApp();
      expect(lock.isCurrentlyLocked, isTrue);

      lock.setAppLockEnabled(false);
      expect(lock.isCurrentlyLocked, isFalse);
    });
  });

  group('Auth Screens Widget Tests', () {
    testWidgets('RegisterScreen renders Phone and Email tabs with Username input', (tester) async {
      await tester.pumpWidget(_buildTestApp(const RegisterScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Create Account'), findsWidgets);
      expect(find.text('Username *'), findsOneWidget);
      expect(find.text('Phone Number'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Send Verification Code'), findsOneWidget);

      // Switch to Email tab
      await tester.tap(find.text('Email Address'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.mail_outline_rounded), findsOneWidget);
    });

    testWidgets('LoginScreen renders 3-way identifier tabs and switches OTP/Password modes', (tester) async {
      await tester.pumpWidget(_buildTestApp(const LoginScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.text('Phone Number'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Username'), findsOneWidget);

      expect(find.text('Sign in with OTP'), findsOneWidget);
      expect(find.text('Sign in with Password'), findsOneWidget);

      // Tap password mode
      await tester.tap(find.text('Sign in with Password'));
      await tester.pumpAndSettle();

      expect(find.text('Password'), findsOneWidget);
    });

    testWidgets('OtpVerificationScreen displays 6 digit cells and demo quick-fill', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          const OtpVerificationScreen(
            identifier: 'satria@cyber.gov.id',
            isRegister: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Verify Code (OTP)'), findsOneWidget);
      expect(find.text('satria@cyber.gov.id'), findsOneWidget);
      expect(find.text('Demo OTP Code: 123456'), findsOneWidget);
    });

    testWidgets('TwoFactorVerifyScreen renders 6 PIN dots, keypad, and biometric button', (tester) async {
      await tester.pumpWidget(_buildTestApp(const TwoFactorVerifyScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Two-Step Verification'), findsOneWidget);
      expect(find.byIcon(Icons.verified_user_rounded), findsOneWidget);
      expect(find.byIcon(Icons.fingerprint_rounded), findsOneWidget);
      expect(find.byIcon(Icons.backspace_outlined), findsOneWidget);
    });
  });
}
