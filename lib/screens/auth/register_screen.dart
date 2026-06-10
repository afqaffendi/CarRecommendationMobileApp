import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import 'login_screen.dart';
import 'welcome_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await AuthService.registerWithEmail(
          _emailCtrl.text, _passwordCtrl.text, _nameCtrl.text);
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          AppTheme.slideRoute(const WelcomeScreen()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Registration failed');
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
                _buildBack(),
                const SizedBox(height: 32),
                _buildHeadline(),
                const SizedBox(height: 36),
                _buildNameField(),
                const SizedBox(height: 14),
                _buildEmailField(),
                const SizedBox(height: 14),
                _buildPasswordField(),
                const SizedBox(height: 14),
                _buildConfirmField(),
                const SizedBox(height: 28),
                _buildRegisterButton(),
                const SizedBox(height: 32),
                _buildLoginLink(),
              ]
                  .animate(interval: 60.ms)
                  .fadeIn(duration: 400.ms)
                  .slideY(
                      begin: 0.12,
                      end: 0,
                      duration: 400.ms,
                      curve: Curves.easeOut),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBack() {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.warmSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: const Icon(Icons.arrow_back_rounded,
            size: 18, color: AppTheme.textPrimary),
      ),
    );
  }

  Widget _buildHeadline() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text('Create account.',
            style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w300,
                color: AppTheme.textPrimary,
                height: 1.1,
                letterSpacing: -1.5)),
        SizedBox(height: 8),
        Text('Join AutoPilih to save your recommendations',
            style: TextStyle(
                fontSize: 15,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w400)),
      ],
    );
  }

  Widget _buildNameField() {
    return _InputField(
      controller: _nameCtrl,
      label: 'Full Name',
      validator: (v) =>
          v == null || v.trim().isEmpty ? 'Enter your name' : null,
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
      obscure: _obscurePass,
      suffixIcon: IconButton(
        icon: Icon(
            _obscurePass
                ? Icons.visibility_off_rounded
                : Icons.visibility_rounded,
            size: 20,
            color: AppTheme.textSecondary),
        onPressed: () => setState(() => _obscurePass = !_obscurePass),
      ),
      validator: (v) =>
          v == null || v.length < 6 ? 'Minimum 6 characters' : null,
    );
  }

  Widget _buildConfirmField() {
    return _InputField(
      controller: _confirmCtrl,
      label: 'Confirm Password',
      obscure: _obscureConfirm,
      suffixIcon: IconButton(
        icon: Icon(
            _obscureConfirm
                ? Icons.visibility_off_rounded
                : Icons.visibility_rounded,
            size: 20,
            color: AppTheme.textSecondary),
        onPressed: () =>
            setState(() => _obscureConfirm = !_obscureConfirm),
      ),
      validator: (v) =>
          v != _passwordCtrl.text ? 'Passwords do not match' : null,
    );
  }

  Widget _buildRegisterButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _loading ? null : _register,
        child: _loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Text('Create Account',
                style: TextStyle(fontSize: 16)),
      ),
    );
  }

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Already have an account? ',
            style:
                TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
        GestureDetector(
          onTap: () => Navigator.pushReplacement(
              context, AppTheme.slideRoute(const LoginScreen())),
          child: const Text('Sign In',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.accent)),
        ),
      ],
    );
  }
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
        labelStyle:
            const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
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
