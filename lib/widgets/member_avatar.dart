import 'package:flutter/material.dart';

/// Circle avatar for a member — network photo when available, else initial.
class MemberAvatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final double radius;
  final Color backgroundColor;
  final Color? foregroundColor;
  final double? fontSize;

  const MemberAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.radius = 23,
    this.backgroundColor = const Color(0xFF1D4E89),
    this.foregroundColor,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final url = (photoUrl ?? '').trim();
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    final textColor = foregroundColor ?? Colors.white;

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      backgroundImage: url.isEmpty ? null : NetworkImage(url),
      child: url.isEmpty
          ? Text(
              initial,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: fontSize ?? (radius * 0.78),
              ),
            )
          : null,
    );
  }
}
