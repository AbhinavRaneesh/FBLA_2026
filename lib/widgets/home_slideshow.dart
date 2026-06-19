import 'dart:async';

import 'package:flutter/material.dart';

import '../constants/app_assets.dart';

/// Auto-advancing homepage image slideshow (4s per slide) with dot indicators.
class HomeSlideshow extends StatefulWidget {
  /// Box aspect ratio (width / height). Defaults to the assets' native 3:2;
  /// pass a wider ratio (e.g. 16/9) to render a shorter banner/strip.
  final double aspectRatio;

  const HomeSlideshow({super.key, this.aspectRatio = 3 / 2});

  @override
  State<HomeSlideshow> createState() => _HomeSlideshowState();
}

class _HomeSlideshowState extends State<HomeSlideshow> {
  static const Duration _slideInterval = Duration(seconds: 4);

  /// Large virtual page count so slide 4 can animate forward into slide 1.
  static const int _loopLength = 10000;

  late final PageController _pageController;
  late final int _initialVirtualPage;
  int _virtualPage = 0;
  Timer? _timer;

  int get _slideCount => AppAssets.homeSlideshowImages.length;

  int get _realIndex => _virtualPage % _slideCount;

  @override
  void initState() {
    super.initState();
    final mid = _loopLength ~/ 2;
    _initialVirtualPage = mid - (mid % _slideCount);
    _virtualPage = _initialVirtualPage;
    _pageController = PageController(initialPage: _initialVirtualPage);
    _timer = Timer.periodic(_slideInterval, (_) => _advance());
  }

  void _advance() {
    if (!mounted || !_pageController.hasClients) return;
    _pageController.animateToPage(
      _virtualPage + 1,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
    );
  }

  void _goToPage(int target) {
    if (!_pageController.hasClients) return;
    final currentReal = _realIndex;
    var delta = (target - currentReal) % _slideCount;
    if (delta <= 0) delta += _slideCount;
    if (delta == 0) return;

    _pageController.animateToPage(
      _virtualPage + delta,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
    _restartTimer();
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_slideInterval, (_) => _advance());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: Stack(
        alignment: Alignment.bottomCenter,
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: _loopLength,
            onPageChanged: (i) {
              setState(() => _virtualPage = i);
              _restartTimer();
            },
            itemBuilder: (context, i) {
              final imageIndex = i % _slideCount;
              return Image.asset(
                AppAssets.homeSlideshowImages[imageIndex],
                width: width,
                fit: BoxFit.fitWidth,
                alignment: Alignment.topCenter,
              );
            },
          ),
          Positioned(
            bottom: 14,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(_slideCount, (i) {
                final active = i == _realIndex;
                return GestureDetector(
                  onTap: () => _goToPage(i),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: active ? 9 : 7,
                    height: active ? 9 : 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: active
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.45),
                      boxShadow: active
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
