import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../ai/bloc/chat_bloc.dart';
import 'ai_chat_panel.dart';

/// Global floating AI button (bottom-left) + dimmed overlay chat panel.
class AiAssistantHost extends StatefulWidget {
  final Widget child;

  const AiAssistantHost({super.key, required this.child});

  @override
  State<AiAssistantHost> createState() => AiAssistantHostState();
}

class AiAssistantHostState extends State<AiAssistantHost>
    with SingleTickerProviderStateMixin {
  bool _open = false;
  late final AnimationController _anim;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  void open() {
    if (_open) return;
    setState(() => _open = true);
    _anim.forward();
  }

  bool closeIfOpen() {
    if (!_open) return false;
    close();
    return true;
  }

  void close() {
    if (!_open) return;
    _anim.reverse().then((_) {
      if (mounted) setState(() => _open = false);
    });
  }

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottomNavHeight = kBottomNavigationBarHeight + media.padding.bottom;
    final keyboardInset = media.viewInsets.bottom;
    final panelHeight = (media.size.height * 0.62 - keyboardInset * 0.35)
        .clamp(280.0, 560.0);

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_open) ...[
          FadeTransition(
            opacity: _fade,
            child: GestureDetector(
              onTap: close,
              child: Container(color: Colors.black.withValues(alpha: 0.52)),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: bottomNavHeight + 12 + keyboardInset,
            height: panelHeight,
            child: SlideTransition(
              position: _slide,
              child: FadeTransition(
                opacity: _fade,
                child: Material(
                  elevation: 24,
                  shadowColor: chatBlueGlow.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(22),
                  clipBehavior: Clip.antiAlias,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: chatSurfaceDarker,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: chatBlueGlow.withValues(alpha: 0.55),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: chatBlueGlow.withValues(alpha: 0.35),
                          blurRadius: 28,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: AiChatPanel(
                      compact: true,
                      onClose: close,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
        if (!_open)
          Positioned(
            left: 16,
            bottom: bottomNavHeight + 12,
            child: _AiFab(onTap: open),
          ),
      ],
    );
  }
}

class _AiFab extends StatelessWidget {
  final VoidCallback onTap;

  const _AiFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      shadowColor: chatBlueGlow.withValues(alpha: 0.45),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: fblaGold.withValues(alpha: 0.45)),
      ),
      color: fblaNavy,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome_rounded, color: fblaGold, size: 22),
              SizedBox(width: 8),
              Text(
                'AI',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Provides [ChatBloc] and hosts the overlay above the main app shell.
class AiAssistantScope extends StatelessWidget {
  final Widget child;
  final GlobalKey<AiAssistantHostState>? hostKey;

  const AiAssistantScope({super.key, required this.child, this.hostKey});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ChatBloc(),
      child: AiAssistantHost(key: hostKey, child: child),
    );
  }
}
