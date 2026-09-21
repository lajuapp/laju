import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/core.dart';

class NotificationsSettingsScreen extends StatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  State<NotificationsSettingsScreen> createState() =>
      _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState extends State<NotificationsSettingsScreen> {
  // Persistence Keys
  static const String _kConversationTones = 'notif_conversation_tones';
  static const String _kMsgRingtone = 'notif_msg_ringtone';
  static const String _kMsgVibrate = 'notif_msg_vibrate';
  static const String _kMsgPopup = 'notif_msg_popup';
  static const String _kMsgLight = 'notif_msg_light';
  static const String _kMsgHighPriority = 'notif_msg_high_priority';
  static const String _kMsgReactions = 'notif_msg_reactions';

  static const String _kGroupRingtone = 'notif_group_ringtone';
  static const String _kGroupVibrate = 'notif_group_vibrate';
  static const String _kGroupLight = 'notif_group_light';
  static const String _kGroupHighPriority = 'notif_group_high_priority';
  static const String _kGroupReactions = 'notif_group_reactions';

  static const String _kCallRingtone = 'notif_call_ringtone';
  static const String _kCallVibrate = 'notif_call_vibrate';

  // Default values
  static const String _defaultMsgRingtone = 'LAJU Quantum Wave';
  static const String _defaultGroupRingtone = 'LAJU Neon Pulse';
  static const String _defaultCallRingtone = 'LAJU Horizon Echo';

  // Current State
  bool _conversationTones = true;
  String _msgRingtone = _defaultMsgRingtone;
  String _msgVibrate = 'Default';
  String _msgPopup = 'Tanpa popup';
  String _msgLight = 'Emerald Green';
  bool _msgHighPriority = true;
  bool _msgReactions = true;

  String _groupRingtone = _defaultGroupRingtone;
  String _groupVibrate = 'Default';
  String _groupLight = 'Cyan Blue';
  bool _groupHighPriority = true;
  bool _groupReactions = true;

  String _callRingtone = _defaultCallRingtone;
  String _callVibrate = 'Default';

  bool _isLoading = true;

  // Available Ringtones List
  static const List<Map<String, String>> _availableRingtones = [
    {
      'name': 'LAJU Quantum Wave',
      'desc': 'Nada khas LAJU (Bawaan)',
      'badge': 'Rekomendasi',
    },
    {
      'name': 'LAJU Neon Pulse',
      'desc': 'Elektronik modern dan halus',
      'badge': 'Populer',
    },
    {
      'name': 'LAJU Horizon Echo',
      'desc': 'Lonceng futuristik jernih',
      'badge': 'Khas',
    },
    {
      'name': 'Emerald Chime',
      'desc': 'Dentang lonceng kristal lembut',
      'badge': 'Klasik',
    },
    {
      'name': 'Cyber Ping',
      'desc': 'Sinyal sonik singkat & tegas',
      'badge': 'Minimal',
    },
    {
      'name': 'Aurora Glow',
      'desc': 'Harmoni ambient menenangkan',
      'badge': 'Tenang',
    },
    {
      'name': 'Celestial Tone',
      'desc': 'Akustik bertingkat elegan',
      'badge': 'Elegan',
    },
    {
      'name': 'Hening (Mute)',
      'desc': 'Tanpa suara notifikasi',
      'badge': 'Hening',
    },
  ];

  // Available Vibration Modes
  static const List<Map<String, String>> _availableVibrateModes = [
    {
      'name': 'Mati',
      'desc': 'Nonaktifkan getaran sama sekali',
    },
    {
      'name': 'Default',
      'desc': 'Pola getar standar sistem',
    },
    {
      'name': 'Pendek',
      'desc': 'Getaran singkat dan taktis',
    },
    {
      'name': 'Panjang',
      'desc': 'Getaran tegas berulang',
    },
  ];

  // Available LED / Light Colors
  static const List<Map<String, dynamic>> _availableLights = [
    {'name': 'Tidak ada', 'color': Colors.transparent, 'desc': 'Tanpa lampu indikator'},
    {'name': 'Emerald Green', 'color': Color(0xFF10B981), 'desc': 'Aksen khas LAJU'},
    {'name': 'Cyan Blue', 'color': Color(0xFF06B6D4), 'desc': 'Biru terang elektrik'},
    {'name': 'Putih', 'color': Colors.white, 'desc': 'Cahaya putih netral'},
    {'name': 'Ungu Violet', 'color': Color(0xFF8B5CF6), 'desc': 'Ungu neon halus'},
    {'name': 'Kuning Amber', 'color': Color(0xFFF59E0B), 'desc': 'Warna hangat kontras'},
    {'name': 'Merah', 'color': Color(0xFFEF4444), 'desc': 'Indikator prioritas tinggi'},
  ];

  // Available Popup Options
  static const List<String> _availablePopups = [
    'Tanpa popup',
    'Hanya saat layar aktif',
    'Hanya saat layar mati',
    'Selalu tampilkan popup',
  ];

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _conversationTones = prefs.getBool(_kConversationTones) ?? true;
        _msgRingtone = prefs.getString(_kMsgRingtone) ?? _defaultMsgRingtone;
        _msgVibrate = prefs.getString(_kMsgVibrate) ?? 'Default';
        _msgPopup = prefs.getString(_kMsgPopup) ?? 'Tanpa popup';
        _msgLight = prefs.getString(_kMsgLight) ?? 'Emerald Green';
        _msgHighPriority = prefs.getBool(_kMsgHighPriority) ?? true;
        _msgReactions = prefs.getBool(_kMsgReactions) ?? true;

        _groupRingtone = prefs.getString(_kGroupRingtone) ?? _defaultGroupRingtone;
        _groupVibrate = prefs.getString(_kGroupVibrate) ?? 'Default';
        _groupLight = prefs.getString(_kGroupLight) ?? 'Cyan Blue';
        _groupHighPriority = prefs.getBool(_kGroupHighPriority) ?? true;
        _groupReactions = prefs.getBool(_kGroupReactions) ?? true;

        _callRingtone = prefs.getString(_kCallRingtone) ?? _defaultCallRingtone;
        _callVibrate = prefs.getString(_kCallVibrate) ?? 'Default';

        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _saveString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  void _triggerHapticPreview(String mode) {
    LajuSoundService.triggerVibrate(mode);
  }

  void _triggerRingtonePreview(String ringtone) {
    LajuSoundService.playRingtone(ringtone);
  }

  // --- Modal Sheets ---

  void _showRingtonePickerSheet({
    required String current,
    required String title,
    required ValueChanged<String> onSelected,
  }) {
    final isDark = ThemeModeController.instance.isDarkMode(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFE2E8F0),
                    width: 1.2,
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.music_note_rounded, color: AppColors.primary, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Pilih nada dering lalu ketuk untuk memutar preview',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Divider(
                    height: 1,
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
                  ),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _availableRingtones.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        indent: 64,
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
                      ),
                      itemBuilder: (context, index) {
                        final item = _availableRingtones[index];
                        final name = item['name']!;
                        final desc = item['desc']!;
                        final badge = item['badge']!;
                        final isSelected = current == name;

                        return Material(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: isDark ? 0.12 : 0.08)
                              : Colors.transparent,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary
                                    : (isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F5F9)),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isSelected ? Icons.volume_up_rounded : Icons.music_note_outlined,
                                color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF6B7280)),
                                size: 18,
                              ),
                            ),
                            title: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    name,
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      color: isSelected
                                          ? AppColors.primary
                                          : (isDark ? Colors.white : const Color(0xFF111827)),
                                      fontSize: 14.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primary.withValues(alpha: 0.2)
                                        : (isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0)),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    badge,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected ? AppColors.primary : (isDark ? Colors.white60 : const Color(0xFF6B7280)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              desc,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Putar suara',
                                  icon: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.volume_up_rounded, color: AppColors.primary, size: 18),
                                  ),
                                  onPressed: () {
                                    _triggerRingtonePreview(name);
                                  },
                                ),
                                const SizedBox(width: 4),
                                isSelected
                                    ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 22)
                                    : Icon(
                                        Icons.circle_outlined,
                                        color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                                        size: 22,
                                      ),
                              ],
                            ),
                            onTap: () {
                              setSheetState(() {
                                current = name;
                              });
                              _triggerRingtonePreview(name);
                              onSelected(name);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(ctx);
                          LajuToast.success(context, 'Nada dering disimpan: $current');
                        },
                        child: const Text(
                          'Selesai',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showVibratePickerSheet({
    required String current,
    required String title,
    required ValueChanged<String> onSelected,
  }) {
    final isDark = ThemeModeController.instance.isDarkMode(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFE2E8F0),
                    width: 1.2,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withValues(alpha: 0.14),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.vibration_rounded, color: Color(0xFF3B82F6), size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : const Color(0xFF111827),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Ketuk untuk merasakan preview pola getaran',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Divider(
                      height: 1,
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ..._availableVibrateModes.map((item) {
                              final name = item['name']!;
                              final desc = item['desc']!;
                              final isSelected = current == name;

                              return Material(
                                color: isSelected
                                    ? AppColors.primary.withValues(alpha: isDark ? 0.12 : 0.08)
                                    : Colors.transparent,
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                                  leading: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.primary
                                          : (isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F5F9)),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isSelected ? Icons.vibration_rounded : Icons.phone_android_rounded,
                                      color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF6B7280)),
                                      size: 18,
                                    ),
                                  ),
                                  title: Text(
                                    name,
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      color: isSelected ? AppColors.primary : (isDark ? Colors.white : const Color(0xFF111827)),
                                      fontSize: 14.5,
                                    ),
                                  ),
                                  subtitle: Text(
                                    desc,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                                    ),
                                  ),
                                  trailing: isSelected
                                      ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 22)
                                      : Icon(
                                          Icons.circle_outlined,
                                          color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                                          size: 22,
                                        ),
                                  onTap: () {
                                    setSheetState(() {
                                      current = name;
                                    });
                                    _triggerHapticPreview(name);
                                    onSelected(name);
                                    Navigator.pop(ctx);
                                    LajuToast.success(context, 'Pola getar diubah: $name');
                                  },
                                ),
                              );
                            }),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showLightPickerSheet({
    required String current,
    required String title,
    required ValueChanged<String> onSelected,
  }) {
    final isDark = ThemeModeController.instance.isDarkMode(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(
                color: isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFE2E8F0),
                width: 1.2,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFFF59E0B), size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Warna lampu indikator LED perangkat saat notifikasi masuk',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Divider(
                  height: 1,
                  color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ..._availableLights.map((item) {
                          final name = item['name'] as String;
                          final color = item['color'] as Color;
                          final desc = item['desc'] as String;
                          final isSelected = current == name;

                          return Material(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: isDark ? 0.12 : 0.08)
                                : Colors.transparent,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                              leading: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: color == Colors.transparent ? (isDark ? Colors.white12 : const Color(0xFFE2E8F0)) : color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2),
                                    width: 1.5,
                                  ),
                                ),
                                child: color == Colors.transparent
                                    ? Icon(Icons.close_rounded, size: 16, color: isDark ? Colors.white60 : Colors.black45)
                                    : null,
                              ),
                              title: Text(
                                name,
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: isSelected ? AppColors.primary : (isDark ? Colors.white : const Color(0xFF111827)),
                                  fontSize: 14.5,
                                ),
                              ),
                              subtitle: Text(
                                desc,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                                ),
                              ),
                              trailing: isSelected
                                  ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 22)
                                  : Icon(
                                      Icons.circle_outlined,
                                      color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                                      size: 22,
                                    ),
                              onTap: () {
                                HapticFeedback.selectionClick();
                                onSelected(name);
                                Navigator.pop(ctx);
                                LajuToast.success(context, 'Warna lampu diubah: $name');
                              },
                            ),
                          );
                        }),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPopupPickerSheet() {
    final isDark = ThemeModeController.instance.isDarkMode(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(
                color: isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFE2E8F0),
                width: 1.2,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.picture_in_picture_alt_rounded, color: Color(0xFF6366F1), size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Notifikasi Popup',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Tampilkan pesan melayang di atas aplikasi lain',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Divider(
                  height: 1,
                  color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ..._availablePopups.map((mode) {
                          final isSelected = _msgPopup == mode;
                          return Material(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: isDark ? 0.12 : 0.08)
                                : Colors.transparent,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                              title: Text(
                                mode,
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: isSelected ? AppColors.primary : (isDark ? Colors.white : const Color(0xFF111827)),
                                  fontSize: 14.5,
                                ),
                              ),
                              trailing: isSelected
                                  ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 22)
                                  : Icon(
                                      Icons.circle_outlined,
                                      color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                                      size: 22,
                                    ),
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _msgPopup = mode);
                                _saveString(_kMsgPopup, mode);
                                Navigator.pop(ctx);
                                LajuToast.success(context, 'Setelan popup disimpan');
                              },
                            ),
                          );
                        }),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showResetConfirmation() {
    final isDark = ThemeModeController.instance.isDarkMode(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Atur Ulang Setelan Notifikasi?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        content: Text(
          'Semua setelan notifikasi kustom termasuk nada dering, getaran, warna lampu, dan preferensi obrolan akan dikembalikan ke pengaturan default pabrik.',
          style: TextStyle(
            fontSize: 13.5,
            height: 1.45,
            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF4B5563),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Batal',
              style: TextStyle(
                color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove(_kConversationTones);
              await prefs.remove(_kMsgRingtone);
              await prefs.remove(_kMsgVibrate);
              await prefs.remove(_kMsgPopup);
              await prefs.remove(_kMsgLight);
              await prefs.remove(_kMsgHighPriority);
              await prefs.remove(_kMsgReactions);
              await prefs.remove(_kGroupRingtone);
              await prefs.remove(_kGroupVibrate);
              await prefs.remove(_kGroupLight);
              await prefs.remove(_kGroupHighPriority);
              await prefs.remove(_kGroupReactions);
              await prefs.remove(_kCallRingtone);
              await prefs.remove(_kCallVibrate);

              await _loadPreferences();
              if (mounted) {
                HapticFeedback.mediumImpact();
                LajuToast.success(context, 'Pengaturan notifikasi berhasil diatur ulang ke default');
              }
            },
            child: const Text(
              'Atur Ulang',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF1F5F9),
        appBar: LajuGlassAppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : const Color(0xFF111827)),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            context.tr('notificationsTitle'),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF111827),
            ),
          ),
        ),
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF1F5F9),
      appBar: LajuGlassAppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : const Color(0xFF111827)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.tr('notificationsTitle'),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            color: isDark ? AppColors.darkSurfaceElevated : Colors.white,
            icon: Icon(
              Icons.more_vert_rounded,
              color: isDark ? Colors.white : const Color(0xFF111827),
            ),
            onSelected: (val) {
              if (val == 'reset') {
                _showResetConfirmation();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'reset',
                child: Row(
                  children: [
                    Icon(Icons.refresh_rounded, size: 18, color: AppColors.primary),
                    SizedBox(width: 10),
                    Text('Atur ulang setelan'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: LajuGlassBackground(
        showOrbs: true,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 40),
          children: [
            // --- 1. General Settings (Conversation Tones) ---
            LajuGlassCard(
              padding: EdgeInsets.zero,
              borderRadius: 20,
              blurSigma: 16,
              child: Material(
                color: Colors.transparent,
                child: SwitchListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  activeThumbColor: AppColors.primary,
                  activeTrackColor: AppColors.primary.withValues(alpha: 0.4),
                  title: Text(
                    context.tr('conversationTones'),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  subtitle: Text(
                    context.tr('conversationTonesSub'),
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                    ),
                  ),
                  value: _conversationTones,
                  onChanged: (v) {
                    setState(() => _conversationTones = v);
                    _saveBool(_kConversationTones, v);
                    HapticFeedback.selectionClick();
                  },
                ),
              ),
            ),

            const SizedBox(height: 16),

            // --- Uji Coba Notifikasi Masuk Card ---
            LajuGlassCard(
              padding: const EdgeInsets.all(16),
              borderRadius: 20,
              blurSigma: 16,
              borderColor: AppColors.primary.withValues(alpha: 0.3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.touch_app_rounded, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Uji Coba Pengaturan Notifikasi',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Simulasikan pesan masuk untuk menguji nada dering, getaran, dan pop-up',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.send_rounded, size: 16),
                          label: const Text(
                            'Tes Pesan',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            AppNotificationService.instance.showIncomingMessage(
                              conversationId: 'test_demo_channel',
                              senderName: 'LAJU Notification Test',
                              message: 'Halo! Pengaturan suara "$_msgRingtone" dan getar "$_msgVibrate" Anda aktif!',
                              onOpenChat: () {
                                LajuToast.info(context, 'Membuka simulasi obrolan...');
                              },
                              onQuickReply: (text) {
                                LajuToast.success(context, 'Balasan cepat: "$text"');
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF06B6D4),
                            side: BorderSide(color: const Color(0xFF06B6D4).withValues(alpha: 0.4)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.call_rounded, size: 16),
                          label: const Text(
                            'Tes Panggilan',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          onPressed: () {
                            LajuSoundService.playRingtone(_callRingtone);
                            LajuSoundService.triggerVibrate(_callVibrate);
                            AppNotificationService.instance.showIncomingCall(
                              callerName: 'LAJU Voice Call Test',
                              isVideo: false,
                              onAccept: () {
                                LajuSoundService.stopRingtone();
                                LajuToast.success(context, 'Panggilan uji coba diterima');
                              },
                              onDecline: () {
                                LajuSoundService.stopRingtone();
                                LajuToast.info(context, 'Panggilan uji coba ditolak');
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // --- 2. Messages Section ---
            _buildSectionHeader('PESAN & OBROLAN PRIBADI', isDark),
            const SizedBox(height: 8),

            LajuGlassCard(
              padding: EdgeInsets.zero,
              borderRadius: 20,
              blurSigma: 16,
              child: Column(
                children: [
                  // Message Ringtone
                  _buildSettingTile(
                    title: context.tr('ringtone'),
                    subtitle: _msgRingtone,
                    isAccentSubtitle: true,
                    icon: Icons.notifications_none_rounded,
                    isDark: isDark,
                    onTap: () {
                      _showRingtonePickerSheet(
                        current: _msgRingtone,
                        title: 'Nada Dering Pesan',
                        onSelected: (val) {
                          setState(() => _msgRingtone = val);
                          _saveString(_kMsgRingtone, val);
                        },
                      );
                    },
                  ),
                  _buildDivider(isDark),

                  // Message Vibrate
                  _buildSettingTile(
                    title: context.tr('vibrate'),
                    subtitle: _msgVibrate,
                    icon: Icons.vibration_rounded,
                    isDark: isDark,
                    onTap: () {
                      _showVibratePickerSheet(
                        current: _msgVibrate,
                        title: 'Getaran Pesan',
                        onSelected: (val) {
                          setState(() => _msgVibrate = val);
                          _saveString(_kMsgVibrate, val);
                        },
                      );
                    },
                  ),
                  _buildDivider(isDark),

                  // Message Popup
                  _buildSettingTile(
                    title: 'Notifikasi popup',
                    subtitle: _msgPopup,
                    icon: Icons.picture_in_picture_alt_rounded,
                    isDark: isDark,
                    onTap: () => _showPopupPickerSheet(),
                  ),
                  _buildDivider(isDark),

                  // Message Light
                  _buildSettingTile(
                    title: 'Warna lampu indikator',
                    subtitle: _msgLight,
                    icon: Icons.lightbulb_outline_rounded,
                    isDark: isDark,
                    onTap: () {
                      _showLightPickerSheet(
                        current: _msgLight,
                        title: 'Lampu Pesan',
                        onSelected: (val) {
                          setState(() => _msgLight = val);
                          _saveString(_kMsgLight, val);
                        },
                      );
                    },
                  ),
                  _buildDivider(isDark),

                  // High Priority Switch
                  _buildSwitchTile(
                    title: context.tr('highPriority'),
                    subtitle: context.tr('highPrioritySub'),
                    value: _msgHighPriority,
                    isDark: isDark,
                    onChanged: (v) {
                      setState(() => _msgHighPriority = v);
                      _saveBool(_kMsgHighPriority, v);
                      HapticFeedback.selectionClick();
                    },
                  ),
                  _buildDivider(isDark),

                  // Reaction Notifications Switch
                  _buildSwitchTile(
                    title: context.tr('reactionNotifications'),
                    subtitle: context.tr('reactionNotificationsSub'),
                    value: _msgReactions,
                    isDark: isDark,
                    isLast: true,
                    onChanged: (v) {
                      setState(() => _msgReactions = v);
                      _saveBool(_kMsgReactions, v);
                      HapticFeedback.selectionClick();
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // --- 3. Groups Section ---
            _buildSectionHeader('GRUP', isDark),
            const SizedBox(height: 8),

            LajuGlassCard(
              padding: EdgeInsets.zero,
              borderRadius: 20,
              blurSigma: 16,
              child: Column(
                children: [
                  // Group Ringtone
                  _buildSettingTile(
                    title: context.tr('ringtone'),
                    subtitle: _groupRingtone,
                    isAccentSubtitle: true,
                    icon: Icons.group_outlined,
                    isDark: isDark,
                    onTap: () {
                      _showRingtonePickerSheet(
                        current: _groupRingtone,
                        title: 'Nada Dering Grup',
                        onSelected: (val) {
                          setState(() => _groupRingtone = val);
                          _saveString(_kGroupRingtone, val);
                        },
                      );
                    },
                  ),
                  _buildDivider(isDark),

                  // Group Vibrate
                  _buildSettingTile(
                    title: context.tr('vibrate'),
                    subtitle: _groupVibrate,
                    icon: Icons.vibration_rounded,
                    isDark: isDark,
                    onTap: () {
                      _showVibratePickerSheet(
                        current: _groupVibrate,
                        title: 'Getaran Grup',
                        onSelected: (val) {
                          setState(() => _groupVibrate = val);
                          _saveString(_kGroupVibrate, val);
                        },
                      );
                    },
                  ),
                  _buildDivider(isDark),

                  // Group Light
                  _buildSettingTile(
                    title: 'Warna lampu indikator',
                    subtitle: _groupLight,
                    icon: Icons.lightbulb_outline_rounded,
                    isDark: isDark,
                    onTap: () {
                      _showLightPickerSheet(
                        current: _groupLight,
                        title: 'Lampu Grup',
                        onSelected: (val) {
                          setState(() => _groupLight = val);
                          _saveString(_kGroupLight, val);
                        },
                      );
                    },
                  ),
                  _buildDivider(isDark),

                  // Group High Priority Switch
                  _buildSwitchTile(
                    title: context.tr('highPriority'),
                    subtitle: context.tr('highPrioritySub'),
                    value: _groupHighPriority,
                    isDark: isDark,
                    onChanged: (v) {
                      setState(() => _groupHighPriority = v);
                      _saveBool(_kGroupHighPriority, v);
                      HapticFeedback.selectionClick();
                    },
                  ),
                  _buildDivider(isDark),

                  // Group Reaction Notifications Switch
                  _buildSwitchTile(
                    title: context.tr('reactionNotifications'),
                    subtitle: context.tr('reactionNotificationsSub'),
                    value: _groupReactions,
                    isDark: isDark,
                    isLast: true,
                    onChanged: (v) {
                      setState(() => _groupReactions = v);
                      _saveBool(_kGroupReactions, v);
                      HapticFeedback.selectionClick();
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // --- 4. Calls Section ---
            _buildSectionHeader('PANGGILAN SUARA & VIDEO', isDark),
            const SizedBox(height: 8),

            LajuGlassCard(
              padding: EdgeInsets.zero,
              borderRadius: 20,
              blurSigma: 16,
              child: Column(
                children: [
                  // Call Ringtone
                  _buildSettingTile(
                    title: context.tr('ringtone'),
                    subtitle: _callRingtone,
                    isAccentSubtitle: true,
                    icon: Icons.call_outlined,
                    isDark: isDark,
                    onTap: () {
                      _showRingtonePickerSheet(
                        current: _callRingtone,
                        title: 'Nada Dering Panggilan',
                        onSelected: (val) {
                          setState(() => _callRingtone = val);
                          _saveString(_kCallRingtone, val);
                        },
                      );
                    },
                  ),
                  _buildDivider(isDark),

                  // Call Vibrate
                  _buildSettingTile(
                    title: context.tr('vibrate'),
                    subtitle: _callVibrate,
                    icon: Icons.vibration_rounded,
                    isDark: isDark,
                    isLast: true,
                    onTap: () {
                      _showVibratePickerSheet(
                        current: _callVibrate,
                        title: 'Getaran Panggilan',
                        onSelected: (val) {
                          setState(() => _callVibrate = val);
                          _saveString(_kCallVibrate, val);
                        },
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // --- 5. Background Push (Killed State) Section ---
            _buildSectionHeader('PUSH NOTIFIKASI SAAT APLIKASI TERTUTUP (KILLED STATE)', isDark),
            const SizedBox(height: 8),

            LajuGlassCard(
              padding: const EdgeInsets.all(16),
              borderRadius: 20,
              blurSigma: 16,
              borderColor: const Color(0xFF10B981).withValues(alpha: 0.3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.bolt_rounded, color: Color(0xFF10B981), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Gotify & FCM Wakeup Engine',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Pesan baru tetap membunyikan dan memunculkan pop-up saat aplikasi dimatikan total.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'AKTIF',
                          style: TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Push Token Perangkat:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.black : Colors.grey.shade100).withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            PushNotificationService.instance.pushToken.isNotEmpty
                                ? PushNotificationService.instance.pushToken
                                : 'Token terdaftar pada server...',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontFamily: 'monospace',
                              color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          tooltip: 'Salin Token',
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: PushNotificationService.instance.pushToken),
                            );
                            LajuToast.success(context, 'Token disalin ke papan klip');
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.cell_tower_rounded, size: 18),
                      label: const Text(
                        'Uji Coba Push Server (Killed-State Test)',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () async {
                        LajuToast.info(context, 'Mengirim perintah push ke server backend...');
                        final res = await PushNotificationService.instance.testPushNotification();
                        if (res['success'] == true && context.mounted) {
                          LajuToast.success(context, res['message'] ?? 'Push notification berhasil terkirim!');
                        } else if (context.mounted) {
                          LajuToast.error(context, res['message'] ?? 'Gagal mengirim push test');
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Helper Widget Builders ---

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 12,
          color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: 16,
      endIndent: 16,
      color: isDark ? Colors.white.withValues(alpha: 0.07) : const Color(0xFFE2E8F0),
    );
  }

  Widget _buildSettingTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isDark,
    required VoidCallback onTap,
    bool isAccentSubtitle = false,
    bool isLast = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        shape: isLast
            ? const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14.5,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12.5,
            color: isAccentSubtitle
                ? (isDark ? AppColors.primaryLight : AppColors.primaryDark)
                : (isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280)),
            fontWeight: isAccentSubtitle ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios_rounded,
          size: 14,
          color: isDark ? AppColors.darkTextSecondary : const Color(0xFF9CA3AF),
        ),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required bool isDark,
    required ValueChanged<bool> onChanged,
    bool isLast = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: SwitchListTile(
        shape: isLast
            ? const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        activeThumbColor: AppColors.primary,
        activeTrackColor: AppColors.primary.withValues(alpha: 0.4),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14.5,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12.5,
            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
          ),
        ),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
