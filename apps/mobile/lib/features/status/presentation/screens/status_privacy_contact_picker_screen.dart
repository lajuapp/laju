import 'package:flutter/material.dart';
import '../../../../core/core.dart';
import '../../../conversations/domain/conversation_service.dart';
import '../../../settings/domain/account_controller.dart';

enum PrivacyPickerMode {
  exclude, // "My contacts except..." -> Hide status from...
  include, // "Only share with..." -> Share status with...
}

class PrivacyContact {
  final String id;
  final String name;
  final String status;
  final String phone;

  const PrivacyContact({
    required this.id,
    required this.name,
    required this.status,
    required this.phone,
  });
}

class StatusPrivacyContactPickerScreen extends StatefulWidget {
  final PrivacyPickerMode mode;
  final Set<String> initialSelectedIds;

  const StatusPrivacyContactPickerScreen({
    super.key,
    required this.mode,
    required this.initialSelectedIds,
  });

  @override
  State<StatusPrivacyContactPickerScreen> createState() =>
      _StatusPrivacyContactPickerScreenState();
}

class _StatusPrivacyContactPickerScreenState
    extends State<StatusPrivacyContactPickerScreen> {
  late Set<String> _selectedIds;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  List<PrivacyContact> _allContacts = [];

  @override
  void initState() {
    super.initState();
    _selectedIds = Set<String>.from(widget.initialSelectedIds);
    _loadSavedContacts();
  }

  void _loadSavedContacts() {
    final saved = AccountController.instance.savedContacts;
    setState(() {
      _allContacts = saved.map((c) => PrivacyContact(
        id: c.id,
        name: (c.displayName != null && c.displayName!.isNotEmpty) ? c.displayName! : c.username,
        status: (c.about != null && c.about!.isNotEmpty) ? c.about! : 'Kontak Personal Terverifikasi',
        phone: '@${c.username}',
      )).toList();
    });
  }

  void _onSearchQueryChanged(String query) {
    setState(() {});
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<PrivacyContact> get _filteredContacts {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _allContacts;
    return _allContacts
        .where((c) =>
            c.name.toLowerCase().contains(q) ||
            c.phone.contains(q) ||
            c.status.toLowerCase().contains(q))
        .toList();
  }

  void _toggleContact(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedIds.length == _allContacts.length) {
        _selectedIds.clear();
      } else {
        _selectedIds = _allContacts.map((c) => c.id).toSet();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);
    final isExclude = widget.mode == PrivacyPickerMode.exclude;
    final titleText = isExclude ? 'Hide status from...' : 'Share status with...';
    final countLabel = isExclude
        ? '${_selectedIds.length} excluded'
        : '${_selectedIds.length} selected';

    final activeColor = isExclude ? const Color(0xFFDC2626) : AppColors.primary;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : const Color(0xFF111827)),
          onPressed: () => Navigator.pop(context, widget.initialSelectedIds),
        ),
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(fontSize: 16, color: isDark ? Colors.white : const Color(0xFF111827)),
                decoration: InputDecoration(
                  hintText: isExclude ? 'Search contacts to hide...' : 'Search contacts to share...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: isDark ? AppColors.darkTextSecondary : const Color(0xFF9CA3AF), fontSize: 14),
                ),
                onChanged: (val) {
                  setState(() {});
                  _onSearchQueryChanged(val);
                },
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titleText,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  Text(
                    countLabel,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
        actions: [
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close_rounded : Icons.search_rounded,
              color: isDark ? Colors.white70 : const Color(0xFF374151),
            ),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _searchController.clear();
                }
                _isSearching = !_isSearching;
              });
            },
          ),
          IconButton(
            icon: Icon(
              _selectedIds.length == _allContacts.length
                  ? Icons.deselect_rounded
                  : Icons.select_all_rounded,
              color: isDark ? Colors.white70 : const Color(0xFF374151),
            ),
            tooltip: _selectedIds.length == _allContacts.length ? 'Deselect all' : 'Select all',
            onPressed: _toggleSelectAll,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () {
          Navigator.pop(context, _selectedIds);
        },
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 26),
      ),
      body: ListView.builder(
        itemCount: _filteredContacts.length,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemBuilder: (context, index) {
          final contact = _filteredContacts[index];
          final isSelected = _selectedIds.contains(contact.id);

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: ModernAvatar(
              name: contact.name,
              radius: 22,
              isVerified: true,
            ),
            title: Text(
              contact.name,
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
            ),
            subtitle: Text(
              contact.status,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
              ),
            ),
            trailing: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? activeColor : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? activeColor
                      : (isDark ? AppColors.darkSurfaceBorder : const Color(0xFF9CA3AF)),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Icon(
                      isExclude ? Icons.close_rounded : Icons.check_rounded,
                      size: 17,
                      color: Colors.white,
                    )
                  : null,
            ),
            onTap: () => _toggleContact(contact.id),
          );
        },
      ),
    );
  }
}
