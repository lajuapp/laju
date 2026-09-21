import 'package:flutter/material.dart';

enum LajuToastType {
  success,
  info,
  warning,
  error,
}

class LajuToast {
  static void show(
    BuildContext context, {
    required String message,
    String? title,
    LajuToastType type = LajuToastType.info,
    Duration duration = const Duration(seconds: 2),
    IconData? customIcon,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    Color bgColor;
    Color borderColor;
    IconData icon;

    switch (type) {
      case LajuToastType.success:
        bgColor = const Color(0xFF0B8069); // LAJU signature primary teal
        borderColor = const Color(0xFF00A884);
        icon = Icons.check_circle_rounded;
        break;
      case LajuToastType.info:
        bgColor = const Color(0xFF075E54); // Deep theme teal
        borderColor = const Color(0xFF26A69A);
        icon = Icons.info_rounded;
        break;
      case LajuToastType.warning:
        bgColor = const Color(0xFF854D0E);
        borderColor = const Color(0xFFFBBF24);
        icon = Icons.warning_rounded;
        break;
      case LajuToastType.error:
        bgColor = const Color(0xFF991B1B);
        borderColor = const Color(0xFFF87171);
        icon = Icons.error_rounded;
        break;
    }

    if (customIcon != null) {
      icon = customIcon;
    }

    messenger.showSnackBar(
      SnackBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        padding: EdgeInsets.zero,
        duration: duration,
        content: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(50), // Sleek floating pill
              border: Border.all(
                color: borderColor.withValues(alpha: 0.6),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
                BoxShadow(
                  color: borderColor.withValues(alpha: 0.3),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 19),
                const SizedBox(width: 9),
                Flexible(
                  child: Text(
                    message,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.1,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static void success(BuildContext context, String message, {String? title, Duration? duration}) {
    show(
      context,
      message: message,
      title: title,
      type: LajuToastType.success,
      duration: duration ?? const Duration(seconds: 2),
    );
  }

  static void info(BuildContext context, String message, {String? title, Duration? duration}) {
    show(
      context,
      message: message,
      title: title,
      type: LajuToastType.info,
      duration: duration ?? const Duration(seconds: 2),
    );
  }

  static void warning(BuildContext context, String message, {String? title, Duration? duration}) {
    show(
      context,
      message: message,
      title: title,
      type: LajuToastType.warning,
      duration: duration ?? const Duration(seconds: 2),
    );
  }

  static void error(BuildContext context, String message, {String? title, Duration? duration}) {
    show(
      context,
      message: message,
      title: title,
      type: LajuToastType.error,
      duration: duration ?? const Duration(seconds: 3),
    );
  }
}
