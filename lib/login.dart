import 'package:developer_community_app/services/analytics_service.dart';
import 'package:developer_community_app/signup.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'utils/app_snackbar.dart';
import 'utils/app_validators.dart';
import 'widgets/app_dialogs.dart';

class login extends StatefulWidget {
  const login({super.key});

  @override
  State<login> createState() => _loginState();
}

class _loginState extends State<login> with SingleTickerProviderStateMixin {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _isSubmitted = false;
  final _formKey = GlobalKey<FormState>();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  Future<void> _storeFreshFcmToken(User user) async {
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return;
      }

      final token = await messaging.getToken();
      if (token == null || token.trim().isEmpty) {
        return;
      }

      await FirebaseFirestore.instance.collection('User').doc(user.uid).set({
        'fcmToken': token,
        'fcmTokens': FieldValue.arrayUnion([token]),
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Failed to store FCM token after login: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeOut));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> userLogin() async {
    setState(() => _isSubmitted = true);
    if (!_formKey.currentState!.validate()) {
      AppSnackbar.error('Please fix the errors in the form.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      final user = credential.user;
      if (user != null) {
        await _storeFreshFcmToken(user);
      }

      await AnalyticsService().logLogin(method: 'email');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-credential' ||
          e.code == 'wrong-password' ||
          e.code == 'user-not-found') {
        await AppDialogs.showError(
          context,
          title: 'Login Failed',
          message: 'Incorrect email or password. Please try again.',
        );
      } else if (e.code == 'too-many-requests') {
        await AppDialogs.showError(
          context,
          title: 'Too Many Attempts',
          message: 'Please wait a moment before trying to sign in again.',
        );
      } else {
        await AppDialogs.showError(
          context,
          title: 'Error',
          message: e.message ?? e.code,
        );
      }
    } catch (e) {
      await AppDialogs.showError(
        context,
        title: 'Error',
        message: 'An unexpected error occurred. Please try again.',
      );
      debugPrint("Login error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> forgetPassword() async {
    setState(() => _isSubmitted = true);
    if (emailController.text.isEmpty) {
      AppSnackbar.error('Please enter your email first', title: 'Error');
      return;
    }

    try {
      await FirebaseAuth.instance
          .sendPasswordResetEmail(email: emailController.text.trim());
      AppSnackbar.success('Password reset email sent!', title: 'Success');
    } on FirebaseAuthException catch (e) {
      AppSnackbar.error(e.code, title: 'Error');
    } catch (e) {
      debugPrint("Reset password error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        height: size.height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.8),
              theme.colorScheme.primary.withValues(alpha: 0.4),
              theme.colorScheme.surface,
            ],
            stops: const [0.0, 0.4, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: size.height * 0.06),
                      // Header Section
                      _buildHeader(),
                      SizedBox(height: size.height * 0.04),
                      // Form Card
                      _buildFormCard(theme),
                      const SizedBox(height: 24),
                      // Sign up link
                      _buildSignUpLink(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.code_rounded,
            size: 48,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          'Welcome\nBack! 👋',
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Sign in to continue your developer journey',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Email Field
            _buildInputField(
              controller: emailController,
              label: 'Email Address',
              hint: 'Enter your email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: AppValidators.validateEmail,
            ),
            const SizedBox(height: 20),
            // Password Field
            _buildInputField(
              controller: passwordController,
              label: 'Password',
              hint: 'Enter your password',
              icon: Icons.lock_outline,
              isPassword: true,
              validator: AppValidators.validatePassword,
            ),
            const SizedBox(height: 12),
            // Forgot Password
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: forgetPassword,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Forgot Password?',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            // Login Button
            _buildLoginButton(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: isPassword && !_isPasswordVisible,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 16),
          validator: (val) =>
              _isSubmitted && validator != null ? validator(val) : null,
          autovalidateMode: AutovalidateMode.disabled,
          onTap: () {
            if (_isSubmitted) {
              setState(() => _isSubmitted = false);
              _formKey.currentState?.validate();
            }
          },
          onChanged: (val) {
            if (_isSubmitted) {
              setState(() => _isSubmitted = false);
              _formKey.currentState?.validate();
            }
          },
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey.withValues(alpha: 0.08),
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.grey.withValues(alpha: 0.6),
              fontSize: 15,
            ),
            prefixIcon: Icon(
              icon,
              color: Colors.grey.withValues(alpha: 0.6),
              size: 22,
            ),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: Colors.grey.withValues(alpha: 0.6),
                      size: 22,
                    ),
                    onPressed: () {
                      setState(() => _isPasswordVisible = !_isPasswordVisible);
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.error, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.error, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton(ThemeData theme) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : userLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Sign In',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 20),
                ],
              ),
      ),
    );
  }

  Widget _buildSignUpLink() {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Don't have an account? ",
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 15,
            ),
          ),
          GestureDetector(
            onTap: () => Get.to(() => const signup()),
            child: const Text(
              'Sign Up',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
