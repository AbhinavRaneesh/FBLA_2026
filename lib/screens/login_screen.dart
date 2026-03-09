import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart';
import '../services/firebase_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

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
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final app = Provider.of<AppState>(context, listen: false);
      await app.signInWithMongo(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
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
          );
        }

        if (!mounted) return;
        final app = Provider.of<AppState>(context, listen: false);
        await app.setFirebaseUser(user);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google sign-in was cancelled.')),
        );
      }
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

  Future<void> _signInWithInstagram() async {
    const instagramLogin = 'https://www.instagram.com/accounts/login/';
    final uri = Uri.parse(instagramLogin);

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          opened
              ? 'Instagram opened. Complete sign-in after OAuth is configured.'
              : 'Could not open Instagram sign-in.',
        ),
      ),
    );
  }

  Widget _buildSocialLogoBadge({
    required String logoUrl,
    required IconData fallbackIcon,
    required Color fallbackColor,
  }) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(7),
      child: Image.network(
        logoUrl,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(
          fallbackIcon,
          color: fallbackColor,
          size: 18,
        ),
      ),
    );
  }

  Widget _buildBrandedSignInButton({
    required VoidCallback? onPressed,
    required String label,
    required List<Color> borderGradient,
    required Widget logo,
  }) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: borderGradient),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(1.2),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF111A2E),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(15),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  logo,
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: Colors.white.withOpacity(0.72),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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
                                              fblaBlue,
                                              fblaBlue.withOpacity(0.8)
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: fblaBlue.withOpacity(0.3),
                                              blurRadius: 20,
                                              offset: const Offset(0, 10),
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          Icons.business_center_rounded,
                                          color: fblaGold,
                                          size: 45,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    Text(
                                      "Welcome Back",
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
                                      "Log in to continue your FBLA journey",
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
                                    AutofillHints.email,
                                  ],
                                ),
                                const SizedBox(height: 20),

                                /// Password field
                                TextFormField(
                                  controller: _passwordController,
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    hintText: 'Enter your password',
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
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _submit(),
                                  validator: _validatePassword,
                                  autofillHints: const [AutofillHints.password],
                                ),

                                /// Forgot password link
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () {
                                      return;
                                    },
                                    child: Text(
                                      'Forgot Password?',
                                      style: TextStyle(
                                        color: textSecondary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                /// Login button with loading state
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
                                            'Log in',
                                            style: TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                SizedBox(
                                  height: 52,
                                  child: OutlinedButton.icon(
                                    onPressed:
                                        _isLoading ? null : _signInDeveloperMode,
                                    icon: const Icon(Icons.developer_mode),
                                    label: const Text(
                                      'Developer Mode',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: fblaGold,
                                      side: BorderSide(
                                        color: fblaGold.withOpacity(0.7),
                                        width: 1.3,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 20),

                                Row(
                                  children: [
                                    Expanded(
                                      child: Divider(
                                        color: textSecondary.withOpacity(0.35),
                                        thickness: 1,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      child: Text(
                                        'or continue with',
                                        style: TextStyle(
                                          color: textSecondary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Divider(
                                        color: textSecondary.withOpacity(0.35),
                                        thickness: 1,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 14),

                                _buildBrandedSignInButton(
                                  onPressed: _isLoading ? null : _signInWithGoogle,
                                  label: 'Sign in with Google',
                                  borderGradient: const [
                                    Color(0xFF4285F4),
                                    Color(0xFF34A853),
                                    Color(0xFFFBBC05),
                                    Color(0xFFEA4335),
                                  ],
                                  logo: _buildSocialLogoBadge(
                                    logoUrl:
                                        'https://img.icons8.com/color/48/google-logo.png',
                                    fallbackIcon: Icons.g_mobiledata_rounded,
                                    fallbackColor: const Color(0xFF4285F4),
                                  ),
                                ),

                                const SizedBox(height: 10),

                                _buildBrandedSignInButton(
                                  onPressed:
                                      _isLoading ? null : _signInWithInstagram,
                                  label: 'Sign in with Instagram',
                                  borderGradient: const [
                                    Color(0xFF833AB4),
                                    Color(0xFFE1306C),
                                    Color(0xFFF56040),
                                    Color(0xFFFCAF45),
                                  ],
                                  logo: _buildSocialLogoBadge(
                                    logoUrl:
                                        'https://img.icons8.com/fluency/48/instagram-new.png',
                                    fallbackIcon: Icons.camera_alt_outlined,
                                    fallbackColor: const Color(0xFFE1306C),
                                  ),
                                ),

                                const SizedBox(height: 24),

                                const SizedBox(height: 28),

                                /// Signup prompt
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "Don't have an account? ",
                                      style: TextStyle(
                                        color: textSecondary,
                                        fontSize: 15,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pushNamed(
                                          context, '/signup'),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                      ),
                                      child: Text(
                                        'Sign up',
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
