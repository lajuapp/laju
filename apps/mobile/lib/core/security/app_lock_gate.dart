import 'package:flutter/material.dart';
import '../../features/lock/presentation/screens/app_lock_screen.dart';
import 'app_lock_controller.dart';

class AppLockGate extends StatefulWidget {
  final Widget child;

  const AppLockGate({super.key, required this.child});

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  final AppLockController _lockCtrl = AppLockController.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _lockCtrl.onAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      _lockCtrl.onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _lockCtrl,
      builder: (context, _) {
        return Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            if (_lockCtrl.isCurrentlyLocked)
              Positioned.fill(
                child: AppLockScreen(
                  isGate: true,
                  onUnlocked: () {
                    _lockCtrl.unlockApp();
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}
