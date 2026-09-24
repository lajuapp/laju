import 'dart:ui' as ui;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../core/core.dart';
import '../../../../core/services/local_database.dart';
import '../../../conversations/domain/models/conversation_model.dart';
import '../../../conversations/domain/conversation_service.dart';
import '../../../conversations/presentation/widgets/conversation_tile.dart';
import '../../../conversations/presentation/widgets/conversation_options_sheet.dart';
import '../../../messaging/presentation/screens/chat_screen.dart';
import '../../../messaging/presentation/screens/group_chat_screen.dart';
import '../../../calls/presentation/screens/active_call_screen.dart';
import '../../../status/presentation/screens/status_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../../conversations/presentation/screens/new_chat_screen.dart';
import '../../../settings/presentation/screens/my_qr_code_screen.dart';
import '../../../lock/presentation/screens/app_lock_screen.dart';
import '../../../conversations/presentation/screens/locked_chats_screen.dart';
import '../../../conversations/presentation/screens/archived_chats_screen.dart';
import '../../../calls/presentation/screens/new_call_contact_picker_screen.dart';
import '../../../calls/domain/call_session_controller.dart';
import '../../../settings/domain/account_controller.dart';

class HomeScreen extends StatefulWidget {
  static final ValueNotifier<int> activeTabNotifier = ValueNotifier<int>(0);

  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentBottomNavIndex = 0;
  String _selectedFilter = 'All';
  bool _isSearchExpanded = false;
  final TextEditingController _searchController = TextEditingController();
  final List<String> _filters = ['All', 'Unread', 'Groups', 'Favorites'];

  List<Map<String, dynamic>> _callLogs = [];

  @override
  void initState() {
    super.initState();
    _currentBottomNavIndex = HomeScreen.activeTabNotifier.value;
    HomeScreen.activeTabNotifier.addListener(_onTabChanged);
    ConversationService.instance.conversationsNotifier.addListener(_onConversationsSync);
    CallSessionController.instance.addListener(_onCallSessionChanged);
    _loadConversations();
    _loadCallLogs();
  }

  void _onConversationsSync() {
    if (mounted && !_isSearchExpanded) {
      final apiConvs = ConversationService.instance.conversationsNotifier.value;
      if (apiConvs.isNotEmpty && !ConversationModel.areListsEqual(_conversations, apiConvs)) {
        setState(() {
          _conversations = apiConvs;
        });
      }
    }
  }

  void _onCallSessionChanged() {
    if (mounted && _currentBottomNavIndex == 2) {
      _loadCallLogs();
    }
  }

  Future<void> _loadCallLogs() async {
    try {
      final logs = await LocalDatabase.instance.getCallLogs();
      if (mounted) {
        setState(() {
          _callLogs = logs;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadConversations() async {
    // Step 1: Always check local SQLite cache so local mutations (unlock/pin/archive) apply instantly
    final cached = await ConversationService.instance.getConversationsFromCache();
    if (mounted && cached.isNotEmpty) {
      if (!ConversationModel.areListsEqual(_conversations, cached)) {
        setState(() {
          _conversations = cached;
          _isLoadingConversations = false;
        });
      }
    } else if (mounted && _conversations.isEmpty) {
      setState(() => _isLoadingConversations = true);
    }

    // Step 2: Fetch from server in background silently (stale-while-revalidate)
    try {
      final apiConvs = await ConversationService.instance.fetchConversations();
      if (mounted) {
        if (!ConversationModel.areListsEqual(_conversations, apiConvs)) {
          setState(() {
            if (apiConvs.isNotEmpty) _conversations = apiConvs;
            _isLoadingConversations = false;
          });
        } else if (_isLoadingConversations) {
          setState(() {
            _isLoadingConversations = false;
          });
        }
      }
    } catch (_) {
      if (mounted && _isLoadingConversations) {
        setState(() {
          _isLoadingConversations = false;
        });
      }
    }
  }

  void _onTabChanged() {
    if (mounted && _currentBottomNavIndex != HomeScreen.activeTabNotifier.value) {
      setState(() {
        _currentBottomNavIndex = HomeScreen.activeTabNotifier.value;
      });
      if (_currentBottomNavIndex == 2) {
        _loadCallLogs();
      }
    }
  }

  @override
  void dispose() {
    ConversationService.instance.conversationsNotifier.removeListener(_onConversationsSync);
    CallSessionController.instance.removeListener(_onCallSessionChanged);
    HomeScreen.activeTabNotifier.removeListener(_onTabChanged);
    super.dispose();
  }

  List<ConversationModel> _conversations = ConversationService.instance.inMemoryConversations ?? [];
  bool _isLoadingConversations = false;

  List<ConversationModel> get _filteredConversations {
    final blocked = AccountController.instance.blockedContacts;
    var list = _conversations
        .where((c) =>
            (c.isLocked != true) &&
            (c.isArchived != true) &&
            !blocked.contains(c.title) &&
            !blocked.contains(c.id))
        .toList();
    switch (_selectedFilter) {
      case 'Unread':
        list = list.where((c) => c.unreadCount > 0).toList();
        break;
      case 'Groups':
        list = list.where((c) => c.isGroup).toList();
        break;
      case 'Favorites':
        final pinned = list.where((c) => c.isPinned == true).toList();
        list = pinned.isNotEmpty ? pinned : list.take(2).toList();
        break;
      default:
        break;
    }
    list.sort((a, b) {
      final aPin = a.isPinned == true;
      final bPin = b.isPinned == true;
      if (aPin && !bPin) return -1;
      if (!aPin && bPin) return 1;
      return b.lastMessageTime.compareTo(a.lastMessageTime);
    });

    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list.where((c) =>
          c.title.toLowerCase().contains(query) ||
          c.lastMessage.toLowerCase().contains(query)).toList();
    }

    return list;
  }

  void _handleConversationOptions(ConversationModel conv) async {
    final action = await ConversationOptionsSheet.show(context, conversation: conv);
    if (action == null || !mounted) return;

    final index = _conversations.indexWhere((c) => c.id == conv.id);
    if (index == -1) return;

    switch (action) {
      case ConversationActionType.togglePin:
        final newPinned = !_conversations[index].isPinned;
        final updated = _conversations[index].copyWith(isPinned: newPinned);
        setState(() {
          _conversations[index] = updated;
        });
        await ConversationService.instance.updateConversationLocally(updated);
        if (mounted) {
          LajuToast.info(context, newPinned ? 'Chat disematkan ke posisi paling atas' : 'Sematan chat dilepas');
        }
        break;

      case ConversationActionType.lockChat:
        final newLocked = !_conversations[index].isLocked;
        final updated = _conversations[index].copyWith(isLocked: newLocked);
        setState(() {
          _conversations[index] = updated;
        });
        await ConversationService.instance.updateConversationLocally(updated);
        if (mounted) {
          LajuToast.info(context, newLocked ? 'Chat dikunci dan dipindahkan ke Locked Chats' : 'Kunci chat dibuka');
        }
        break;

      case ConversationActionType.toggleArchive:
        final newArchived = !_conversations[index].isArchived;
        final updated = _conversations[index].copyWith(isArchived: newArchived);
        setState(() {
          _conversations[index] = updated;
        });
        await ConversationService.instance.updateConversationLocally(updated);
        if (mounted) {
          LajuToast.info(context, newArchived ? 'Chat dipindahkan ke arsip' : 'Chat dibuka dari arsip');
        }
        break;

      case ConversationActionType.toggleMute:
        final newMuted = !_conversations[index].isMuted;
        final updated = _conversations[index].copyWith(isMuted: newMuted);
        setState(() {
          _conversations[index] = updated;
        });
        await ConversationService.instance.updateConversationLocally(updated);
        if (mounted) {
          LajuToast.info(context, newMuted ? 'Notifikasi obrolan dibisukan' : 'Notifikasi obrolan aktif kembali');
        }
        break;

      case ConversationActionType.toggleRead:
        final isUnread = _conversations[index].unreadCount > 0;
        final updated = _conversations[index].copyWith(unreadCount: isUnread ? 0 : 1);
        setState(() {
          _conversations[index] = updated;
        });
        await ConversationService.instance.updateConversationLocally(updated);
        if (mounted) {
          LajuToast.info(context, isUnread ? 'Ditandai sudah dibaca' : 'Ditandai belum dibaca');
        }
        break;

      case ConversationActionType.addLabel:
        LajuToast.info(context, 'Label kategori obrolan diperbarui');
        break;

      case ConversationActionType.clearChat:
        _showClearChatConfirmation(_conversations[index]);
        break;

      case ConversationActionType.deleteChat:
        _showDeleteChatConfirmation(_conversations[index]);
        break;

      case ConversationActionType.exitGroup:
        _showExitGroupConfirmation(_conversations[index]);
        break;

      case ConversationActionType.blockContact:
        _showBlockContactConfirmation(_conversations[index]);
        break;

      case ConversationActionType.reportContact:
        showReportUserSheet(
          context,
          reportedUserId: conv.id,
          reportedUserName: conv.title,
        );
        break;
    }
  }

  void _showDeleteChatConfirmation(ConversationModel conv) {
    final isDark = ThemeModeController.instance.isDarkMode(context);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 22),
            ),
            const SizedBox(width: 12),
            const Text(
              'Hapus Chat?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Riwayat pesan dan media dengan "${conv.title}" akan dihapus secara permanen dari perangkat ini.',
          style: TextStyle(
            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              'Batal',
              style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF64748B)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              setState(() {
                _conversations.removeWhere((c) => c.id == conv.id);
              });
              await ConversationService.instance.deleteConversation(conv.id);
              await LocalDatabase.instance.deleteConversation(conv.id);
              if (mounted) {
                LajuToast.info(context, 'Obrolan telah dihapus');
              }
            },
            child: const Text('Hapus Chat'),
          ),
        ],
      ),
    );
  }

  void _showClearChatConfirmation(ConversationModel conv) {
    final isDark = ThemeModeController.instance.isDarkMode(context);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cleaning_services_rounded, color: Color(0xFFF59E0B), size: 22),
            ),
            const SizedBox(width: 12),
            const Text(
              'Bersihkan Pesan?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Semua isi pesan di dalam obrolan "${conv.title}" akan dibersihkan.',
          style: TextStyle(
            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              'Batal',
              style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF64748B)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await LocalDatabase.instance.clearMessages(conv.id);
              final idx = _conversations.indexWhere((c) => c.id == conv.id);
              if (idx != -1) {
                final updated = _conversations[idx].copyWith(lastMessage: 'Pesan telah dibersihkan');
                setState(() {
                  _conversations[idx] = updated;
                });
                await ConversationService.instance.updateConversationLocally(updated);
              }
              if (mounted) {
                LajuToast.info(context, 'Riwayat pesan telah dibersihkan');
              }
            },
            child: const Text('Bersihkan'),
          ),
        ],
      ),
    );
  }

  void _showExitGroupConfirmation(ConversationModel conv) {
    final isDark = ThemeModeController.instance.isDarkMode(context);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.exit_to_app_rounded, color: Color(0xFFEF4444), size: 22),
            ),
            const SizedBox(width: 12),
            const Text(
              'Keluar dari Grup?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Anda tidak akan lagi menerima pesan dari grup "${conv.title}".',
          style: TextStyle(
            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              'Batal',
              style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF64748B)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              setState(() {
                _conversations.removeWhere((c) => c.id == conv.id);
              });
              await ConversationService.instance.leaveGroup(conv.id);
              if (mounted) {
                LajuToast.info(context, 'Anda telah keluar dari grup');
              }
            },
            child: const Text('Keluar Grup'),
          ),
        ],
      ),
    );
  }

  void _showBlockContactConfirmation(ConversationModel conv) {
    final isDark = ThemeModeController.instance.isDarkMode(context);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.block_rounded, color: Color(0xFFEF4444), size: 22),
            ),
            const SizedBox(width: 12),
            const Text(
              'Blokir Kontak?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Kontak "${conv.title}" tidak akan dapat mengirim pesan atau melakukan panggilan kepada Anda.',
          style: TextStyle(
            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              'Batal',
              style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF64748B)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              AccountController.instance.addBlockedContact(conv.title);
              setState(() {
                _conversations.removeWhere((c) => c.id == conv.id);
              });
              if (mounted) {
                LajuToast.info(context, 'Kontak ${conv.title} telah diblokir');
              }
            },
            child: const Text('Blokir'),
          ),
        ],
      ),
    );
  }

  void _openChat(ConversationModel conv) async {
    if (conv.isGroup) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GroupChatScreen(
            groupId: conv.id,
            groupName: conv.title,
          ),
        ),
      );
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            conversationId: conv.id,
            title: conv.title,
            isGroup: conv.isGroup,
            avatarUrl: conv.avatarUrl,
            contactUserId: conv.participantUserId,
            contactPhone: conv.participantPhone,
            contactAbout: conv.participantAbout,
            contactTrustScore: conv.participantTrustScore,
          ),
        ),
      );
    }
    _loadConversations();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);

    return Scaffold(
      extendBody: true,
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF1F5F9),
      appBar: _currentBottomNavIndex == 0
          ? LajuGlassAppBar(
              titleSpacing: 16,
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Image.asset(
                      'assets/images/logo_no_bg.png',
                      width: 24,
                      height: 24,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'LAJU',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDark
                              ? [
                                  const Color(0xFF1E293B).withValues(alpha: 0.85),
                                  const Color(0xFF0F172A).withValues(alpha: 0.95),
                                ]
                              : [
                                  Colors.white,
                                  AppColors.primary.withValues(alpha: 0.08),
                                ],
                        ),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF38BDF8).withValues(alpha: 0.3)
                              : AppColors.primary.withValues(alpha: 0.25),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (isDark ? const Color(0xFF38BDF8) : AppColors.primary)
                                .withValues(alpha: isDark ? 0.18 : 0.12),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const MyQrCodeScreen(initialTabIndex: 1),
                              ),
                            );
                          },
                          child: Center(
                            child: Icon(
                              Icons.qr_code_scanner_rounded,
                              size: 21,
                              color: isDark ? const Color(0xFF38BDF8) : AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : null,
      body: _buildBody(),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: _currentBottomNavIndex == 0
            ? FloatingActionButton(
                heroTag: 'fab_home_chat',
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const NewChatScreen()),
                  );
                  _loadConversations();
                },
                backgroundColor: AppColors.primary,
                elevation: 6,
                child: const Icon(Icons.edit_rounded, color: Colors.white, size: 22),
              )
            : (_currentBottomNavIndex == 1
                ? FloatingActionButton(
                    heroTag: 'fab_home_status',
                    onPressed: () {
                      StatusScreen.statusKey.currentState?.showMediaPicker();
                    },
                    backgroundColor: AppColors.primary,
                    elevation: 6,
                    child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 22),
                  )
                : (_currentBottomNavIndex == 2
                    ? FloatingActionButton(
                        heroTag: 'fab_home_call',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const NewCallContactPickerScreen()),
                          );
                        },
                        backgroundColor: AppColors.primary,
                        elevation: 6,
                        child: const Icon(Icons.add_call, color: Colors.white, size: 22),
                      )
                    : null)),
      ),
      bottomNavigationBar: _buildFloatingGlassDock(isDark),
    );
  }

  Widget _buildFloatingGlassDock(bool isDark) {
    final navItems = [
      {'icon': Icons.chat_bubble_outline_rounded, 'activeIcon': Icons.chat_bubble_rounded, 'label': context.tr('chats')},
      {'icon': Icons.donut_large_rounded, 'activeIcon': Icons.donut_large_rounded, 'label': context.tr('status')},
      {'icon': Icons.call_outlined, 'activeIcon': Icons.call_rounded, 'label': context.tr('calls')},
      {'icon': Icons.settings_outlined, 'activeIcon': Icons.settings_rounded, 'label': context.tr('settings')},
    ];

    return RepaintBoundary(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            const Color(0xFF1E293B).withValues(alpha: 0.78),
                            const Color(0xFF0F172A).withValues(alpha: 0.88),
                          ]
                        : [
                            Colors.white.withValues(alpha: 0.90),
                            Colors.white.withValues(alpha: 0.75),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.white.withValues(alpha: 0.55),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(navItems.length, (idx) {
                    final item = navItems[idx];
                    final isSelected = _currentBottomNavIndex == idx;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        HomeScreen.activeTabNotifier.value = idx;
                      },
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        padding: EdgeInsets.symmetric(
                          horizontal: isSelected ? 16 : 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: isDark ? 0.22 : 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: isSelected
                              ? Border.all(
                                  color: AppColors.primary.withValues(alpha: 0.4),
                                  width: 1,
                                )
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isSelected
                                  ? (item['activeIcon'] as IconData)
                                  : (item['icon'] as IconData),
                              size: 21,
                              color: isSelected
                                  ? AppColors.primary
                                  : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                            ),
                            if (isSelected) ...[
                              const SizedBox(width: 8),
                              Text(
                                item['label'] as String,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

  Widget _buildBody() {
    return IndexedStack(
      index: _currentBottomNavIndex,
      children: [
        _buildChatsTab(),
        StatusScreen(key: StatusScreen.statusKey),
        _buildCallsTab(),
        const SettingsScreen(),
      ],
    );
  }

  Widget _buildChatsTab() {
    final isDark = ThemeModeController.instance.isDarkMode(context);

    return LajuGlassBackground(
      child: Column(
        children: [
          // Frosted Glass Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: LajuGlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
            borderRadius: 16,
            blurSigma: 12,
            child: SizedBox(
              height: 42,
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF111827), fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Cari obrolan, kontak, atau pesan...',
                  hintStyle: TextStyle(
                    color: isDark ? AppColors.darkTextSecondary : const Color(0xFF9CA3AF),
                    fontSize: 13.5,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: isDark ? AppColors.darkTextSecondary : const Color(0xFF9CA3AF),
                    size: 20,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: isDark ? Colors.white70 : const Color(0xFF6B7280),
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          tooltip: 'Hapus Pencarian',
                        )
                      : null,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
        ),

        // Filter Chips Row matching Screen 4 (All, Unread, Groups, Favorites)
        FilterChipGroup(
          filters: _filters,
          selectedFilter: _selectedFilter,
          onSelected: (val) {
            setState(() {
              _selectedFilter = val;
            });
          },
        ),

        const SizedBox(height: 4),

        // Conversation List with Glass Spacing
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadConversations,
            color: AppColors.primary,
            child: _buildConversationsContent(isDark),
          ),
        ),
      ],
    ),
  );
}

  Widget _buildConversationsContent(bool isDark) {
    if (_isLoadingConversations && _conversations.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    final isSearching = _searchController.text.trim().isNotEmpty;
    final archivedCount = _conversations.where((c) => c.isArchived == true).length;

    // Headers shown at top of the conversation list
    final List<Widget> headers = [];
    if (_selectedFilter == 'All' && !isSearching) {
      headers.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: _buildLockedChatsBanner(isDark),
        ),
      );
      if (archivedCount > 0) {
        headers.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: _buildArchivedChatsBanner(isDark, archivedCount),
          ),
        );
      }
    }

    if (_filteredConversations.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          ...headers,
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 40, left: 24, right: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isSearching ? Icons.search_off_rounded : Icons.chat_bubble_outline_rounded,
                      color: AppColors.primary,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isSearching ? 'Tidak Ditemukan' : 'Belum Ada Obrolan',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isSearching
                        ? 'Tidak ada obrolan yang cocok dengan "${_searchController.text.trim()}". Periksa ejaan atau gunakan kata kunci lain.'
                        : 'Mulai obrolan baru dengan kontak Anda menggunakan tombol pesan di kanan bawah.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final totalItemCount = headers.length + _filteredConversations.length;

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: totalItemCount,
      separatorBuilder: (context, index) {
        if (index < headers.length) {
          return const SizedBox(height: 2);
        }
        return Padding(
          padding: const EdgeInsets.only(left: 78),
          child: Divider(
            height: 1,
            color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE2E8F0).withValues(alpha: 0.6),
          ),
        );
      },
      itemBuilder: (context, index) {
        if (index < headers.length) {
          return headers[index];
        }
        final conv = _filteredConversations[index - headers.length];
        return ConversationTile(
          key: ValueKey(conv.id),
          conversation: conv,
          onTap: () => _openChat(conv),
          onLongPress: () => _handleConversationOptions(conv),
        );
      },
    );
  }

  Widget _buildLockedChatsBanner(bool isDark) {
    return LajuGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      borderRadius: 16,
      blurSigma: 10,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AppLockScreen(
              onUnlocked: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LockedChatsScreen(),
                  ),
                ).then((_) => _loadConversations());
              },
            ),
          ),
        );
      },
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: isDark ? 0.20 : 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
            ),
            child: const Center(
              child: Icon(Icons.lock_rounded, color: AppColors.primary, size: 20),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chat Dikunci',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Ketuk untuk membuka dengan sidik jari / PIN',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF9CA3AF),
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildArchivedChatsBanner(bool isDark, int count) {
    return LajuGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      borderRadius: 16,
      blurSigma: 10,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ArchivedChatsScreen(),
          ),
        ).then((_) => _loadConversations());
      },
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.20 : 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
              ),
            ),
            child: const Center(
              child: Icon(Icons.archive_outlined, color: Color(0xFFF59E0B), size: 20),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Diarsipkan',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Obrolan yang disimpan di arsip',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFFF59E0B),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right_rounded,
            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF9CA3AF),
            size: 20,
          ),
        ],
      ),
    );
  }

  String _formatCallTimestamp(int? timestampMs) {
    if (timestampMs == null || timestampMs == 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final callDate = DateTime(dt.year, dt.month, dt.day);

    if (callDate == today) {
      return DateFormat('HH:mm').format(dt);
    } else if (callDate == today.subtract(const Duration(days: 1))) {
      return 'Kemarin, ${DateFormat('HH:mm').format(dt)}';
    } else {
      return DateFormat('d MMM, HH:mm').format(dt);
    }
  }

  String _formatCallDuration(int seconds) {
    if (seconds <= 0) return '';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m == 0) return '${s}d';
    return '${m}m ${s}d';
  }

  Widget _buildCallsTab() {
    final isDark = ThemeModeController.instance.isDarkMode(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: LajuGlassAppBar(
        titleSpacing: 16,
        title: Text(
          context.tr('calls'),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.search_rounded,
              size: 22,
              color: isDark ? Colors.white : const Color(0xFF374151),
            ),
            onPressed: () {},
            tooltip: context.tr('search'),
          ),
          PopupMenuButton<String>(
            color: isDark ? AppColors.darkSurfaceElevated : Colors.white,
            icon: Icon(
              Icons.more_vert_rounded,
              color: isDark ? Colors.white : const Color(0xFF374151),
            ),
            onSelected: (value) async {
              if (value == 'clear') {
                await LocalDatabase.instance.clearCallLogs();
                _loadCallLogs();
              } else if (value == 'settings') {
                HomeScreen.activeTabNotifier.value = 3;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'clear', child: Text(context.tr('clearCallLog'))),
              PopupMenuItem(value: 'settings', child: Text(context.tr('settings'))),
            ],
          ),
        ],
      ),
      body: LajuGlassBackground(
        child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
        children: [
          // New Call Action in a sleek frosted glass card
          LajuGlassCard(
            borderRadius: 18,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const NewCallContactPickerScreen()),
                ).then((_) => _loadCallLogs());
              },
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          AppColors.primary,
                          AppColors.primaryDark,
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.add_call, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('newCall'),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15.5,
                            color: isDark ? Colors.white : const Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.tr('newCallSub'),
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          if (_callLogs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.phone_missed_rounded,
                        color: AppColors.primary,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Belum Ada Riwayat Panggilan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Panggilan suara dan video end-to-end terenkripsi Anda akan ditampilkan di sini.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // Section Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  Text(
                    context.tr('recentCalls'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      color: isDark ? AppColors.darkTextSecondary : const Color(0xFF4B5563),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Recent Calls Grouped in Glass Card
            LajuGlassCard(
              borderRadius: 18,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: List.generate(_callLogs.length, (index) {
                  final call = _callLogs[index];
                  final name = (call['contact_name'] as String?)?.isNotEmpty == true
                      ? call['contact_name'] as String
                      : 'Panggilan';
                  final phone = call['contact_phone'] as String?;
                  final userId = (call['contact_id'] ?? call['contact_user_id']) as String?;
                  final direction = call['direction'] as String? ?? 'outgoing';
                  final status = call['status'] as String? ?? 'completed';
                  final callType = call['call_type'] as String? ?? 'audio';
                  final isVideo = callType == 'video';
                  final isIncoming = direction == 'incoming';
                  final isMissed = status == 'missed' || status == 'rejected';
                  final duration = (call['duration_seconds'] as num?)?.toInt() ?? 0;
                  final createdAt = (call['created_at'] as num?)?.toInt() ?? (call['timestamp'] as num?)?.toInt();
                  final timeStr = _formatCallTimestamp(createdAt);
                  final isLast = index == _callLogs.length - 1;

                  String? avatarUrl = call['avatar_url'] as String?;
                  if (avatarUrl == null || avatarUrl.isEmpty) {
                    try {
                      for (final c in _conversations) {
                        if (userId != null && userId.isNotEmpty && c.participantUserId == userId) {
                          if (c.avatarUrl != null && c.avatarUrl!.isNotEmpty) {
                            avatarUrl = c.avatarUrl;
                            break;
                          }
                        }
                        if (phone != null && phone.isNotEmpty && c.participantPhone == phone) {
                          if (c.avatarUrl != null && c.avatarUrl!.isNotEmpty) {
                            avatarUrl = c.avatarUrl;
                            break;
                          }
                        }
                        if (c.title.trim().toLowerCase() == name.trim().toLowerCase()) {
                          if (c.avatarUrl != null && c.avatarUrl!.isNotEmpty) {
                            avatarUrl = c.avatarUrl;
                            break;
                          }
                        }
                      }
                    } catch (_) {}
                  }

                  String statusDesc;
                  if (status == 'rejected') {
                    statusDesc = 'Ditolak';
                  } else if (status == 'missed') {
                    statusDesc = 'Tak terjawab';
                  } else if (duration > 0) {
                    statusDesc = _formatCallDuration(duration);
                  } else {
                    statusDesc = isIncoming ? 'Masuk' : 'Keluar';
                  }

                  final subtitleText = timeStr.isNotEmpty ? '$timeStr • $statusDesc' : statusDesc;

                  return Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: ModernAvatar(
                          name: name,
                          imagePath: avatarUrl,
                          radius: 22,
                          isVerified: true,
                        ),
                        title: Text(
                          name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15.5,
                            color: isDark ? Colors.white : const Color(0xFF111827),
                          ),
                        ),
                        subtitle: Row(
                          children: [
                            Icon(
                              isIncoming
                                  ? (isMissed ? Icons.call_missed_rounded : Icons.call_received_rounded)
                                  : Icons.call_made_rounded,
                              size: 14,
                              color: isMissed ? const Color(0xFFEF4444) : AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                subtitleText,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: isMissed
                                      ? const Color(0xFFEF4444)
                                      : (isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        trailing: Container(
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.white : AppColors.primary).withValues(alpha: isDark ? 0.08 : 0.10),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: Icon(
                              isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                              size: 20,
                              color: AppColors.primary,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ActiveCallScreen(
                                    contactName: name,
                                    calleeUserId: userId,
                                    contactPhone: phone,
                                    avatarUrl: avatarUrl,
                                    isVideo: isVideo,
                                    returnToCallsScreen: true,
                                  ),
                                ),
                              ).then((_) => _loadCallLogs());
                            },
                          ),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ActiveCallScreen(
                                contactName: name,
                                calleeUserId: userId,
                                contactPhone: phone,
                                avatarUrl: avatarUrl,
                                isVideo: isVideo,
                                returnToCallsScreen: true,
                              ),
                            ),
                          ).then((_) => _loadCallLogs());
                        },
                      ),
                      if (!isLast)
                        Divider(
                          height: 1,
                          indent: 68,
                          endIndent: 16,
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                        ),
                    ],
                  );
                }),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
}
