import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laju_mobile/features/home/presentation/screens/home_screen.dart';
import 'package:laju_mobile/features/auth/presentation/screens/welcome_screen.dart';
import 'package:laju_mobile/features/auth/presentation/screens/register_screen.dart';
import 'package:laju_mobile/features/security/presentation/screens/security_screen.dart';
import 'package:laju_mobile/features/security/presentation/screens/chat_lock_screen.dart';
import 'package:laju_mobile/features/lock/presentation/screens/app_lock_screen.dart';
import 'package:laju_mobile/features/settings/presentation/screens/settings_screen.dart';

void main() {
  testWidgets('LAJU Welcome Screen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: WelcomeScreen(),
      ),
    );
    expect(find.text('LAJU'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('I already have an account'), findsOneWidget);
  });

  testWidgets('LAJU Register Screen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: RegisterScreen(),
      ),
    );
    expect(find.byType(RegisterScreen), findsOneWidget);
  });

  testWidgets('LAJU Home Screen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(),
      ),
    );
    expect(find.text('LAJU'), findsOneWidget);
    expect(find.text('Chats'), findsOneWidget);
    expect(find.text('Dimas'), findsOneWidget);
    expect(find.text('Komando Alpha'), findsOneWidget);
  });

  testWidgets('LAJU Security & Settings Screens smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SecurityScreen(),
      ),
    );
    expect(find.text('Security'), findsOneWidget);
    expect(find.text('Your conversations are\nend-to-end encrypted'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: SettingsScreen(),
      ),
    );
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Ridwan'), findsOneWidget);
  });

  testWidgets('LAJU Chat Lock and App Lock Screens smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ChatLockScreen(),
      ),
    );
    expect(find.text('Chat Lock'), findsOneWidget);
    expect(find.text('Keep your chats locked and hidden'), findsOneWidget);
    expect(find.text('Lock chats with biometric'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: AppLockScreen(),
      ),
    );
    expect(find.text('LAJU'), findsOneWidget);
    expect(find.text('Locked'), findsOneWidget);
    expect(find.text('Use fingerprint to unlock'), findsOneWidget);
  });
}
