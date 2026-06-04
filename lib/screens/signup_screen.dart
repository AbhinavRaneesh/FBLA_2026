import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/firebase_service.dart';
import 'terms_conditions_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _schoolController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  final PageController _pageController = PageController();

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

  String? _validateConfirm(String? value) {
    if (value == null || value.isEmpty) return 'Please confirm password';
    if (value != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
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
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (_nameController.text.trim().isEmpty) {
        _showError('Please enter your name');
        return;
      }
      if (_validateEmail(_emailController.text) != null) {
        _showError('Please enter a valid email');
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
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _previousStep() {
    setState(() => _currentStep--);
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
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

  Future<void> _submit() async {
    if (_validatePassword(_passwordController.text) != null) {
      _showError('Password must be at least 6 characters');
      return;
    }
    if (_validateConfirm(_confirmController.text) != null) {
      _showError('Passwords do not match');
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
      _showError(e.toString().replaceFirst('Exception: ', ''));
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
                  SafeArea(
                    child: Column(
                      children: [
                        _buildTopBar(),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(22, 4, 22, 18),
                            child: FadeTransition(
                              opacity: _fadeAnimation,
                              child: SlideTransition(
                                position: _slideAnimation,
                                child: Column(
                                  children: [
                                    _buildHeader(),
                                    const SizedBox(height: 18),
                                    _buildStepIndicator(),
                                    const SizedBox(height: 14),
                                    _buildFormCard(),
                                    const SizedBox(height: 18),
                                    _buildLoginPrompt(),
                                    const SizedBox(height: 8),
                                    Container(
                                      width: 98,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: Colors.white
                                            .withValues(alpha: 0.42),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                    ),
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

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed:
                _currentStep > 0 ? _previousStep : () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white),
          ),
          const Spacer(),
          Text(
            'Step ${_currentStep + 1} of 3',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final isCompact = MediaQuery.of(context).size.height < 720;
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
          'CREATE YOUR\nACCOUNT',
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
              width: isCurrent ? 32 : 12,
              height: 12,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: isActive
                    ? const Color(0xFF3C67FF)
                    : Colors.white.withValues(alpha: 0.16),
                boxShadow: isCurrent
                    ? [
                        BoxShadow(
                          color:
                              const Color(0xFF2B55F5).withValues(alpha: 0.32),
                          blurRadius: 12,
                        ),
                      ]
                    : null,
              ),
            ),
            if (index < 2) const SizedBox(width: 8),
          ],
        );
      }),
    );
  }

  Widget _buildFormCard() {
    final isCompact = MediaQuery.of(context).size.height < 720;
    final cardHeight = _currentStep == 0
        ? (isCompact ? 300.0 : 320.0)
        : _currentStep == 1
            ? (isCompact ? 430.0 : 450.0)
            : (isCompact ? 340.0 : 360.0);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      constraints: const BoxConstraints(maxWidth: 400),
      height: cardHeight,
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Form(
          key: _formKey,
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildStep1(),
              _buildStep2(),
              _buildStep3(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCardCaption('Start with your basic information'),
          const SizedBox(height: 18),
          _buildTextField(
            controller: _nameController,
            hint: 'Full name',
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _emailController,
            hint: 'Email',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 28),
          _buildPrimaryButton(
            onPressed: _nextStep,
            label: 'Continue',
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCardCaption('Choose your FBLA role'),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: _roleOptions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final role = _roleOptions[index];
                final isSelected = _selectedRole == role;
                return _buildRoleOption(role, isSelected);
              },
            ),
          ),
          const SizedBox(height: 14),
          _buildSectionLabel('Select your school'),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _schoolController,
            hint: 'Search school name',
            icon: Icons.apartment_rounded,
            suffixIcon: Icon(
              Icons.search_rounded,
              color: Colors.white.withValues(alpha: 0.42),
              size: 20,
            ),
          ),
          const SizedBox(height: 14),
          _buildPrimaryButton(
            onPressed: _nextStep,
            label: 'Continue',
          ),
        ],
      ),
    );
  }

  Widget _buildRoleOption(String role, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(7),
          color: isSelected
              ? const Color(0xFF2B55F5).withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.055),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF6B8BFF)
                : Colors.white.withValues(alpha: 0.09),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              _getRoleIcon(role),
              color: isSelected
                  ? const Color(0xFF6B8BFF)
                  : Colors.white.withValues(alpha: 0.58),
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              role,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
            const Spacer(),
            if (isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF3C67FF),
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 16),
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

  Widget _buildStep3() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCardCaption('Secure your account'),
          const SizedBox(height: 18),
          _buildTextField(
            controller: _passwordController,
            hint: 'Password',
            icon: Icons.lock_outline,
            obscureText: _obscure,
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
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _confirmController,
            hint: 'Confirm password',
            icon: Icons.lock_outline,
            obscureText: _obscureConfirm,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirm
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: Colors.white.withValues(alpha: 0.48),
                size: 19,
              ),
              onPressed: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
            ),
          ),
          const SizedBox(height: 16),
          _buildTermsCheckbox(),
          const SizedBox(height: 22),
          _buildPrimaryButton(
            onPressed: _isLoading ? null : _submit,
            label: 'Create Account',
            isLoading: _isLoading,
          ),
        ],
      ),
    );
  }

  Widget _buildTermsCheckbox() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: _agreedToTerms
                  ? const Color(0xFF3C67FF)
                  : Colors.white.withValues(alpha: 0.02),
              border: Border.all(
                color: _agreedToTerms
                    ? const Color(0xFF3C67FF)
                    : Colors.white.withValues(alpha: 0.48),
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
            children: [
              Text(
                'I agree to the ',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.58),
                  fontSize: 11.5,
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
                    color: Color(0xFF6B8BFF),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    decoration: TextDecoration.underline,
                    decorationColor: Color(0xFF6B8BFF),
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

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.78),
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        color: const Color(0xFF111722),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
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
        ),
      ),
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
                label.toUpperCase(),
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

  Widget _buildLoginPrompt() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Already have an account? ",
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.54),
            fontSize: 12,
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
          child: const Text(
            'Log in',
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
