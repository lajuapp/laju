import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laju_mobile/features/conversations/domain/group_controller.dart';
import 'package:laju_mobile/features/conversations/presentation/screens/create_group_screen.dart';
import 'package:laju_mobile/features/conversations/presentation/screens/group_profile_screen.dart';
import 'package:laju_mobile/features/conversations/presentation/screens/group_settings_screen.dart';

Widget _buildTestApp(Widget child) {
  return MaterialApp(
    locale: const Locale('en'),
    home: child,
  );
}

void main() {
  setUp(() {
    GroupController.instance.resetToDefaults();
  });

  group('GroupController Unit Tests', () {
    test('Initial default group exists and current user is admin', () {
      final controller = GroupController.instance;
      final group = controller.getGroup('grp-1');

      expect(group, isNotNull);
      expect(group!.name, 'Operations Team');
      expect(controller.isCurrentUserAdmin('grp-1'), isTrue);
      expect(group.members.length, 6);
    });

    test('createGroup creates a new group with creator as admin', () {
      final controller = GroupController.instance;
      final newGroup = controller.createGroup(
        name: 'Alpha Squad',
        description: 'Classified operations channel',
        members: const [
          GroupMemberItem(
            id: 'u1',
            name: 'Dimas',
            phone: '+62 812-5551-0101',
            role: 'Officer',
            isOnline: true,
          ),
          GroupMemberItem(
            id: 'u2',
            name: 'Sari',
            phone: '+62 813-2233-4455',
            role: 'Specialist',
            isOnline: false,
          ),
        ],
        canEditGroupInfo: false,
        canSendMessages: true,
        canAddMembers: false,
        requireApprovalToJoin: true,
      );

      expect(newGroup.id, startsWith('grp-'));
      expect(newGroup.name, 'Alpha Squad');
      expect(newGroup.description, 'Classified operations channel');
      expect(newGroup.canEditGroupInfo, isFalse);
      expect(newGroup.requireApprovalToJoin, isTrue);

      // Current user should be admin and member of new group
      expect(controller.isCurrentUserAdmin(newGroup.id), isTrue);
      expect(newGroup.members.any((m) => m.id == GroupController.currentUserId), isTrue);
      expect(newGroup.members.length, 3); // Current user + 2 added
    });

    test('updatePermissions modifies group permissions', () {
      final controller = GroupController.instance;
      controller.updatePermissions(
        'grp-1',
        canEditGroupInfo: false,
        canSendMessages: false,
        canAddMembers: false,
        requireApprovalToJoin: true,
      );

      final group = controller.getGroup('grp-1');
      expect(group!.canEditGroupInfo, isFalse);
      expect(group.canSendMessages, isFalse);
      expect(group.canAddMembers, isFalse);
      expect(group.requireApprovalToJoin, isTrue);
    });

    test('toggleAdmin promotes and demotes member', () {
      final controller = GroupController.instance;
      final group = controller.getGroup('grp-1')!;
      final member = group.members.firstWhere((m) => m.id == 'm-dimas');
      expect(member.isAdmin, isFalse);

      controller.toggleAdmin('grp-1', 'm-dimas');
      expect(controller.getGroup('grp-1')!.members.firstWhere((m) => m.id == 'm-dimas').isAdmin, isTrue);

      controller.toggleAdmin('grp-1', 'm-dimas');
      expect(controller.getGroup('grp-1')!.members.firstWhere((m) => m.id == 'm-dimas').isAdmin, isFalse);
    });

    test('removeMember removes member from group', () {
      final controller = GroupController.instance;
      final countBefore = controller.getGroup('grp-1')!.members.length;

      controller.removeMember('grp-1', 'm-dimas');
      final groupAfter = controller.getGroup('grp-1')!;

      expect(groupAfter.members.length, countBefore - 1);
      expect(groupAfter.members.any((m) => m.id == 'm-dimas'), isFalse);
    });

    test('updateGroupInfo updates subject and description', () {
      final controller = GroupController.instance;
      controller.updateGroupInfo(
        'grp-1',
        name: 'Alpha Redux',
        description: 'New Description',
      );

      final group = controller.getGroup('grp-1')!;
      expect(group.name, 'Alpha Redux');
      expect(group.description, 'New Description');
    });
  });

  group('Group UI Screen Tests', () {
    testWidgets('CreateGroupScreen displays contacts and toggles selection', (tester) async {
      await tester.pumpWidget(_buildTestApp(const CreateGroupScreen()));
      await tester.pumpAndSettle();

      expect(find.text('New Group'), findsOneWidget);
      expect(find.text('Dimas'), findsOneWidget);
      expect(find.text('Komando Alpha'), findsOneWidget);

      // Tap on Dimas contact to select
      await tester.tap(find.text('Dimas'));
      await tester.pumpAndSettle();

      // Floating Action Button should be visible now that 1 contact is selected
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('GroupSettingsScreen renders admin controls and permission tiles', (tester) async {
      await tester.pumpWidget(_buildTestApp(const GroupSettingsScreen(groupId: 'grp-1')));
      await tester.pumpAndSettle();

      expect(find.text('Group Settings'), findsOneWidget);
      expect(find.text('Edit group info'), findsOneWidget);
      expect(find.text('Send messages'), findsOneWidget);
      expect(find.text('Add other members'), findsOneWidget);
      expect(find.text('Approve new members'), findsOneWidget);
      expect(find.text('Edit group admins'), findsOneWidget);
    });

    testWidgets('GroupProfileScreen renders group profile with settings tile for admin', (tester) async {
      await tester.pumpWidget(_buildTestApp(const GroupProfileScreen(groupId: 'grp-1')));
      await tester.pumpAndSettle();

      expect(find.text('Operations Team'), findsWidgets);
      expect(find.text('Group Settings'), findsOneWidget);
      expect(find.text('Dimas'), findsOneWidget);
    });
  });
}
