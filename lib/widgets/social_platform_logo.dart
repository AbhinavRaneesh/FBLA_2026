import 'package:flutter/material.dart';

import '../constants/app_assets.dart';

class SocialPlatformLogo extends StatelessWidget {
  final String? assetPath;
  final String? platformName;
  final IconData fallbackIcon;
  final Color? color;
  final double size;
  final BoxFit fit;

  const SocialPlatformLogo({
    super.key,
    this.assetPath,
    this.platformName,
    required this.fallbackIcon,
    this.color,
    required this.size,
    this.fit = BoxFit.contain,
  });

  String? get _resolvedAsset =>
      assetPath ??
      (platformName != null ? AppAssets.socialLogoForName(platformName!) : null);

  @override
  Widget build(BuildContext context) {
    final path = _resolvedAsset;
    if (path != null) {
      return Image.asset(
        path,
        width: size,
        height: size,
        fit: fit,
        errorBuilder: (_, __, ___) =>
            Icon(fallbackIcon, color: color, size: size),
      );
    }
    return Icon(fallbackIcon, color: color, size: size);
  }
}
