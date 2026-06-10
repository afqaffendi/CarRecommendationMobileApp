import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await AuthService.signInWithEmail(_emailCtrl.text, _passwordCtrl.text);
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Sign-in failed');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _googleSignIn() async {
    setState(() => _loading = true);
    try {
      await AuthService.signInWithGoogle();
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Google sign-in failed');
    } catch (_) {
      _showError('Google sign-in cancelled');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.warmBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBrand(),
                const SizedBox(height: 48),
                _buildHeadline(),
                const SizedBox(height: 36),
                _buildEmailField(),
                const SizedBox(height: 14),
                _buildPasswordField(),
                const SizedBox(height: 28),
                _buildSignInButton(),
                const SizedBox(height: 16),
                _buildDivider(),
                const SizedBox(height: 16),
                _buildGoogleButton(),
                const SizedBox(height: 32),
                _buildRegisterLink(),
              ]
                  .animate(interval: 60.ms)
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.12, end: 0, duration: 400.ms, curve: Curves.easeOut),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrand() {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.textPrimary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.directions_car_rounded,
              size: 20, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('AutoPilih',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.3)),
            Text('MALAYSIA',
                style: TextStyle(
                    fontSize: 9,
                    color: AppTheme.textSecondary,
                    letterSpacing: 2.0,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ],
    );
  }

  Widget _buildHeadline() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text('Welcome back.',
            style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w300,
                color: AppTheme.textPrimary,
                height: 1.1,
                letterSpacing: -1.5)),
        SizedBox(height: 8),
        Text('Sign in to your account',
            style: TextStyle(
                fontSize: 15,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w400)),
      ],
    );
  }

  Widget _buildEmailField() {
    return _InputField(
      controller: _emailCtrl,
      label: 'Email',
      keyboardType: TextInputType.emailAddress,
      validator: (v) =>
          v == null || !v.contains('@') ? 'Enter a valid email' : null,
    );
  }

  Widget _buildPasswordField() {
    return _InputField(
      controller: _passwordCtrl,
      label: 'Password',
      obscure: _obscure,
      suffixIcon: IconButton(
        icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            size: 20, color: AppTheme.textSecondary),
        onPressed: () => setState(() => _obscure = !_obscure),
      ),
      validator: (v) =>
          v == null || v.length < 6 ? 'Minimum 6 characters' : null,
    );
  }

  Widget _buildSignInButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _loading ? null : _signIn,
        child: _loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Text('Sign In', style: TextStyle(fontSize: 16)),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppTheme.cardBorder)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('or',
              style: TextStyle(
                  fontSize: 13, color: AppTheme.textSecondary)),
        ),
        const Expanded(child: Divider(color: AppTheme.cardBorder)),
      ],
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton.icon(
        onPressed: _loading ? null : _googleSignIn,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppTheme.cardBorder),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
          backgroundColor: AppTheme.warmSurface,
        ),
        icon: _GoogleLogo(),
        label: const Text('Continue with Google',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary)),
      ),
    );
  }

  Widget _buildRegisterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("Don't have an account? ",
            style:
                TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
        GestureDetector(
          onTap: () => Navigator.push(
              context, AppTheme.slideRoute(const RegisterScreen())),
          child: const Text('Register',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.accent)),
        ),
      ],
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        -1.57, 3.14, true, paint);

    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        -1.57, -3.14, true, paint);

    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        1.57, 1.57, true, paint);

    paint.color = const Color(0xFF34A853);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        0, 1.57, true, paint);

    paint.color = Colors.white;
    canvas.drawCircle(center, radius * 0.6, paint);

    paint.color = const Color(0xFF4285F4);
    final rect = Rect.fromLTRB(
        center.dx, center.dy - radius * 0.15,
        center.dx + radius, center.dy + radius * 0.15);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;

  const _InputField({
    required this.controller,
    required this.label,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(
          fontSize: 15,
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w400),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
            color: AppTheme.textSecondary, fontSize: 14),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppTheme.warmSurface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppTheme.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppTheme.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              const BorderSide(color: AppTheme.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
      ),
    );
  }
}
