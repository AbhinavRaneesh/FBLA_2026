import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../main.dart';

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
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  final TextEditingController _gradeLevelController = TextEditingController();

  final FocusNode _nameFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _gradeFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _confirmFocus = FocusNode();

  static const List<String> _roleOptions = [
    'Chapter Member',
    'Advisor',
    'Student',
    'Officer',
    'Other',
  ];
  String? _selectedRole;
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  bool _agreedToTerms = false;
  int _currentStep = 0;

  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  static const Color fblaBlue = Color(0xFF1D4E89);
  static const Color fblaGold = Color(0xFFF6C500);
  static const Color appBackground = Color(0xFF0A0E1A);
  static const Color cardColor = Color(0xFF141B2D);
  static const Color fieldBackground = Color(0xFF1A2235);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFB0B8C9);

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

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Name is required';
    return null;
  }

  String? _validateGradeLevel(String? value) {
    if (value == null || value.trim().isEmpty) return 'Grade level is required';
    return null;
  }

  String? _validateRole(String? value) {
    if (value == null || value.trim().isEmpty) return 'Please choose a role';
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
      duration: const Duration(milliseconds: 1000),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
      ),
    );
    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _gradeLevelController.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _gradeFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  bool _validateStep1() {
    final nameValid = _validateName(_nameController.text) == null;
    final emailValid = _validateEmail(_emailController.text) == null;
    final roleValid = _validateRole(_selectedRole) == null;
    final gradeValid = _validateGradeLevel(_gradeLevelController.text) == null;
    return nameValid && emailValid && roleValid && gradeValid;
  }

  void _nextStep() {
    HapticFeedback.lightImpact();
    if (_currentStep == 0) {
      if (_validateStep1()) {
        setState(() => _currentStep = 1);
      } else {
        _formKey.currentState?.validate();
        if (_validateRole(_selectedRole) != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Please select your role'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.red.shade700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    }
  }

  void _previousStep() {
    HapticFeedback.lightImpact();
    if (_currentStep > 0) {
      setState(() => _currentStep = 0);
    }
  }

  Future<void> _submit() async {
    HapticFeedback.lightImpact();
    if (!_formKey.currentState!.validate()) return;

    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please agree to the terms to continue'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade700,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final app = Provider.of<AppState>(context, listen: false);
      await app.signUpWithMongo(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        name: _nameController.text.trim(),
        role: _selectedRole!.trim(),
        grade: _gradeLevelController.text.trim(),
      );
      if (!mounted) return;
      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade700,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  InputDecoration _buildInputDecoration({
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: textSecondary, fontSize: 14),
      hintStyle: TextStyle(color: textSecondary.withOpacity(0.5), fontSize: 14),
      prefixIcon: Container(
        margin: const EdgeInsets.only(left: 12, right: 8),
        child: Icon(icon, color: fblaBlue.withOpacity(0.8), size: 22),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 48),
      suffixIcon: suffix,
      filled: true,
      fillColor: fieldBackground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.06), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: fblaBlue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.red.shade400, width: 2),
      ),
      errorStyle: TextStyle(color: Colors.red.shade300, fontSize: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBackground,
      body: Stack(
        children: [
          // Animated background gradient orbs
          Positioned(
            top: -100,
            left: -100,
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) => Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        fblaGold.withOpacity(0.12),
                        fblaGold.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            right: -100,
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) => Transform.scale(
                scale: 2.0 - _pulseAnimation.value,
                child: Container(
                  width: 350,
                  height: 350,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        fblaBlue.withOpacity(0.1),
                        fblaBlue.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 24),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Column(
                          children: [
                            _buildHeader(),
                            const SizedBox(height: 32),

                            // Progress indicator
                            _buildProgressIndicator(),
                            const SizedBox(height: 28),

                            // Form card
                            Container(
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 30,
                                    offset: const Offset(0, 15),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(28),
                                child: Form(
                                  key: _formKey,
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    transitionBuilder: (child, animation) {
                                      return FadeTransition(
                                        opacity: animation,
                                        child: SlideTransition(
                                          position: Tween<Offset>(
                                            begin: Offset(_currentStep == 0 ? 0.1 : -0.1, 0),
                                            end: Offset.zero,
                                          ).animate(animation),
                                          child: child,
                                        ),
                                      );
                                    },
                                    child: _currentStep == 0
                                        ? _buildStep1()
                                        : _buildStep2(),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),

                            // Login prompt
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Already have an account? ",
                                  style: TextStyle(
                                    color: textSecondary.withOpacity(0.8),
                                    fontSize: 14,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    Navigator.pop(context);
                                  },
                                  child: const Text(
                                    'Log in',
                                    style: TextStyle(
                                      color: fblaGold,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Column(
          children: [
            Image.asset(
              'assets/fbla_logo.png',
              width: width,
              height: width * 0.47,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 24),
            const Text(
              'Create Account',
              style: TextStyle(
                color: textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Join the FBLA community today',
              style: TextStyle(
                color: textSecondary.withOpacity(0.8),
                fontSize: 15,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProgressIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStepDot(0, 'Info'),
        Container(
          width: 60,
          height: 2,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(1),
            color: _currentStep >= 1 ? fblaBlue : Colors.white.withOpacity(0.1),
          ),
        ),
        _buildStepDot(1, 'Security'),
      ],
    );
  }

  Widget _buildStepDot(int step, String label) {
    final isActive = _currentStep >= step;
    final isCurrent = _currentStep == step;

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: isCurrent ? 40 : 32,
          height: isCurrent ? 40 : 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? fblaBlue : Colors.white.withOpacity(0.1),
            border: isCurrent
                ? Border.all(color: fblaBlue.withOpacity(0.3), width: 3)
                : null,
            boxShadow: isCurrent
                ? [
                    BoxShadow(
                      color: fblaBlue.withOpacity(0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: isActive && !isCurrent
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : Text(
                    '${step + 1}',
                    style: TextStyle(
                      color: isActive ? Colors.white : textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: isCurrent ? 16 : 14,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: isActive ? textPrimary : textSecondary.withOpacity(0.6),
            fontSize: 12,
            fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildStep1() {
    return Column(
      key: const ValueKey('step1'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Step title
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: fblaBlue.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.person_outline_rounded, color: fblaBlue, size: 22),
            ),
            const SizedBox(width: 14),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Personal Information',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Tell us about yourself',
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Name field
        TextFormField(
          controller: _nameController,
          focusNode: _nameFocus,
          decoration: _buildInputDecoration(
            label: 'Full Name',
            hint: 'Enter your full name',
            icon: Icons.badge_outlined,
          ),
          textInputAction: TextInputAction.next,
          style: const TextStyle(color: textPrimary, fontSize: 15),
          cursorColor: fblaGold,
          validator: _validateName,
          onFieldSubmitted: (_) => _emailFocus.requestFocus(),
        ),
        const SizedBox(height: 16),

        // Email field
        TextFormField(
          controller: _emailController,
          focusNode: _emailFocus,
          decoration: _buildInputDecoration(
            label: 'Email',
            hint: 'Enter your email',
            icon: Icons.mail_outline_rounded,
          ),
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: textPrimary, fontSize: 15),
          cursorColor: fblaGold,
          textInputAction: TextInputAction.next,
          validator: _validateEmail,
          autofillHints: const [AutofillHints.email],
          onFieldSubmitted: (_) => _gradeFocus.requestFocus(),
        ),
        const SizedBox(height: 16),

        // Role dropdown
        DropdownButtonFormField<String>(
          value: _selectedRole,
          style: const TextStyle(color: textPrimary, fontSize: 15),
          dropdownColor: const Color(0xFF1E2A42),
          iconEnabledColor: textSecondary,
          decoration: _buildInputDecoration(
            label: 'Role',
            hint: 'Select your role',
            icon: Icons.work_outline_rounded,
          ),
          items: _roleOptions
              .map(
                (role) => DropdownMenuItem<String>(
                  value: role,
                  child: Text(role),
                ),
              )
              .toList(),
          onChanged: (value) {
            HapticFeedback.selectionClick();
            setState(() => _selectedRole = value);
          },
          validator: _validateRole,
        ),
        const SizedBox(height: 16),

        // Grade level field
        TextFormField(
          controller: _gradeLevelController,
          focusNode: _gradeFocus,
          decoration: _buildInputDecoration(
            label: 'Grade Level',
            hint: '9, 10, 11, 12, College...',
            icon: Icons.school_outlined,
          ),
          textInputAction: TextInputAction.done,
          style: const TextStyle(color: textPrimary, fontSize: 15),
          cursorColor: fblaGold,
          validator: _validateGradeLevel,
          onFieldSubmitted: (_) => _nextStep(),
        ),
        const SizedBox(height: 28),

        // Next button
        _buildPrimaryButton(
          onPressed: _nextStep,
          label: 'Continue',
          isLoading: false,
          icon: Icons.arrow_forward_rounded,
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      key: const ValueKey('step2'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Back button and step title
        Row(
          children: [
            GestureDetector(
              onTap: _previousStep,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.arrow_back_rounded, color: textSecondary, size: 22),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Secure Your Account',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Create a strong password',
                    style: TextStyle(
                      color: textSecondary.withOpacity(0.8),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Password field
        TextFormField(
          controller: _passwordController,
          focusNode: _passwordFocus,
          decoration: _buildInputDecoration(
            label: 'Password',
            hint: 'At least 6 characters',
            icon: Icons.lock_outline_rounded,
            suffix: IconButton(
              icon: Icon(
                _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: textSecondary.withOpacity(0.7),
                size: 22,
              ),
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() => _obscure = !_obscure);
              },
            ),
          ),
          obscureText: _obscure,
          style: const TextStyle(color: textPrimary, fontSize: 15),
          cursorColor: fblaGold,
          textInputAction: TextInputAction.next,
          validator: _validatePassword,
          autofillHints: const [AutofillHints.newPassword],
          onFieldSubmitted: (_) => _confirmFocus.requestFocus(),
        ),
        const SizedBox(height: 16),

        // Confirm password field
        TextFormField(
          controller: _confirmController,
          focusNode: _confirmFocus,
          decoration: _buildInputDecoration(
            label: 'Confirm Password',
            hint: 'Re-enter your password',
            icon: Icons.lock_outline_rounded,
            suffix: IconButton(
              icon: Icon(
                _obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: textSecondary.withOpacity(0.7),
                size: 22,
              ),
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() => _obscureConfirm = !_obscureConfirm);
              },
            ),
          ),
          obscureText: _obscureConfirm,
          style: const TextStyle(color: textPrimary, fontSize: 15),
          cursorColor: fblaGold,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _submit(),
          validator: _validateConfirm,
          autofillHints: const [AutofillHints.newPassword],
        ),
        const SizedBox(height: 24),

        // Password requirements hint
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: fblaBlue.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: fblaBlue.withOpacity(0.15)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: fblaBlue.withOpacity(0.8), size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Password must be at least 6 characters long',
                  style: TextStyle(
                    color: textSecondary.withOpacity(0.9),
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Terms checkbox
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _agreedToTerms = !_agreedToTerms);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: _agreedToTerms ? fblaBlue : Colors.transparent,
                    border: Border.all(
                      color: _agreedToTerms ? fblaBlue : textSecondary.withOpacity(0.4),
                      width: 2,
                    ),
                  ),
                  child: _agreedToTerms
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: textSecondary.withOpacity(0.8),
                        fontSize: 13,
                        height: 1.4,
                      ),
                      children: const [
                        TextSpan(text: 'I agree to the '),
                        TextSpan(
                          text: 'Terms & Conditions',
                          style: TextStyle(
                            color: fblaBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Create account button
        _buildPrimaryButton(
          onPressed: _isLoading ? null : _submit,
          label: 'Create Account',
          isLoading: _isLoading,
        ),
      ],
    );
  }

  Widget _buildPrimaryButton({
    required VoidCallback? onPressed,
    required String label,
    required bool isLoading,
    IconData? icon,
  }) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [fblaBlue, Color(0xFF2A5F9E)],
        ),
        boxShadow: [
          BoxShadow(
            color: fblaBlue.withOpacity(0.4),
            blurRadius: 15,
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
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (icon != null) ...[
                    const SizedBox(width: 8),
                    Icon(icon, color: Colors.white, size: 20),
                  ],
                ],
              ),
      ),
    );
  }
}
