import 'package:flutter/material.dart';

/// Branded in-app toast / snackbar used across login, events, friends, social, etc.
enum AppSnackType { success, error, info, warning }

class AppSnackBar {
  AppSnackBar._();

  static const Color _navy = Color(0xFF13243A);
  static const Color _gold = Color(0xFFFDB913);
  static const Color _error = Color(0xFFE53935);
  static const Color _info = Color(0xFF64B5F6);

  static AppSnackType inferType(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('fail') ||
        lower.contains('error') ||
        lower.contains('could not') ||
        lower.contains('unable') ||
        lower.contains('incorrect') ||
        lower.contains('invalid') ||
        lower.contains('missing') ||
        lower.contains('declined') ||
        lower.contains('removed') ||
        lower.contains('deleted') ||
        lower.contains('cancelled') ||
        lower.contains('canceled')) {
      if (lower.contains('removed') ||
          lower.contains('deleted') ||
          lower.contains('declined') ||
          lower.contains('cancelled') ||
          lower.contains('canceled')) {
        return AppSnackType.info;
      }
      return AppSnackType.error;
    }
    if (lower.contains('saved') ||
        lower.contains('reminder') ||
        lower.contains('sent') ||
        lower.contains('accepted') ||
        lower.contains('published') ||
        lower.contains('queued') ||
        lower.contains('complete') ||
        lower.contains('joined') ||
        lower.contains('updated') ||
        lower.contains('signed in')) {
      return AppSnackType.success;
    }
    if (lower.contains('coming soon') || lower.contains('offline')) {
      return AppSnackType.warning;
    }
    return AppSnackType.info;
  }

  static void show(
    BuildContext context, {
    required String message,
    AppSnackType? type,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
    IconData? icon,
  }) {
    final resolvedType = type ?? inferType(message);
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          padding: EdgeInsets.zero,
          duration: duration,
          action: (actionLabel != null && onAction != null)
              ? SnackBarAction(
                  label: actionLabel,
                  onPressed: onAction,
                  textColor: _gold,
                )
              : null,
          content: _SnackBody(
            message: message,
            type: resolvedType,
            icon: icon,
          ),
        ),
      );
  }

  static void success(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
    IconData? icon,
  }) =>
      show(
        context,
        message: message,
        type: AppSnackType.success,
        actionLabel: actionLabel,
        onAction: onAction,
        duration: duration,
        icon: icon,
      );

  static void error(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
    IconData? icon,
  }) =>
      show(
        context,
        message: message,
        type: AppSnackType.error,
        duration: duration,
        icon: icon,
      );

  static void info(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    IconData? icon,
  }) =>
      show(
        context,
        message: message,
        type: AppSnackType.info,
        duration: duration,
        icon: icon,
      );

  static void warning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
    IconData? icon,
  }) =>
      show(
        context,
        message: message,
        type: AppSnackType.warning,
        duration: duration,
        icon: icon,
      );
}

class _SnackBody extends StatelessWidget {
  final String message;
  final AppSnackType type;
  final IconData? icon;

  const _SnackBody({
    required this.message,
    required this.type,
    this.icon,
  });

  Color get _accent {
    switch (type) {
      case AppSnackType.success:
        return AppSnackBar._gold;
      case AppSnackType.error:
        return AppSnackBar._error;
      case AppSnackType.warning:
        return AppSnackBar._gold;
      case AppSnackType.info:
        return AppSnackBar._info;
    }
  }

  IconData get _icon {
    if (icon != null) return icon!;
    switch (type) {
      case AppSnackType.success:
        return Icons.check_circle_rounded;
      case AppSnackType.error:
        return Icons.error_outline_rounded;
      case AppSnackType.warning:
        return Icons.info_outline_rounded;
      case AppSnackType.info:
        return Icons.notifications_active_rounded;
    }
  }

  List<Color> get _gradient {
    switch (type) {
      case AppSnackType.error:
        return const [Color(0xFF3A1520), Color(0xFF241018)];
      case AppSnackType.warning:
        return const [Color(0xFF2A2418), AppSnackBar._navy];
      default:
        return const [Color(0xFF1A3358), AppSnackBar._navy];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accent.withValues(alpha: 0.42)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.16),
              shape: BoxShape.circle,
              border: Border.all(color: _accent.withValues(alpha: 0.34)),
            ),
            child: Icon(_icon, color: _accent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
