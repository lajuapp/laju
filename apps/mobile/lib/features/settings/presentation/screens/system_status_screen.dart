import 'package:flutter/material.dart';
import '../../../../core/core.dart';

class ServiceStatusDef {
  final String nameKey;
  final String uptime;
  final String statusKey;
  final IconData icon;

  const ServiceStatusDef({
    required this.nameKey,
    required this.uptime,
    required this.statusKey,
    required this.icon,
  });
}

class SystemStatusScreen extends StatefulWidget {
  const SystemStatusScreen({super.key});

  @override
  State<SystemStatusScreen> createState() => _SystemStatusScreenState();
}

class _SystemStatusScreenState extends State<SystemStatusScreen> {
  bool _isRefreshing = false;
  bool _isAllHealthy = true;

  List<ServiceStatusDef> _services = const [
    ServiceStatusDef(
      nameKey: 'sysServiceAuth',
      uptime: '100%',
      statusKey: 'sysNormal',
      icon: Icons.key_rounded,
    ),
    ServiceStatusDef(
      nameKey: 'sysServiceOutbox',
      uptime: '99.99%',
      statusKey: 'sysNormal',
      icon: Icons.sync_lock_rounded,
    ),
    ServiceStatusDef(
      nameKey: 'sysServiceWebrtc',
      uptime: '99.98%',
      statusKey: 'sysNormal',
      icon: Icons.phone_locked_rounded,
    ),
    ServiceStatusDef(
      nameKey: 'sysServiceMedia',
      uptime: '100%',
      statusKey: 'sysNormal',
      icon: Icons.attachment_rounded,
    ),
    ServiceStatusDef(
      nameKey: 'sysServicePush',
      uptime: '100%',
      statusKey: 'sysNormal',
      icon: Icons.notifications_active_rounded,
    ),
    ServiceStatusDef(
      nameKey: 'sysServiceAntiSpam',
      uptime: '100%',
      statusKey: 'sysNormal',
      icon: Icons.security_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    setState(() {
      _isRefreshing = true;
    });

    try {
      final res = await ApiClient.instance.get(ApiEndpoints.health);
      final isSuccess = res.isSuccess;
      String dbStatus = 'up';
      String redisStatus = 'up';

      if (isSuccess && res.rawJson is Map && res.rawJson['services'] is Map) {
        final services = res.rawJson['services'] as Map;
        dbStatus = services['database']?.toString() ?? 'up';
        redisStatus = services['redis']?.toString() ?? 'up';
      }

      final isDbNormal = dbStatus == 'up';
      final isRedisNormal = redisStatus == 'up';
      final isHealthy = isSuccess && isDbNormal && isRedisNormal;

      if (!mounted) return;

      setState(() {
        _isAllHealthy = isHealthy;
        _isRefreshing = false;
        _services = [
          ServiceStatusDef(
            nameKey: 'sysServiceAuth',
            uptime: isHealthy ? '100%' : '98.5%',
            statusKey: isHealthy ? 'sysNormal' : 'sysDegraded',
            icon: Icons.key_rounded,
          ),
          ServiceStatusDef(
            nameKey: 'sysServiceOutbox',
            uptime: isRedisNormal ? '99.99%' : '95.0%',
            statusKey: isRedisNormal ? 'sysNormal' : 'sysDegraded',
            icon: Icons.sync_lock_rounded,
          ),
          ServiceStatusDef(
            nameKey: 'sysServiceWebrtc',
            uptime: isHealthy ? '99.98%' : '97.2%',
            statusKey: isHealthy ? 'sysNormal' : 'sysDegraded',
            icon: Icons.phone_locked_rounded,
          ),
          ServiceStatusDef(
            nameKey: 'sysServiceMedia',
            uptime: isHealthy ? '100%' : '99.0%',
            statusKey: isHealthy ? 'sysNormal' : 'sysDegraded',
            icon: Icons.attachment_rounded,
          ),
          ServiceStatusDef(
            nameKey: 'sysServicePush',
            uptime: isHealthy ? '100%' : '99.5%',
            statusKey: isHealthy ? 'sysNormal' : 'sysDegraded',
            icon: Icons.notifications_active_rounded,
          ),
          ServiceStatusDef(
            nameKey: 'sysServiceAntiSpam',
            uptime: isDbNormal ? '100%' : '98.0%',
            statusKey: isDbNormal ? 'sysNormal' : 'sysDegraded',
            icon: Icons.security_rounded,
          ),
        ];
      });

      LajuToast.success(context, context.tr('systemRefreshedToast'));
    } catch (_) {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : const Color(0xFFF1F5F9),
      appBar: LajuGlassAppBar(
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.tr('systemStatusPageTitle'),
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
        ),
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : const Icon(Icons.refresh_rounded, size: 22),
            onPressed: _isRefreshing ? null : _refreshStatus,
          ),
        ],
      ),
      body: LajuGlassBackground(
        showOrbs: true,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 40),
          children: [
            // Overall Status Banner
            LajuGlassCard(
              padding: const EdgeInsets.all(18),
              borderRadius: 20,
              blurSigma: 16,
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: (_isAllHealthy ? const Color(0xFF16A34A) : const Color(0xFFD97706)).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isAllHealthy ? const Color(0xFF22C55E) : const Color(0xFFF59E0B),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      _isAllHealthy ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded,
                      color: _isAllHealthy ? const Color(0xFF22C55E) : const Color(0xFFF59E0B),
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isAllHealthy ? context.tr('systemStatusAllGood') : 'Sebagian Layanan Mengalami Kendala',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          context.tr('systemStatusUptimeSla'),
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text(
                context.tr('systemServicesClusters'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : const Color(0xFF6B7280),
                  letterSpacing: 0.8,
                ),
              ),
            ),

            LajuGlassCard(
              padding: EdgeInsets.zero,
              borderRadius: 20,
              blurSigma: 16,
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _services.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  thickness: 0.5,
                  indent: 52,
                  endIndent: 16,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0xFFE2E8F0),
                ),
                itemBuilder: (context, index) {
                  final s = _services[index];
                  return ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        s.icon,
                        color: isDark
                            ? AppColors.primary
                            : const Color(0xFF2563EB),
                        size: 19,
                      ),
                    ),
                    title: Text(
                      context.tr(s.nameKey),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          s.uptime,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 9,
                          height: 9,
                          decoration: const BoxDecoration(
                            color: Color(0xFF22C55E),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 18),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text(
                context.tr('systemIncidentHistory'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : const Color(0xFF6B7280),
                  letterSpacing: 0.8,
                ),
              ),
            ),

            LajuGlassCard(
              padding: const EdgeInsets.all(16),
              borderRadius: 20,
              blurSigma: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF22C55E),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        context.tr('systemNoIncidents'),
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr('systemNoIncidentsDesc'),
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : const Color(0xFF64748B),
                      height: 1.4,
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
}
