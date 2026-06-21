import 'dart:async';

import 'package:flutter/material.dart';

import '../services/typewriter_sound_service.dart';

/// Bollywood-style location-card intro with cyber terminal styling and click SFX.
class CyberTypewriterIntro extends StatefulWidget {
  final Color accentColor;
  final VoidCallback? onSequenceComplete;

  const CyberTypewriterIntro({
    super.key,
    required this.accentColor,
    this.onSequenceComplete,
  });

  @override
  State<CyberTypewriterIntro> createState() => _CyberTypewriterIntroState();
}

class _CyberTypewriterIntroState extends State<CyberTypewriterIntro>
    with SingleTickerProviderStateMixin {
  static const _lineGroups = [
    ['NETWORKS', 'UNDER', 'THREAT'],
    ['DATA', 'REQUIRES', 'PROTECTION'],
    ['CYBERSECURITY', 'FUNDAMENTALS'],
  ];

  static const _wordDelay = Duration(milliseconds: 420);
  static const _linePause = Duration(milliseconds: 520);

  int _lineIndex = 0;
  int _wordIndex = 0;
  bool _sequenceDone = false;
  Timer? _timer;
  late final AnimationController _scanController;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
    unawaited(TypewriterSoundService.instance.ensureReady());
    _scheduleNextWord();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scanController.dispose();
    super.dispose();
  }

  void _scheduleNextWord() {
    _timer?.cancel();
    if (_lineIndex >= _lineGroups.length) {
      if (!_sequenceDone) {
        _sequenceDone = true;
        widget.onSequenceComplete?.call();
      }
      return;
    }

    final line = _lineGroups[_lineIndex];
    if (_wordIndex >= line.length) {
      _lineIndex += 1;
      _wordIndex = 0;
      _timer = Timer(_linePause, _scheduleNextWord);
      return;
    }

    _timer = Timer(_wordDelay, () {
      if (!mounted) return;
      unawaited(TypewriterSoundService.instance.playClick());
      setState(() => _wordIndex += 1);
      _scheduleNextWord();
    });
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor;
    final glow = Color.lerp(accent, const Color(0xFF00E5FF), 0.45)!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 320.0;

        return Container(
          width: double.infinity,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF050D18),
                Color(0xFF0A1628),
                Color(0xFF07111F),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              _TerminalGrid(accent: accent, animation: _scanController),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.terminal_rounded,
                            color: glow.withValues(alpha: 0.9), size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'SECURE_TERMINAL // LEVEL_01',
                          style: TextStyle(
                            color: glow.withValues(alpha: 0.75),
                            fontFamily: 'monospace',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 1,
                      color: accent.withValues(alpha: 0.22),
                    ),
                    const Spacer(),
                    ...List.generate(_lineGroups.length, (i) {
                      final visibleLine = i < _lineIndex ||
                          (i == _lineIndex && _wordIndex > 0);
                      if (!visibleLine) return const SizedBox.shrink();

                      final words = _lineGroups[i];
                      final count = i < _lineIndex
                          ? words.length
                          : i == _lineIndex
                              ? _wordIndex
                              : 0;

                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: i < _lineGroups.length - 1 ? 18 : 0,
                        ),
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 280),
                          opacity: count > 0 ? 1 : 0,
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 6,
                            children: [
                              for (var w = 0; w < count; w++)
                                _TypewriterWord(
                                  text: words[w],
                                  accent: accent,
                                  glow: glow,
                                  delayMs: w * 40,
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const Spacer(),
                    Row(
                      children: [
                        Text(
                          '> ',
                          style: TextStyle(
                            color: glow,
                            fontFamily: 'monospace',
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        _BlinkingCursor(color: glow),
                        const SizedBox(width: 8),
                        Text(
                          _sequenceDone ? 'READY' : 'LOADING...',
                          style: TextStyle(
                            color: glow.withValues(alpha: 0.65),
                            fontFamily: 'monospace',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TypewriterWord extends StatelessWidget {
  final String text;
  final Color accent;
  final Color glow;
  final int delayMs;

  const _TypewriterWord({
    required this.text,
    required this.accent,
    required this.glow,
    required this.delayMs,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.92 + (0.08 * value),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: glow.withValues(alpha: 0.35)),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: glow,
            fontFamily: 'monospace',
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.6,
            shadows: [
              Shadow(color: glow.withValues(alpha: 0.55), blurRadius: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlinkingCursor extends StatefulWidget {
  final Color color;

  const _BlinkingCursor({required this.color});

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor> {
  bool _on = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 480), (_) {
      if (mounted) setState(() => _on = !_on);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 120),
      opacity: _on ? 1 : 0.15,
      child: Container(
        width: 11,
        height: 18,
        color: widget.color,
      ),
    );
  }
}

class _TerminalGrid extends StatelessWidget {
  final Color accent;
  final Animation<double> animation;

  const _TerminalGrid({
    required this.accent,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return CustomPaint(
          painter: _GridPainter(
            accent: accent,
            phase: animation.value,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _GridPainter extends CustomPainter {
  final Color accent;
  final double phase;

  _GridPainter({required this.accent, required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = accent.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    const step = 28.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final scanY = size.height * phase;
    final scanPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          accent.withValues(alpha: 0.08),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, scanY - 40, size.width, 80));
    canvas.drawRect(
      Rect.fromLTWH(0, scanY - 40, size.width, 80),
      scanPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) {
    return oldDelegate.phase != phase;
  }
}
