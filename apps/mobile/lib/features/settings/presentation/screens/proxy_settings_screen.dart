import 'package:flutter/material.dart';
import '../../../../core/core.dart';
import '../../domain/data_storage_controller.dart';

class ProxySettingsScreen extends StatefulWidget {
  const ProxySettingsScreen({super.key});

  @override
  State<ProxySettingsScreen> createState() => _ProxySettingsScreenState();
}

class _ProxySettingsScreenState extends State<ProxySettingsScreen> {
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late final TextEditingController _secretController;
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    final controller = DataStorageController.instance;
    _hostController = TextEditingController(text: controller.proxyHost);
    _portController = TextEditingController(text: controller.proxyPort.toString());
    _secretController = TextEditingController(text: controller.proxySecret);
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _secretController.dispose();
    super.dispose();
  }

  Future<void> _handleTest() async {
    setState(() => _isTesting = true);
    final success = await DataStorageController.instance.testProxyConnection();
    if (!mounted) return;
    setState(() => _isTesting = false);

    if (success) {
      final ping = DataStorageController.instance.proxyPingMs ?? 35;
      LajuToast.success(context, '${context.tr('proxyConnected')} ($ping ms)');
    } else {
      LajuToast.error(context, context.tr('proxyFailed'));
    }
  }

  void _handleSave() {
    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 1080;
    final secret = _secretController.text.trim();

    DataStorageController.instance.updateProxyConfig(
      host: host,
      port: port,
      secret: secret,
    );

    LajuToast.success(context, context.tr('proxySaved'));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);
    final controller = DataStorageController.instance;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final useProxy = controller.useProxy;
        final isConnected = useProxy && controller.proxyStatus == 'connected';

        return Scaffold(
          backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
          extendBodyBehindAppBar: true,
          appBar: LajuGlassAppBar(
            title: Text(context.tr('proxy')),
          ),
          body: LajuGlassBackground(
            showOrbs: true,
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                children: [
                  // Switch Card
                  LajuGlassCard(
                    padding: EdgeInsets.zero,
                    child: Material(
                      color: Colors.transparent,
                      child: SwitchListTile(
                        activeTrackColor: AppColors.primary,
                        activeThumbColor: Colors.white,
                        title: Text(
                          context.tr('useProxy'),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: isDark ? Colors.white : const Color(0xFF111827),
                          ),
                        ),
                        subtitle: Text(
                          context.tr('useProxySub'),
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                          ),
                        ),
                        value: useProxy,
                        onChanged: (val) {
                          controller.setUseProxy(val);
                          LajuToast.info(
                            context,
                            val ? context.tr('proxyEnabledToast') : context.tr('proxyDisabledToast'),
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Status Card
                  LajuGlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: isConnected
                                ? const Color(0xFF10B981)
                                : (useProxy ? Colors.orange : Colors.grey),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr('connectionStatus'),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                !useProxy
                                    ? context.tr('proxyNotActive')
                                    : (isConnected
                                        ? '${context.tr('connectedStatus')} • ${controller.proxyPingMs ?? 38} ms'
                                        : context.tr('connectingStatus')),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF111827),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (useProxy)
                          TextButton.icon(
                            onPressed: _isTesting ? null : _handleTest,
                            icon: _isTesting
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.sync_rounded, size: 16),
                            label: Text(
                              _isTesting ? context.tr('testingConnection') : context.tr('testConnection'),
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Form Card
                  LajuGlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('proxyConfiguration'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.primaryLight : AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Host
                        Text(
                          context.tr('proxyHost'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : const Color(0xFF374151),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _hostController,
                          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF111827)),
                          decoration: InputDecoration(
                            hintText: 'proxy.laju.internal',
                            hintStyle: TextStyle(color: isDark ? Colors.white38 : const Color(0xFF9CA3AF)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: isDark ? AppColors.darkSurfaceBorder : const Color(0xFFD1D5DB),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: isDark ? AppColors.darkSurfaceBorder : const Color(0xFFD1D5DB),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Port
                        Text(
                          context.tr('proxyPort'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : const Color(0xFF374151),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _portController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF111827)),
                          decoration: InputDecoration(
                            hintText: '1080',
                            hintStyle: TextStyle(color: isDark ? Colors.white38 : const Color(0xFF9CA3AF)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: isDark ? AppColors.darkSurfaceBorder : const Color(0xFFD1D5DB),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: isDark ? AppColors.darkSurfaceBorder : const Color(0xFFD1D5DB),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Secret
                        Text(
                          context.tr('proxySecret'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : const Color(0xFF374151),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _secretController,
                          obscureText: true,
                          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF111827)),
                          decoration: InputDecoration(
                            hintText: '•••••••••••• (Optional)',
                            hintStyle: TextStyle(color: isDark ? Colors.white38 : const Color(0xFF9CA3AF)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: isDark ? AppColors.darkSurfaceBorder : const Color(0xFFD1D5DB),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: isDark ? AppColors.darkSurfaceBorder : const Color(0xFFD1D5DB),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _handleSave,
                      child: Text(
                        context.tr('saveSettings'),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
