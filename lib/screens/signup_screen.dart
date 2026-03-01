import 'package:flutter/material.dart';
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
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

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
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _gradeLevelController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final roleValidation = _validateRole(_selectedRole);
    if (roleValidation != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(roleValidation)),
      );
      return;
    }

    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please agree to the terms first.')),
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
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color fblaBlue = const Color(0xFF1D4E89); // Royal Blue
    final Color fblaGold = const Color(0xFFF6C500); // Gold
    final Color appBackground = const Color(0xFF0B1220);
    final Color cardTop = const Color(0xFF13213A);
    final Color cardBottom = const Color(0xFF0F1A2E);
    final Color fieldBackground = const Color(0xFF192743);
    final Color textPrimary = Colors.white;
    final Color textSecondary = Colors.white70;
    final Color infoBackground = const Color(0xFF1A2B47);
    final Color infoBorder = const Color(0xFF335C9A);
    final Color infoText = const Color(0xFFD0E2FF);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: fblaBlue.withOpacity(0.45), width: 1.5),
    );

    return Scaffold(
      backgroundColor: appBackground,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              appBackground,
              fblaBlue.withOpacity(0.25),
              const Color(0xFF081120),
            ],
            stops: const [0.0, 0.4, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Card(
                      elevation: 12,
                      shadowColor: fblaBlue.withOpacity(0.3),
                      color: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              cardTop,
                              cardBottom,
                            ],
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 40),
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              inputDecorationTheme: InputDecorationTheme(
                                labelStyle: TextStyle(color: textSecondary),
                                hintStyle: TextStyle(color: textSecondary),
                              ),
                            ),
                            child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                /// Header with animated icon
                                Column(
                                  children: [
                                    Hero(
                                      tag: 'auth_icon',
                                      child: Container(
                                        width: 90,
                                        height: 90,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: LinearGradient(
                                            colors: [
                                              fblaGold,
                                              fblaGold.withOpacity(0.8)
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: fblaGold.withOpacity(0.4),
                                              blurRadius: 20,
                                              offset: const Offset(0, 10),
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          Icons.person_add_alt_1_rounded,
                                          color: fblaBlue,
                                          size: 45,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    Text(
                                      "Join FBLA",
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: textPrimary,
                                            letterSpacing: -0.5,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      "Create your account and get started",
                                      style: TextStyle(
                                        color: textSecondary,
                                        fontSize: 15,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 36),

                                /// Email field
                                TextFormField(
                                  controller: _nameController,
                                  decoration: InputDecoration(
                                    labelText: 'Full Name',
                                    hintText: 'Your full name',
                                    prefixIcon: Icon(
                                      Icons.person_outline,
                                      color: fblaBlue.withOpacity(0.7),
                                    ),
                                    filled: true,
                                    fillColor: fieldBackground,
                                    border: border,
                                    enabledBorder: border,
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide:
                                          BorderSide(color: fblaBlue, width: 2),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                          color: Colors.red.shade300,
                                          width: 1.5),
                                    ),
                                    focusedErrorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide:
                                          BorderSide(color: Colors.red, width: 2),
                                    ),
                                  ),
                                  textInputAction: TextInputAction.next,
                                  style: TextStyle(color: textPrimary),
                                  cursorColor: fblaGold,
                                  validator: _validateName,
                                ),
                                const SizedBox(height: 20),

                                /// Email field
                                TextFormField(
                                  controller: _emailController,
                                  decoration: InputDecoration(
                                    labelText: 'Email Address',
                                    hintText: 'your.email@example.com',
                                    prefixIcon: Icon(
                                      Icons.email_outlined,
                                      color: fblaBlue.withOpacity(0.7),
                                    ),
                                    filled: true,
                                    fillColor: fieldBackground,
                                    border: border,
                                    enabledBorder: border,
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide:
                                          BorderSide(color: fblaBlue, width: 2),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                          color: Colors.red.shade300,
                                          width: 1.5),
                                    ),
                                    focusedErrorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                          color: Colors.red, width: 2),
                                    ),
                                  ),
                                  keyboardType: TextInputType.emailAddress,
                                  style: TextStyle(color: textPrimary),
                                  cursorColor: fblaGold,
                                  textInputAction: TextInputAction.next,
                                  validator: _validateEmail,
                                  autofillHints: const [
                                    AutofillHints.username,
                                    AutofillHints.email
                                  ],
                                ),
                                const SizedBox(height: 20),

                                /// Signing up as
                                DropdownButtonFormField<String>(
                                  value: _selectedRole,
                                  style: TextStyle(color: textPrimary),
                                  dropdownColor: fieldBackground,
                                  iconEnabledColor: textSecondary,
                                  decoration: InputDecoration(
                                    labelText: 'Signing up as',
                                    prefixIcon: Icon(
                                      Icons.badge_outlined,
                                      color: fblaBlue.withOpacity(0.7),
                                    ),
                                    filled: true,
                                    fillColor: fieldBackground,
                                    border: border,
                                    enabledBorder: border,
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide:
                                          BorderSide(color: fblaBlue, width: 2),
                                    ),
                                  ),
                                  items: _roleOptions
                                      .map(
                                        (role) => DropdownMenuItem<String>(
                                          value: role,
                                          child: Text(
                                            role,
                                            style: TextStyle(color: textPrimary),
                                          ),
                                        ),
                                      )
                                      .toList(growable: false),
                                  onChanged: (value) {
                                    setState(() => _selectedRole = value);
                                  },
                                  validator: _validateRole,
                                ),
                                const SizedBox(height: 20),

                                /// Grade level
                                TextFormField(
                                  controller: _gradeLevelController,
                                  decoration: InputDecoration(
                                    labelText: 'Grade Level',
                                    hintText: '9, 10, 11, 12, College, etc.',
                                    prefixIcon: Icon(
                                      Icons.school_outlined,
                                      color: fblaBlue.withOpacity(0.7),
                                    ),
                                    filled: true,
                                    fillColor: fieldBackground,
                                    border: border,
                                    enabledBorder: border,
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide:
                                          BorderSide(color: fblaBlue, width: 2),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                          color: Colors.red.shade300,
                                          width: 1.5),
                                    ),
                                    focusedErrorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide:
                                          BorderSide(color: Colors.red, width: 2),
                                    ),
                                  ),
                                  textInputAction: TextInputAction.next,
                                  style: TextStyle(color: textPrimary),
                                  cursorColor: fblaGold,
                                  validator: _validateGradeLevel,
                                ),
                                const SizedBox(height: 20),

                                /// Password field
                                TextFormField(
                                  controller: _passwordController,
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    hintText: 'At least 6 characters',
                                    prefixIcon: Icon(
                                      Icons.lock_outline,
                                      color: fblaBlue.withOpacity(0.7),
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscure
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        color: Colors.grey.shade600,
                                      ),
                                      onPressed: () =>
                                          setState(() => _obscure = !_obscure),
                                    ),
                                    filled: true,
                                    fillColor: fieldBackground,
                                    border: border,
                                    enabledBorder: border,
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide:
                                          BorderSide(color: fblaBlue, width: 2),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                          color: Colors.red.shade300,
                                          width: 1.5),
                                    ),
                                    focusedErrorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                          color: Colors.red, width: 2),
                                    ),
                                  ),
                                  obscureText: _obscure,
                                  style: TextStyle(color: textPrimary),
                                  cursorColor: fblaGold,
                                  textInputAction: TextInputAction.next,
                                  validator: _validatePassword,
                                  autofillHints: const [
                                    AutofillHints.newPassword
                                  ],
                                ),
                                const SizedBox(height: 20),

                                /// Confirm Password field
                                TextFormField(
                                  controller: _confirmController,
                                  decoration: InputDecoration(
                                    labelText: 'Confirm Password',
                                    hintText: 'Re-enter your password',
                                    prefixIcon: Icon(
                                      Icons.lock_outline,
                                      color: fblaBlue.withOpacity(0.7),
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscureConfirm
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        color: Colors.grey.shade600,
                                      ),
                                      onPressed: () => setState(() =>
                                          _obscureConfirm = !_obscureConfirm),
                                    ),
                                    filled: true,
                                    fillColor: fieldBackground,
                                    border: border,
                                    enabledBorder: border,
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide:
                                          BorderSide(color: fblaBlue, width: 2),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                          color: Colors.red.shade300,
                                          width: 1.5),
                                    ),
                                    focusedErrorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                          color: Colors.red, width: 2),
                                    ),
                                  ),
                                  obscureText: _obscureConfirm,
                                  style: TextStyle(color: textPrimary),
                                  cursorColor: fblaGold,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _submit(),
                                  validator: _validateConfirm,
                                  autofillHints: const [
                                    AutofillHints.newPassword
                                  ],
                                ),
                                const SizedBox(height: 24),

                                /// Terms and conditions checkbox
                                Row(
                                  children: [
                                    SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: Checkbox(
                                        value: _agreedToTerms,
                                        onChanged: (value) {
                                          setState(() =>
                                              _agreedToTerms = value ?? false);
                                        },
                                        activeColor: fblaBlue,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Wrap(
                                        children: [
                                          Text(
                                            'I agree to the ',
                                            style: TextStyle(
                                              color: textSecondary,
                                              fontSize: 13,
                                            ),
                                          ),
                                          InkWell(
                                            onTap: () {
                                              // TODO: Show terms
                                              return;
                                            },
                                            child: Text(
                                              'Terms & Conditions',
                                              style: TextStyle(
                                                color: fblaBlue,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                decoration:
                                                    TextDecoration.underline,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),

                                /// Create account button with loading state
                                SizedBox(
                                  height: 54,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: fblaBlue,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      elevation: 6,
                                      shadowColor: fblaBlue.withOpacity(0.4),
                                    ),
                                    onPressed: _isLoading ? null : _submit,
                                    child: _isLoading
                                        ? const SizedBox(
                                            height: 24,
                                            width: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      Colors.white),
                                            ),
                                          )
                                        : const Text(
                                            'Create Account',
                                            style: TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 28),

                                /// Already have account? Login
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "Already have an account? ",
                                      style: TextStyle(
                                        color: textSecondary,
                                        fontSize: 15,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                      ),
                                      child: Text(
                                        'Log in',
                                        style: TextStyle(
                                          color: fblaGold,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
