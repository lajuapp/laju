import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/core.dart';
import '../../../conversations/domain/conversation_service.dart';
import '../../domain/models/message_model.dart';

class LajuContactPickerBottomSheet extends StatefulWidget {
  const LajuContactPickerBottomSheet({super.key});

  static Future<LajuContactData?> show(BuildContext context) {
    return showModalBottomSheet<LajuContactData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const LajuContactPickerBottomSheet(),
    );
  }

  @override
  State<LajuContactPickerBottomSheet> createState() => _LajuContactPickerBottomSheetState();
}

class _LajuContactPickerBottomSheetState extends State<LajuContactPickerBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _isLoading = true;
  List<LajuContactData> _contacts = [];
  List<LajuContactData> _filteredContacts = [];

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts([String query = '']) async {
    setState(() => _isLoading = true);
    try {
      final results = await ConversationService.instance.searchUsers(query.trim());
      if (!mounted) return;

      final items = results.map((u) {
        final displayName = (u.username.isNotEmpty) ? u.username : 'Pengguna LAJU';
        return LajuContactData(
          userId: u.id,
          name: displayName,
          username: u.username,
          phoneNumber: u.phoneNumber,
          avatarUrl: u.avatarUrl,
          status: u.status ?? 'Pengguna Terverifikasi LAJU',
        );
      }).toList();

      setState(() {
        _contacts = items;
        _filteredContacts = items;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    final query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      setState(() {
        _filteredContacts = _contacts;
      });
      return;
    }

    // Local quick filter first
    final localMatches = _contacts.where((c) {
      return c.name.toLowerCase().contains(query) ||
          c.username.toLowerCase().contains(query) ||
          (c.phoneNumber != null && c.phoneNumber!.contains(query));
    }).toList();

    setState(() {
      _filteredContacts = localMatches;
    });

    // Remote debounce query to ensure complete directory search
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final remoteResults = await ConversationService.instance.searchUsers(query);
        if (!mounted) return;

        final items = remoteResults.map((u) {
          final displayName = (u.username.isNotEmpty) ? u.username : 'Pengguna LAJU';
          return LajuContactData(
            userId: u.id,
            name: displayName,
            username: u.username,
            phoneNumber: u.phoneNumber,
            avatarUrl: u.avatarUrl,
            status: u.status ?? 'Pengguna Terverifikasi LAJU',
          );
        }).toList();

        setState(() {
          _filteredContacts = items;
        });
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mediaQuery = MediaQuery.of(context);

    return Container(
      height: mediaQuery.size.height * 0.82,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.perm_contact_calendar_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bagikan Kontak LAJU',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _isLoading
                            ? 'Memuat kontak...'
                            : '${_filteredContacts.length} kontak tersedia',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Search Box
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 14.5,
                ),
                decoration: InputDecoration(
                  hintText: 'Cari nama atau @username...',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white38 : Colors.black38,
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.cancel_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),

          const Divider(height: 1),

          // Contacts List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : _filteredContacts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_search_rounded,
                              size: 56,
                              color: isDark ? Colors.white24 : Colors.black26,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Tidak ada kontak ditemukan',
                              style: TextStyle(
                                color: isDark ? Colors.white54 : Colors.black54,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _filteredContacts.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          indent: 72,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.05),
                        ),
                        itemBuilder: (context, index) {
                          final contact = _filteredContacts[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            leading: ModernAvatar(
                              name: contact.name,
                              imagePath: contact.avatarUrl,
                              radius: 22,
                              isOnline: true,
                              isVerified: true,
                            ),
                            title: Text(
                              contact.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            subtitle: Text(
                              '@${contact.username}${contact.status != null && contact.status!.isNotEmpty ? ' • ${contact.status}' : ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Bagikan',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(
                                    Icons.send_rounded,
                                    color: AppColors.primary,
                                    size: 13,
                                  ),
                                ],
                              ),
                            ),
                            onTap: () {
                              Navigator.pop(context, contact);
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
