import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_assets.dart';
import '../main.dart';
import '../services/firebase_service.dart';
import '../utils/validators.dart';

// Login-only richer blue backdrop. Do NOT replace with the shared
// appBackgroundGradient (main.dart) — that is used by every other screen.
const LinearGradient _loginBackgroundGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    Color(0xFF050E22),
    Color(0xFF0E2A56),
    Color(0xFF050E22),
  ],
  stops: [0.0, 0.55, 1.0],
);

// Bright accent blue used for login highlights (focus rings, links, glows).
const Color _accentBlue = Color(0xFF4D9DE0);

// Clips the FBLA asset to just the triangle emblem (left side, upper band),
// excluding the "FBLA" wordmark and the subtitle text.
class _EmblemClipper extends CustomClipper<Rect> {
  @override
  Rect getClip(Size size) => Rect.fromLTRB(
        size.width * 0.08,
        size.height * 0.22,
        size.width * 0.34,
        size.height * 0.56,
      );

  @override
  bool shouldReclip(covariant CustomClipper<Rect> oldClipper) => false;
}

class LoginScreen extends StatefulWidget {
  final String? initialEmail;
  final String? initialPassword;
  const LoginScreen({super.key, this.initialEmail, this.initialPassword});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  bool _obscure = true;
  bool _isLoading = false;
  bool _rememberMe = false;
  bool _showSplash = true;
  String? _emailError;
  String? _passwordError;
  late AnimationController _animationController;
  late AnimationController _backgroundController;
  late AnimationController _splashController;
  late AnimationController _shimmerController;
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail != null) {
      _emailController.text = widget.initialEmail!;
    }
    if (widget.initialPassword != null) {
      _passwordController.text = widget.initialPassword!;
    }
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
    _splashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _emailFocus.addListener(() => setState(() {}));
    _passwordFocus.addListener(() => setState(() {}));
    // Start the splash clock on the first rendered frame, not initState —
    // on a cold start the first frame can land >1s later and would
    // otherwise swallow the splash entirely.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _splashController.forward();
      Timer(const Duration(milliseconds: 1650), () {
        if (!mounted) return;
        setState(() => _showSplash = false);
        _animationController.forward();
      });
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _backgroundController.dispose();
    _splashController.dispose();
    _shimmerController.dispose();
    _shakeController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty && password.isEmpty) {
      await _signInDeveloperMode();
      return;
    }

    final emailError = Validators.email(email);
    final passwordError = Validators.password(password);
    if (emailError != null || passwordError != null) {
      setState(() {
        _emailError = emailError;
        _passwordError = passwordError;
      });
      _shakeController.forward(from: 0);
      return;
    }
    setState(() {
      _emailError = null;
      _passwordError = null;
      _isLoading = true;
    });

    try {
      final userCredential =
          await FirebaseService.signInWithEmail(email, password);
      if (userCredential?.user != null) {
        final user = userCredential!.user!;
        final profile = await FirebaseService.getUserProfile(user.uid);
        if (profile == null) {
          await FirebaseService.createUserProfile(
            userId: user.uid,
            name: user.displayName ?? 'FBLA Member',
            email: user.email ?? email,
            photoUrl: user.photoURL,
            points: 0,
            streak: 0,
          );
        }
        if (!mounted) return;
        final app = Provider.of<AppState>(context, listen: false);
        await app.setFirebaseUser(user);
      }
    } catch (e) {
      if (!mounted) return;
      final rawMessage = e.toString().replaceFirst('Exception: ', '');

      if (rawMessage.startsWith('[offline]')) {
        // Network unavailable — try Firebase's locally-persisted token first.
        final cached = FirebaseAuth.instance.currentUser;
        if (cached != null) {
          final app = Provider.of<AppState>(context, listen: false);
          await app.setFirebaseUser(cached);
        } else {
          // No cached token: fall into offline demo mode with the entered name.
          final app = Provider.of<AppState>(context, listen: false);
          final offlineName = email.split('@').first.replaceAll(RegExp(r'[._-]+'), ' ');
          await app.login(email, offlineName, role: 'Student', grade: '');
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.cloud_off_rounded, color: fblaGold, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text('Signed in offline — some features may be limited'),
                  ),
                ],
              ),
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF1A3A5C),
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      _shakeController.forward(from: 0);
      final message = rawMessage.contains('No account found') ||
              rawMessage.contains('Incorrect password')
          ? 'Incorrect username or password.'
          : rawMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInDeveloperMode() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final app = Provider.of<AppState>(context, listen: false);
      await app.login(
        'demo@fbla.app',
        'FBLA Demo',
        role: 'Developer',
        grade: 'Demo',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final userCredential = await FirebaseService.signInWithGoogle();

      if (userCredential?.user != null) {
        final user = userCredential!.user!;

        final profile = await FirebaseService.getUserProfile(user.uid);
        if (profile == null) {
          await FirebaseService.createUserProfile(
            userId: user.uid,
            name: user.displayName ?? 'FBLA Member',
            email: user.email ?? '',
            photoUrl: user.photoURL,
            points: 0,
            streak: 0,
          );
        }

        if (!mounted) return;
        final app = Provider.of<AppState>(context, listen: false);
        await app.setFirebaseUser(user);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google sign-in was cancelled.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07111F),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Center(
            child: SizedBox(
              width: math.min(constraints.maxWidth, 430),
              height: constraints.maxHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RepaintBoundary(child: _buildAnimatedBackground()),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 520),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: _showSplash
                        ? _buildSplashView()
                        : _buildLoginView(context),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _backgroundController,
      builder: (context, _) {
        final value = _backgroundController.value;
        return Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: _loginBackgroundGradient,
              ),
            ),
            // Faint brand emblem watermark for depth
            Positioned(
              top: -56,
              right: -64,
              child: Opacity(
                opacity: 0.04,
                child: Transform.rotate(
                  angle: 0.18,
                  child: Image.asset(
                    AppAssets.fblaLogo,
                    width: 320,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            // Blue focal glow behind the logo (gently breathing)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.78),
                    radius: 0.95,
                    colors: [
                      _accentBlue.withValues(
                        alpha: 0.16 + math.sin(value * math.pi * 2) * 0.03,
                      ),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Cool accent glow, drifting off-axis
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(
                      -0.85 + math.sin(value * math.pi * 2) * 0.12,
                      -0.2,
                    ),
                    radius: 0.7,
                    colors: [
                      const Color(0xFF3D7BD6).withValues(alpha: 0.10),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Soft drifting orbs
            Positioned(
              left: -70 + math.sin(value * math.pi * 2) * 16,
              top: 150 + math.cos(value * math.pi * 2) * 22,
              child: _glowOrb(230, _accentBlue, 0.12),
            ),
            Positioned(
              right: -80 + math.cos(value * math.pi * 2) * 18,
              bottom: 60 + math.sin(value * math.pi * 2) * 26,
              child: _glowOrb(280, fblaBlue, 0.16),
            ),
            // Blue grounding glow at the bottom
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, 1.0),
                    radius: 0.9,
                    colors: [
                      fblaBlue.withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Vignette to focus the center
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.15,
                    colors: [
                      Colors.transparent,
                      const Color(0xFF05101F).withValues(alpha: 0.55),
                    ],
                    stops: const [0.58, 1.0],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _glowOrb(double size, Color color, double alpha) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: alpha),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSplashView() {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _splashController,
        curve: const Interval(0.0, 0.72, curve: Curves.easeOut),
      ),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.92, end: 1).animate(
          CurvedAnimation(parent: _splashController, curve: Curves.easeOutBack),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _splashController,
            builder: (context, _) {
              final shimmer = const Interval(0.1, 0.7, curve: Curves.easeInOut)
                  .transform(_splashController.value);
              final barScale =
                  const Interval(0.3, 0.6, curve: Curves.easeOutCubic)
                      .transform(_splashController.value);
              final tagline = const Interval(0.5, 0.9, curve: Curves.easeOut)
                  .transform(_splashController.value);
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ShaderMask(
                    shaderCallback: (rect) {
                      final dx = -1.5 + shimmer * 3.0;
                      return LinearGradient(
                        begin: Alignment(dx - 0.6, -0.2),
                        end: Alignment(dx + 0.6, 0.2),
                        colors: const [
                          Colors.white,
                          Color(0xFFFFD75E),
                          Colors.white,
                        ],
                      ).createShader(rect);
                    },
                    child: const Text(
                      'FBLA',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 44,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Transform.scale(
                    scaleX: barScale,
                    child: Container(
                      width: 56,
                      height: 4,
                      decoration: BoxDecoration(
                        color: fblaGold,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Opacity(
                    opacity: tagline,
                    child: Transform.translate(
                      offset: Offset(0, 8 * (1 - tagline)),
                      child: Text(
                        'FUTURE BUSINESS LEADERS OF AMERICA',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 3.5,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _staggered(int slot, Widget child) {
    const intervals = [
      [0.0, 0.55],
      [0.12, 0.66],
      [0.24, 0.82],
      [0.38, 1.0],
    ];
    final curve = CurvedAnimation(
      parent: _animationController,
      curve: Interval(
        intervals[slot][0],
        intervals[slot][1],
        curve: Curves.easeOutCubic,
      ),
    );
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.05),
          end: Offset.zero,
        ).animate(curve),
        child: child,
      ),
    );
  }

  Widget _buildLoginView(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.height < 720;

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, viewport) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: viewport.maxHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: isCompact ? 20 : 32),
                  _staggered(0, _buildLogo(isCompact: isCompact)),
                  SizedBox(height: isCompact ? 14 : 20),
                  _staggered(1, _buildHeading(isCompact: isCompact)),
                  SizedBox(height: isCompact ? 20 : 26),
                  _staggered(2, _buildShakeWrapper(_buildLoginCard())),
                  SizedBox(height: isCompact ? 18 : 22),
                  _staggered(3, _buildSignUpPrompt()),
                  SizedBox(height: isCompact ? 16 : 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLogo({required bool isCompact}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final logoWidth = (screenWidth * (isCompact ? 0.64 : 0.74))
        .clamp(230.0, 330.0)
        .toDouble();
    final logoHeight = logoWidth / 1.5;

    // The asset carries a lot of transparent padding; the artwork only fills a
    // horizontal band in the middle. Crop to that band to kill the dead space.
    const artworkBand = 0.48; // visible vertical slice of the asset
    const artworkAlignY = -0.18; // re-center the slice on the lockup

    final lockup = SizedBox(
      width: logoWidth,
      height: logoHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Base: the whole lockup recolored to solid white (alpha preserved)
          ColorFiltered(
            colorFilter: const ColorFilter.matrix(<double>[
              0, 0, 0, 0, 255, //
              0, 0, 0, 0, 255, //
              0, 0, 0, 0, 255, //
              0, 0, 0, 1, 0, //
            ]),
            child: Image.asset(AppAssets.fblaLogo, fit: BoxFit.contain),
          ),
          // Overlay: original colors, clipped to just the triangle emblem so
          // only the swoosh keeps its color while the lettering stays white.
          ClipRect(
            clipper: _EmblemClipper(),
            child: Image.asset(AppAssets.fblaLogo, fit: BoxFit.contain),
          ),
        ],
      ),
    );

    return Hero(
      tag: 'fbla_logo',
      child: Material(
        type: MaterialType.transparency,
        child: ClipRect(
          child: Align(
            alignment: const Alignment(0, artworkAlignY),
            heightFactor: artworkBand,
            child: lockup,
          ),
        ),
      ),
    );
  }

  Widget _buildHeading({required bool isCompact}) {
    final headingSize = isCompact ? 26.0 : 30.0;
    return Column(
      children: [
        Text(
          'Welcome back',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: headingSize,
            height: 1.15,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 12),
        AnimatedBuilder(
          animation: _animationController,
          builder: (context, _) {
            final t = const Interval(0.45, 0.8, curve: Curves.easeOutCubic)
                .transform(_animationController.value);
            return Container(
              width: 56 * t,
              height: 3,
              decoration: BoxDecoration(
                color: _accentBlue.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(999),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        Text(
          'Sign in to your FBLA member account',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.62),
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildShakeWrapper(Widget child) {
    return AnimatedBuilder(
      animation: _shakeController,
      builder: (context, c) {
        final t = _shakeController.value;
        final dx = math.sin(t * math.pi * 6) * 7 * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: c);
      },
      child: child,
    );
  }

  Widget _buildLoginCard() {
    final isCompact = MediaQuery.of(context).size.height < 720;
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 3,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF7CC0F2), _accentBlue, Color(0xFF1D4E89)],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(22, isCompact ? 22 : 24, 22, 22),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildField(
                      label: 'Email',
                      controller: _emailController,
                      focusNode: _emailFocus,
                      hint: 'you@school.org',
                      icon: Icons.email_outlined,
                      error: _emailError,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      onChanged: (_) {
                        if (_emailError != null) {
                          setState(() => _emailError = null);
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildField(
                      label: 'Password',
                      controller: _passwordController,
                      focusNode: _passwordFocus,
                      hint: 'Enter your password',
                      icon: Icons.lock_outline,
                      error: _passwordError,
                      obscureText: _obscure,
                      autofillHints: const [AutofillHints.password],
                      onChanged: (_) {
                        if (_passwordError != null) {
                          setState(() => _passwordError = null);
                        }
                      },
                      onSubmitted: (_) => _submit(),
                      suffixIcon: IconButton(
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 150),
                          transitionBuilder: (child, anim) =>
                              FadeTransition(opacity: anim, child: child),
                          child: Icon(
                            _obscure
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            key: ValueKey(_obscure),
                            color: Colors.white.withValues(alpha: 0.48),
                            size: 20,
                          ),
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildRememberForgotRow(),
                    SizedBox(height: isCompact ? 16 : 20),
                    _buildGoldButton(),
                    SizedBox(height: isCompact ? 14 : 18),
                    _buildDivider('or continue with'),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildGoogleButton()),
                        const SizedBox(width: 12),
                        Expanded(child: _buildAppleButton()),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required IconData icon,
    String? error,
    TextInputType? keyboardType,
    bool obscureText = false,
    List<String>? autofillHints,
    Widget? suffixIcon,
    void Function(String)? onChanged,
    void Function(String)? onSubmitted,
  }) {
    final focused = focusNode.hasFocus;
    final hasError = error != null;
    final borderColor = hasError
        ? const Color(0xFFFF7A7A)
        : focused
            ? _accentBlue.withValues(alpha: 0.9)
            : Colors.white.withValues(alpha: 0.10);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.72),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Colors.white.withValues(alpha: 0.04),
            border: Border.all(color: borderColor),
            boxShadow: focused && !hasError
                ? [
                    BoxShadow(
                      color: _accentBlue.withValues(alpha: 0.22),
                      blurRadius: 14,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 14, right: 10),
                child: Icon(
                  icon,
                  color: focused
                      ? _accentBlue
                      : Colors.white.withValues(alpha: 0.55),
                  size: 20,
                ),
              ),
              Expanded(
                child: Center(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    keyboardType: keyboardType,
                    obscureText: obscureText,
                    autofillHints: autofillHints,
                    onChanged: onChanged,
                    onSubmitted: onSubmitted,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    cursorColor: _accentBlue,
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
              if (suffixIcon != null) suffixIcon,
            ],
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              error,
              style: const TextStyle(
                color: Color(0xFFFF7A7A),
                fontSize: 11.5,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRememberForgotRow() {
    return Row(
      children: [
        InkWell(
          onTap: () => setState(() => _rememberMe = !_rememberMe),
          borderRadius: BorderRadius.circular(6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: _rememberMe
                      ? _accentBlue
                      : Colors.white.withValues(alpha: 0.02),
                  border: Border.all(
                    color: _rememberMe
                        ? _accentBlue
                        : Colors.white.withValues(alpha: 0.40),
                  ),
                ),
                child: AnimatedScale(
                  scale: _rememberMe ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutBack,
                  child: const Icon(Icons.check, color: Colors.white, size: 11),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Remember me',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.62),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        TextButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Password reset is coming soon.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 28),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'Forgot password?',
            style: TextStyle(
              color: _accentBlue,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGoldButton() {
    return _PressableScale(
      enabled: !_isLoading,
      onTap: _submit,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFCE45), fblaGold, Color(0xFFE09A00)],
          ),
          boxShadow: [
            BoxShadow(
              color: fblaGold.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (!_isLoading)
                AnimatedBuilder(
                  animation: _shimmerController,
                  builder: (context, _) {
                    final t = const Interval(0.0, 0.4, curve: Curves.easeInOut)
                        .transform(_shimmerController.value);
                    return Align(
                      alignment: Alignment(-2.2 + t * 4.4, 0),
                      child: Transform.rotate(
                        angle: 0.5,
                        child: Container(
                          width: 30,
                          height: 100,
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                      ),
                    );
                  },
                ),
              Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _isLoading
                      ? const SizedBox(
                          key: ValueKey('spinner'),
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(fblaNavy),
                          ),
                        )
                      : const Text(
                          'LOGIN',
                          key: ValueKey('label'),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: fblaNavy,
                            letterSpacing: 1.4,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(String text) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.white.withValues(alpha: 0.18),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.18),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGoogleButton() {
    return _PressableScale(
      enabled: !_isLoading,
      onTap: _signInWithGoogle,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white.withValues(alpha: 0.05),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CustomPaint(painter: _GoogleGPainter()),
            ),
            SizedBox(width: 9),
            Text(
              'Google',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppleButton() {
    return _PressableScale(
      enabled: !_isLoading,
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Apple Sign-In is coming soon.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white.withValues(alpha: 0.05),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.apple, color: Colors.white, size: 22),
            SizedBox(width: 7),
            Text(
              'Apple',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignUpPrompt() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'New to FBLA? ',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.54),
            fontSize: 13.5,
          ),
        ),
        TextButton(
          onPressed: () async {
            final result = await Navigator.pushNamed(context, '/signup');
            if (!mounted) return;
            if (result is Map) {
              final email = result['email']?.toString();
              final password = result['password']?.toString();
              if (email != null && email.isNotEmpty) {
                _emailController.text = email;
              }
              if (password != null && password.isNotEmpty) {
                _passwordController.text = password;
              }
            }
          },
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            minimumSize: const Size(0, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'Create account',
            style: TextStyle(
              color: _accentBlue,
              fontWeight: FontWeight.w800,
              fontSize: 13.5,
            ),
          ),
        ),
      ],
    );
  }

}

class _PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool enabled;

  const _PressableScale({
    required this.child,
    required this.onTap,
    this.enabled = true,
  });

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.enabled
          ? (_) => setState(() => _pressed = true)
          : null,
      onTapUp: widget.enabled
          ? (_) => setState(() => _pressed = false)
          : null,
      onTapCancel:
          widget.enabled ? () => setState(() => _pressed = false) : null,
      onTap: widget.enabled ? widget.onTap : null,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 90),
        child: widget.child,
      ),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  const _GoogleGPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.19;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );
    double deg(double d) => d * math.pi / 180;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, deg(-45), deg(90), false, paint);
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, deg(45), deg(105), false, paint);
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, deg(150), deg(60), false, paint);
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, deg(210), deg(105), false, paint);

    final barPaint = Paint()..color = const Color(0xFF4285F4);
    canvas.drawRect(
      Rect.fromLTWH(
        size.width / 2,
        size.height / 2 - stroke / 2,
        size.width / 2,
        stroke,
      ),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
