import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../services/firebase_service.dart';
import '../utils/validators.dart';
import 'terms_conditions_screen.dart';

// Shared design tokens with the login screen so the two pages read as siblings.
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

const Color _accentBlue = Color(0xFF4D9DE0);

// Clips the FBLA asset to just the triangle emblem (matches login_screen).
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

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with TickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _schoolController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  final FocusNode _nameFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _schoolFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _confirmFocus = FocusNode();

  static const List<String> _roleOptions = [
    'Student',
    'Advisor',
    'Officer',
  ];

  String? _selectedRole;
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  bool _agreedToTerms = false;
  int _currentStep = 0;

  late AnimationController _animationController;
  late AnimationController _backgroundController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    for (final node in [
      _nameFocus,
      _emailFocus,
      _schoolFocus,
      _passwordFocus,
      _confirmFocus,
    ]) {
      node.addListener(() => setState(() {}));
    }
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _backgroundController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _schoolController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _schoolFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep == 0) {
      final nameError = Validators.name(_nameController.text, field: 'Name');
      if (nameError != null) {
        _showError(nameError);
        return;
      }
      final emailError = Validators.email(_emailController.text);
      if (emailError != null) {
        _showError(emailError);
        return;
      }
    } else if (_currentStep == 1) {
      if (_selectedRole == null) {
        _showError('Please select a role');
        return;
      }
      if (_schoolController.text.trim().isEmpty) {
        _showError('Please select your school');
        return;
      }
    }
    setState(() => _currentStep++);
  }

  void _previousStep() {
    setState(() => _currentStep--);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red.shade700,
      ),
    );
  }

  /// Called when signup fails because there is no network connection.
  /// Saves the data for later retry, logs the user in locally so the demo
  /// can continue uninterrupted, and shows a subtle gold banner.
  Future<void> _handleOfflineSignup() async {
    if (!mounted) return;
    final app = Provider.of<AppState>(context, listen: false);
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    await app.savePendingSignup(
      name: name,
      email: email,
      password: _passwordController.text,
      school: _schoolController.text.trim(),
      role: _selectedRole ?? 'Student',
    );
    await app.login(email, name, role: _selectedRole ?? 'Student', grade: '');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.cloud_off_rounded, color: fblaGold, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text('Account saved — will sync when you\'re online'),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1A3A5C),
        duration: const Duration(seconds: 5),
      ),
    );
    Navigator.pop(context, {
      'email': email,
      'password': _passwordController.text,
    });
  }

  Future<void> _submit() async {
    final passwordError = Validators.newPassword(_passwordController.text);
    if (passwordError != null) {
      _showError(passwordError);
      return;
    }
    final confirmError = Validators.confirmPassword(
        _confirmController.text, _passwordController.text);
    if (confirmError != null) {
      _showError(confirmError);
      return;
    }
    if (!_agreedToTerms) {
      _showError('Please agree to the terms first');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await FirebaseService.signUpWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (result?.user != null) {
        final user = result!.user!;
        final fullName = _nameController.text.trim();
        await user.updateDisplayName(fullName);
        await FirebaseService.createUserProfile(
          userId: user.uid,
          name: fullName,
          email: user.email ?? _emailController.text.trim(),
          chapter: null,
          school: _schoolController.text.trim(),
          officerPosition: null,
          biography: null,
          points: 0,
          streak: 0,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, {
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
      });
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      if (msg.startsWith('[offline]')) {
        await _handleOfflineSignup();
        return;
      }
      _showError(msg);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.height < 720;
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
                  SafeArea(
                    child: Column(
                      children: [
                        _buildTopBar(),
                        Expanded(
                          child: SingleChildScrollView(
                            padding:
                                const EdgeInsets.fromLTRB(24, 4, 24, 20),
                            child: FadeTransition(
                              opacity: _fadeAnimation,
                              child: SlideTransition(
                                position: _slideAnimation,
                                child: Column(
                                  children: [
                                    SizedBox(height: isCompact ? 8 : 16),
                                    _buildLogo(isCompact: isCompact),
                                    SizedBox(height: isCompact ? 14 : 20),
                                    _buildHeading(isCompact: isCompact),
                                    SizedBox(height: isCompact ? 18 : 22),
                                    _buildStepIndicator(),
                                    SizedBox(height: isCompact ? 16 : 20),
                                    _buildFormCard(),
                                    SizedBox(height: isCompact ? 16 : 20),
                                    _buildLoginPrompt(),
                                    SizedBox(height: isCompact ? 8 : 12),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ---- Background (mirrors login_screen) -------------------------------------

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
            Positioned(
              top: -56,
              right: -64,
              child: Opacity(
                opacity: 0.04,
                child: Transform.rotate(
                  angle: 0.18,
                  child: Image.asset(
                    'assets/fbla_logo.png',
                    width: 320,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
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

  // ---- Header -----------------------------------------------------------------

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          IconButton(
            tooltip: _currentStep > 0 ? 'Previous step' : 'Back',
            onPressed:
                _currentStep > 0 ? _previousStep : () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 20),
          ),
          const Spacer(),
          Text(
            'Step ${_currentStep + 1} of 3',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }

  Widget _buildLogo({required bool isCompact}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final logoWidth = (screenWidth * (isCompact ? 0.52 : 0.60))
        .clamp(200.0, 290.0)
        .toDouble();
    final logoHeight = logoWidth / 1.5;

    const artworkBand = 0.48;
    const artworkAlignY = -0.18;

    final lockup = SizedBox(
      width: logoWidth,
      height: logoHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColorFiltered(
            colorFilter: const ColorFilter.matrix(<double>[
              0, 0, 0, 0, 255, //
              0, 0, 0, 0, 255, //
              0, 0, 0, 0, 255, //
              0, 0, 0, 1, 0, //
            ]),
            child: Image.asset('assets/fbla_logo.png', fit: BoxFit.contain),
          ),
          ClipRect(
            clipper: _EmblemClipper(),
            child: Image.asset('assets/fbla_logo.png', fit: BoxFit.contain),
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
          'Create account',
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
        Container(
          width: 56,
          height: 3,
          decoration: BoxDecoration(
            color: _accentBlue.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Join your FBLA member community',
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

  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        final isActive = index <= _currentStep;
        final isCurrent = index == _currentStep;
        return Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: isCurrent ? 30 : 10,
              height: 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: isActive
                    ? _accentBlue
                    : Colors.white.withValues(alpha: 0.16),
                boxShadow: isCurrent
                    ? [
                        BoxShadow(
                          color: _accentBlue.withValues(alpha: 0.4),
                          blurRadius: 10,
                        ),
                      ]
                    : null,
              ),
            ),
            if (index < 2) const SizedBox(width: 7),
          ],
        );
      }),
    );
  }

  // ---- Card -------------------------------------------------------------------

  Widget _buildFormCard() {
    final isCompact = MediaQuery.of(context).size.height < 720;
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      width: double.infinity,
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
              padding: EdgeInsets.fromLTRB(20, isCompact ? 22 : 24, 20, 22),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.06, 0),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(
                  key: ValueKey(_currentStep),
                  child: _buildStepContent(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1();
      case 1:
        return _buildStep2();
      default:
        return _buildStep3();
    }
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildCardCaption('Start with your basic information'),
        const SizedBox(height: 18),
        _buildField(
          label: 'Full name',
          controller: _nameController,
          focusNode: _nameFocus,
          hint: 'Jane Smith',
          icon: Icons.person_outline,
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 14),
        _buildField(
          label: 'Email',
          controller: _emailController,
          focusNode: _emailFocus,
          hint: 'you@school.org',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          onSubmitted: (_) => _nextStep(),
        ),
        const SizedBox(height: 24),
        _buildGoldButton(onTap: _nextStep, label: 'Continue'),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildCardCaption('Choose your FBLA role'),
        const SizedBox(height: 16),
        ..._roleOptions.map((role) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildRoleOption(role, _selectedRole == role),
            )),
        const SizedBox(height: 4),
        _buildFieldLabel('Select your school'),
        const SizedBox(height: 8),
        _buildBareField(
          controller: _schoolController,
          focusNode: _schoolFocus,
          hint: 'Search school name',
          icon: Icons.apartment_rounded,
          suffixIcon: Icon(
            Icons.search_rounded,
            color: Colors.white.withValues(alpha: 0.45),
            size: 20,
          ),
        ),
        const SizedBox(height: 22),
        _buildGoldButton(onTap: _nextStep, label: 'Continue'),
      ],
    );
  }

  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildCardCaption('Secure your account'),
        const SizedBox(height: 18),
        _buildField(
          label: 'Password',
          controller: _passwordController,
          focusNode: _passwordFocus,
          hint: 'Create a password',
          icon: Icons.lock_outline,
          obscureText: _obscure,
          onChanged: (_) => setState(() {}),
          suffixIcon: _visibilityToggle(
            obscured: _obscure,
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
        _buildPasswordStrengthMeter(),
        const SizedBox(height: 14),
        _buildField(
          label: 'Confirm password',
          controller: _confirmController,
          focusNode: _confirmFocus,
          hint: 'Re-enter your password',
          icon: Icons.lock_outline,
          obscureText: _obscureConfirm,
          onSubmitted: (_) => _submit(),
          suffixIcon: _visibilityToggle(
            obscured: _obscureConfirm,
            onPressed: () =>
                setState(() => _obscureConfirm = !_obscureConfirm),
          ),
        ),
        const SizedBox(height: 16),
        _buildTermsCheckbox(),
        const SizedBox(height: 22),
        _buildGoldButton(
          onTap: _isLoading ? null : _submit,
          label: 'Create Account',
          isLoading: _isLoading,
        ),
      ],
    );
  }

  Widget _visibilityToggle({
    required bool obscured,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: obscured ? 'Show password' : 'Hide password',
      icon: Icon(
        obscured
            ? Icons.visibility_off_outlined
            : Icons.visibility_outlined,
        color: Colors.white.withValues(alpha: 0.48),
        size: 20,
      ),
      onPressed: onPressed,
    );
  }

  Widget _buildRoleOption(String role, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: isSelected
              ? _accentBlue.withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.04),
          border: Border.all(
            color: isSelected
                ? _accentBlue.withValues(alpha: 0.9)
                : Colors.white.withValues(alpha: 0.10),
            width: isSelected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              _getRoleIcon(role),
              color: isSelected
                  ? _accentBlue
                  : Colors.white.withValues(alpha: 0.58),
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              role,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
            const Spacer(),
            if (isSelected)
              Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: _accentBlue,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 14),
              ),
          ],
        ),
      ),
    );
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'Advisor':
        return Icons.school_outlined;
      case 'Student':
        return Icons.person_outline;
      case 'Officer':
        return Icons.badge_outlined;
      default:
        return Icons.more_horiz;
    }
  }

  Widget _buildTermsCheckbox() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              color: _agreedToTerms
                  ? _accentBlue
                  : Colors.white.withValues(alpha: 0.02),
              border: Border.all(
                color: _agreedToTerms
                    ? _accentBlue
                    : Colors.white.withValues(alpha: 0.40),
              ),
            ),
            child: _agreedToTerms
                ? const Icon(Icons.check, color: Colors.white, size: 12)
                : null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'I agree to the ',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.58),
                  fontSize: 12.5,
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const TermsConditionsScreen(),
                    ),
                  );
                },
                child: const Text(
                  'Terms & Conditions',
                  style: TextStyle(
                    color: _accentBlue,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCardCaption(String text) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.72),
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildFieldLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.72),
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildPasswordStrengthMeter() {
    final value = _passwordController.text;
    final strength = Validators.estimateStrength(value);
    if (strength == PasswordStrength.empty) {
      return const SizedBox(height: 0);
    }
    const colors = {
      PasswordStrength.weak: Color(0xFFE5484D),
      PasswordStrength.fair: Color(0xFFF5A623),
      PasswordStrength.good: _accentBlue,
      PasswordStrength.strong: Color(0xFF30A46C),
    };
    final color = colors[strength] ?? Colors.grey;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              label: 'Password strength: ${strength.label}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: strength.fraction,
                  minHeight: 4,
                  backgroundColor: Colors.white.withValues(alpha: 0.10),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            strength.label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ---- Fields (login_screen look) --------------------------------------------

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(label),
        const SizedBox(height: 8),
        _buildBareField(
          controller: controller,
          focusNode: focusNode,
          hint: hint,
          icon: icon,
          keyboardType: keyboardType,
          obscureText: obscureText,
          suffixIcon: suffixIcon,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          textCapitalization: textCapitalization,
        ),
      ],
    );
  }

  Widget _buildBareField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    final focused = focusNode.hasFocus;
    final borderColor = focused
        ? _accentBlue.withValues(alpha: 0.9)
        : Colors.white.withValues(alpha: 0.10);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: borderColor),
        boxShadow: focused
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
              color:
                  focused ? _accentBlue : Colors.white.withValues(alpha: 0.55),
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
                onChanged: onChanged,
                onSubmitted: onSubmitted,
                textCapitalization: textCapitalization,
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
    );
  }

  // ---- Gold primary button (login_screen look) -------------------------------

  Widget _buildGoldButton({
    required VoidCallback? onTap,
    required String label,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
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
        child: Center(
          child: isLoading
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation<Color>(fblaNavy),
                  ),
                )
              : Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: fblaNavy,
                    letterSpacing: 1.4,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildLoginPrompt() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Already have an account? ',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.54),
            fontSize: 13.5,
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            minimumSize: const Size(0, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'Log in',
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
