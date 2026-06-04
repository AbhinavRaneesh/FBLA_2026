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
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscure = true;
  bool _isLoading = false;
  bool _rememberMe = false;
  bool _showSplash = true;
  late AnimationController _animationController;
  late AnimationController _backgroundController;
  late AnimationController _splashController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  static const Color fblaBlue = Color(0xFF1D4E89);
  static const Color fblaGold = Color(0xFFF6C500);

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
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
    _splashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _splashController.forward();
    Timer(const Duration(milliseconds: 1650), () {
      if (!mounted) return;
      setState(() => _showSplash = false);
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _backgroundController.dispose();
    _splashController.dispose();
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

    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

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
      backgroundColor: const Color(0xFF030813),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Center(
            child: SizedBox(
              width: math.min(constraints.maxWidth, 430),
              height: constraints.maxHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildAnimatedBackground(),
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
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF030813),
                    Color(0xFF07111F),
                    Color(0xFF151922),
                  ],
                ),
              ),
            ),
            Positioned(
              left: -78 + (math.sin(value * math.pi * 2) * 12),
              top: 38 + (math.cos(value * math.pi * 2) * 10),
              child: Transform.rotate(
                angle: -0.78 + value * 0.18,
                child: const _BlueRibbon(size: 178),
              ),
            ),
            Positioned(
              right: -74 + (math.cos(value * math.pi * 2) * 16),
              top: 92 + (math.sin(value * math.pi * 2) * 8),
              child: Transform.rotate(
                angle: 0.85 - value * 0.2,
                child: const _BlueRibbon(size: 132),
              ),
            ),
            Positioned(
              right: -72 + (math.sin(value * math.pi * 2) * 14),
              bottom: -10 + (math.cos(value * math.pi * 2) * 12),
              child: Transform.rotate(
                angle: -0.86 + value * 0.16,
                child: const _BlueRibbon(size: 178),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0.22 + value * 0.08, -0.62),
                    radius: 0.88,
                    colors: [
                      fblaBlue.withValues(alpha: 0.18),
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
        child: const Center(
          child: Text(
            'FBLA.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 27,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginView(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.height < 720;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(22, isCompact ? 28 : 46, 22, 18),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Column(
              children: [
                _buildHeader(isCompact: isCompact),
                SizedBox(height: isCompact ? 20 : 28),
                _buildLoginCard(),
                SizedBox(height: isCompact ? 18 : 26),
                _buildSignUpPrompt(),
                const SizedBox(height: 8),
                Container(
                  width: 98,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.42),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader({required bool isCompact}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final logoWidth = (screenWidth * 0.52).clamp(128.0, 185.0).toDouble();
    final logoHeight = isCompact ? 42.0 : 50.0;
    return Column(
      children: [
        Hero(
          tag: 'fbla_logo',
          child: Container(
            width: logoWidth + 32,
            height: logoHeight + 14,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: fblaBlue.withValues(alpha: 0.28),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
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
        ),
        SizedBox(height: isCompact ? 28 : 38),
        const Text(
          'LOGIN TO\nYOUR ACCOUNT',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 21,
            height: 1.18,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard() {
    final isCompact = MediaQuery.of(context).size.height < 720;
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF17233D).withValues(alpha: 0.92),
            const Color(0xFF171B22).withValues(alpha: 0.98),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, isCompact ? 22 : 26, 16, 22),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Enter your login information',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: isCompact ? 18 : 22),
              _buildTextField(
                controller: _emailController,
                hint: 'Email',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: _validateEmail,
                autofillHints: const [AutofillHints.email],
              ),
              SizedBox(height: isCompact ? 12 : 14),
              _buildTextField(
                controller: _passwordController,
                hint: 'Password',
                icon: Icons.lock_outline,
                obscureText: _obscure,
                validator: _validatePassword,
                autofillHints: const [AutofillHints.password],
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.white.withValues(alpha: 0.48),
                    size: 19,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 8),
              _buildRememberForgotRow(),
              SizedBox(height: isCompact ? 14 : 18),
              _buildPrimaryButton(
                onPressed: _isLoading ? null : _submit,
                label: 'LOGIN',
                isLoading: _isLoading,
              ),
              SizedBox(height: isCompact ? 16 : 22),
              _buildDivider('Or'),
              SizedBox(height: isCompact ? 14 : 18),
              Row(
                children: [
                  Expanded(
                    child: _buildSocialButton(
                      onPressed: _isLoading ? null : _signInWithGoogle,
                      label: 'GOOGLE',
                      iconUrl:
                          'https://img.icons8.com/color/48/google-logo.png',
                      fallbackIcon: Icons.g_mobiledata_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildAppleButton(onPressed: null),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    String? Function(String?)? validator,
    List<String>? autofillHints,
    Widget? suffixIcon,
    void Function(String)? onSubmitted,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        color: const Color(0xFF111722),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        validator: validator,
        autofillHints: autofillHints,
        onFieldSubmitted: onSubmitted,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        cursorColor: fblaGold,
        decoration: InputDecoration(
          filled: true,
          fillColor: const Color(0xFF111722),
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.46),
            fontSize: 12.5,
          ),
          prefixIcon: Icon(
            icon,
            color: Colors.white.withValues(alpha: 0.56),
            size: 19,
          ),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          errorStyle: const TextStyle(color: Color(0xFFFF7A7A), fontSize: 11),
        ),
      ),
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
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: _rememberMe
                      ? fblaBlue
                      : Colors.white.withValues(alpha: 0.02),
                  border: Border.all(
                    color: _rememberMe
                        ? fblaBlue
                        : Colors.white.withValues(alpha: 0.48),
                  ),
                ),
                child: _rememberMe
                    ? const Icon(Icons.check, color: Colors.white, size: 10)
                    : null,
              ),
              const SizedBox(width: 7),
              Text(
                'Remember me',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.58),
                  fontSize: 11.5,
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
          child: Text(
            'Forgot password',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.58),
              fontSize: 11.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton({
    required VoidCallback? onPressed,
    required String label,
    bool isLoading = false,
  }) {
    return Container(
      height: 43,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        gradient: const LinearGradient(
          colors: [Color(0xFF3C67FF), Color(0xFF2B55F5)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2B55F5).withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(7),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.2,
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
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
              fontWeight: FontWeight.w500,
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

  Widget _buildSocialButton({
    required VoidCallback? onPressed,
    required String label,
    required String iconUrl,
    required IconData fallbackIcon,
  }) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        color: Colors.white.withValues(alpha: 0.055),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(7),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              padding: const EdgeInsets.all(4),
              child: Image.network(
                iconUrl,
                errorBuilder: (_, __, ___) => Icon(
                  fallbackIcon,
                  color: const Color(0xFF4285F4),
                  size: 16,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppleButton({required VoidCallback? onPressed}) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        color: Colors.white.withValues(alpha: 0.055),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          disabledForegroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(7),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.apple, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              'APPLE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
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
          "Don't have an account? ",
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.54),
            fontSize: 12,
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
          ),
          child: const Text(
            'Sign up',
            style: TextStyle(
              color: Color(0xFF6B8BFF),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

class _BlueRibbon extends StatelessWidget {
  final double size;

  const _BlueRibbon({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _BlueRibbonPainter(),
      ),
    );
  }
}

class _BlueRibbonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final ribbonPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF05D9FF),
          Color(0xFF2563FF),
          Color(0xFF0A1E73),
          Color(0xFF54F0FF),
        ],
        stops: [0.0, 0.34, 0.68, 1.0],
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

    canvas.drawShadow(path, const Color(0xFF0D5BFF), 16, true);
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
