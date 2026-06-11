import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../services/firebase_service.dart';

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

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    const pattern = r'^[^@\s]+@[^@\s]+\.[^@\s]+$';
    final regExp = RegExp(pattern);
    if (!regExp.hasMatch(value.trim())) return 'Enter a valid email';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 6) return 'Minimum 6 characters';
    return null;
  }

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

    final emailError = _validateEmail(email);
    final passwordError = _validatePassword(password);
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
      _shakeController.forward(from: 0);
      final rawMessage = e.toString().replaceFirst('Exception: ', '');
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
              decoration: const BoxDecoration(gradient: appBackgroundGradient),
            ),
            Positioned(
              left: -78 + (math.sin(value * math.pi * 2) * 12),
              top: 38 + (math.cos(value * math.pi * 2) * 10),
              child: Transform.rotate(
                angle: -0.78 + math.sin(value * math.pi * 2) * 0.09,
                child: const Opacity(
                  opacity: 0.85,
                  child: _Ribbon(size: 178, palette: _Ribbon.gold),
                ),
              ),
            ),
            Positioned(
              right: -74 + (math.cos(value * math.pi * 2) * 16),
              top: 92 + (math.sin(value * math.pi * 2) * 8),
              child: Transform.rotate(
                angle: 0.85 - math.sin(value * math.pi * 2) * 0.1,
                child: const Opacity(
                  opacity: 0.85,
                  child: _Ribbon(size: 132, palette: _Ribbon.navy),
                ),
              ),
            ),
            Positioned(
              right: -72 + (math.sin(value * math.pi * 2) * 14),
              bottom: -10 + (math.cos(value * math.pi * 2) * 12),
              child: Transform.rotate(
                angle: -0.86 + math.sin(value * math.pi * 2) * 0.08,
                child: const Opacity(
                  opacity: 0.85,
                  child: _Ribbon(size: 178, palette: _Ribbon.gold),
                ),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(painter: _GoldDustPainter(value)),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.85),
                    radius: 0.9,
                    colors: [
                      fblaGold.withValues(alpha: 0.10),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(
                      0.22 + math.sin(value * math.pi * 2) * 0.08,
                      -0.62,
                    ),
                    radius: 0.88,
                    colors: [
                      fblaBlue.withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
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
                  _staggered(0, _buildEyebrow()),
                  SizedBox(height: isCompact ? 14 : 18),
                  _staggered(0, _buildLogo(isCompact: isCompact)),
                  SizedBox(height: isCompact ? 18 : 26),
                  _staggered(1, _buildHeading(isCompact: isCompact)),
                  SizedBox(height: isCompact ? 18 : 24),
                  _staggered(2, _buildShakeWrapper(_buildLoginCard())),
                  SizedBox(height: isCompact ? 16 : 20),
                  _staggered(3, _buildSignUpPrompt()),
                  const SizedBox(height: 14),
                  _staggered(3, _buildVarsityStripe()),
                  SizedBox(height: isCompact ? 16 : 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEyebrow() {
    Widget hairline() => Container(
          width: 24,
          height: 2,
          decoration: BoxDecoration(
            color: fblaGold.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(999),
          ),
        );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        hairline(),
        const SizedBox(width: 10),
        const Text(
          'FUTURE BUSINESS LEADERS OF AMERICA',
          style: TextStyle(
            color: fblaGold,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 3.0,
          ),
        ),
        const SizedBox(width: 10),
        hairline(),
      ],
    );
  }

  Widget _buildLogo({required bool isCompact}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final logoWidth = (screenWidth * 0.52).clamp(128.0, 185.0).toDouble();
    final logoHeight = isCompact ? 42.0 : 50.0;
    return Hero(
      tag: 'fbla_logo',
      child: Container(
        width: logoWidth + 32,
        height: logoHeight + 14,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.97),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: fblaGold.withValues(alpha: 0.55),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: fblaGold.withValues(alpha: 0.25),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Center(
          child: Transform.scale(
            scale: 2,
            child: Image.asset(
              'assets/fbla_logo.png',
              width: logoWidth,
              height: logoHeight,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeading({required bool isCompact}) {
    final headingSize = isCompact ? 24.0 : 28.0;
    return Column(
      children: [
        Text(
          'Welcome back,',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: headingSize,
            height: 1.15,
            fontWeight: FontWeight.w800,
          ),
        ),
        ShaderMask(
          shaderCallback: (rect) => const LinearGradient(
            colors: [Color(0xFFFFE08A), fblaGold, Color(0xFFE09A00)],
          ).createShader(rect),
          child: Text(
            'Leader.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: headingSize,
              height: 1.15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 10),
        AnimatedBuilder(
          animation: _animationController,
          builder: (context, _) {
            final t = const Interval(0.45, 0.8, curve: Curves.easeOutCubic)
                .transform(_animationController.value);
            return Container(
              width: 56 * t,
              height: 3,
              decoration: BoxDecoration(
                color: fblaGold.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(999),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        Text(
          'Sign in to continue your road to Nationals',
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
                    colors: [Color(0xFFFFE08A), fblaGold, Color(0xFFE09A00)],
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
            ? fblaGold.withValues(alpha: 0.85)
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
                      color: fblaGold.withValues(alpha: 0.18),
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
                      ? fblaGold
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
                    cursorColor: fblaGold,
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
                      ? fblaGold
                      : Colors.white.withValues(alpha: 0.02),
                  border: Border.all(
                    color: _rememberMe
                        ? fblaGold
                        : Colors.white.withValues(alpha: 0.40),
                  ),
                ),
                child: AnimatedScale(
                  scale: _rememberMe ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutBack,
                  child: const Icon(Icons.check, color: fblaNavy, size: 11),
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
              color: fblaGold,
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
              color: fblaGold,
              fontWeight: FontWeight.w800,
              fontSize: 13.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVarsityStripe() {
    Widget segment(Color color) => Container(
          width: 34,
          height: 3,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(999),
          ),
        );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        segment(fblaBlue),
        const SizedBox(width: 6),
        segment(fblaGold),
        const SizedBox(width: 6),
        segment(fblaBlue),
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

class _Ribbon extends StatelessWidget {
  final double size;
  final List<Color> palette;

  static const List<Color> gold = [
    Color(0xFFFFE08A),
    Color(0xFFFDB913),
    Color(0xFF9A6B00),
    Color(0xFFFFD24A),
  ];
  static const List<Color> navy = [
    Color(0xFF3A78C9),
    Color(0xFF1D4E89),
    Color(0xFF00274D),
    Color(0xFF4A8AD9),
  ];

  const _Ribbon({required this.size, required this.palette});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RibbonPainter(
          colors: palette,
          shadowColor: palette == gold
              ? const Color(0xFF8A6500)
              : const Color(0xFF0D2B55),
        ),
      ),
    );
  }
}

class _RibbonPainter extends CustomPainter {
  final List<Color> colors;
  final Color shadowColor;

  const _RibbonPainter({required this.colors, required this.shadowColor});

  @override
  void paint(Canvas canvas, Size size) {
    final ribbonPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
        stops: const [0.0, 0.34, 0.68, 1.0],
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width * 0.08, size.height * 0.24)
      ..cubicTo(
        size.width * 0.35,
        size.height * 0.02,
        size.width * 0.74,
        size.height * 0.04,
        size.width * 0.88,
        size.height * 0.28,
      )
      ..cubicTo(
        size.width * 0.66,
        size.height * 0.36,
        size.width * 0.42,
        size.height * 0.48,
        size.width * 0.23,
        size.height * 0.68,
      )
      ..cubicTo(
        size.width * 0.48,
        size.height * 0.56,
        size.width * 0.77,
        size.height * 0.58,
        size.width * 0.94,
        size.height * 0.82,
      )
      ..cubicTo(
        size.width * 0.62,
        size.height,
        size.width * 0.18,
        size.height * 0.96,
        size.width * 0.04,
        size.height * 0.70,
      )
      ..cubicTo(
        size.width * 0.22,
        size.height * 0.52,
        size.width * 0.34,
        size.height * 0.40,
        size.width * 0.08,
        size.height * 0.24,
      )
      ..close();

    canvas.drawShadow(path, shadowColor, 16, true);
    canvas.drawPath(path, ribbonPaint);

    final highlightPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.42),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.035
      ..strokeCap = StrokeCap.round;

    final highlightPath = Path()
      ..moveTo(size.width * 0.16, size.height * 0.28)
      ..cubicTo(
        size.width * 0.42,
        size.height * 0.14,
        size.width * 0.68,
        size.height * 0.18,
        size.width * 0.82,
        size.height * 0.31,
      );
    canvas.drawPath(highlightPath, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant _RibbonPainter oldDelegate) =>
      oldDelegate.colors != colors;
}

class _GoldDustPainter extends CustomPainter {
  final double t;

  _GoldDustPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    // Fixed seed keeps particle positions stable across frames; only t moves them.
    final rnd = math.Random(7);
    final paint = Paint();
    for (int i = 0; i < 12; i++) {
      final baseX = rnd.nextDouble();
      final baseY = rnd.nextDouble();
      final twinklePhase = rnd.nextDouble();
      final radius = 1.0 + rnd.nextDouble() * 1.2;
      final drift = rnd.nextDouble() * 0.02;
      // Integer cycle counts keep motion seamless when t wraps 1 -> 0.
      final y = (baseY - t) % 1.0;
      final x = (baseX + math.sin((t + twinklePhase) * math.pi * 2) * drift);
      final twinkle =
          0.5 + 0.5 * math.sin((t * 2 + twinklePhase) * math.pi * 2);
      paint.color = fblaGold.withValues(alpha: 0.05 + 0.25 * twinkle);
      canvas.drawCircle(
        Offset(x * size.width, y * size.height),
        radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GoldDustPainter oldDelegate) =>
      oldDelegate.t != t;
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
