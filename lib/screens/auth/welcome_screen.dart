import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../main.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName ?? 'there';
    final firstName = name.split(' ').first;

    return Scaffold(
      backgroundColor: AppTheme.warmBackground,
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  _buildIcon(),
                  const SizedBox(height: 32),
                  _buildText(firstName),
                  const Spacer(flex: 3),
                  _buildButton(context),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Stack(
      children: [
        Positioned(
          bottom: -60,
          right: -80,
          child: Container(
            width: 340,
            height: 340,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppTheme.accent.withValues(alpha: 0.30),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 60,
          left: -90,
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppTheme.accentBlue.withValues(alpha: 0.20),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIcon() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: AppTheme.accent,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accent.withValues(alpha: 0.40),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: const Icon(Icons.check_rounded, size: 52, color: Colors.white),
    )
        .animate()
        .scale(
          begin: const Offset(0.4, 0.4),
          end: const Offset(1, 1),
          duration: 600.ms,
          curve: Curves.elasticOut,
        )
        .fadeIn(duration: 300.ms);
  }

  Widget _buildText(String firstName) {
    return Column(
      children: [
        Text(
          'Welcome, $firstName!',
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w300,
            color: AppTheme.textPrimary,
            letterSpacing: -1.5,
            height: 1.1,
          ),
          textAlign: TextAlign.center,
        )
            .animate()
            .fadeIn(delay: 300.ms, duration: 500.ms)
            .slideY(begin: 0.15, end: 0, delay: 300.ms, duration: 500.ms),
        const SizedBox(height: 14),
        const Text(
          'Your account has been created.\nStart finding your perfect car.',
          style: TextStyle(
            fontSize: 16,
            color: AppTheme.textSecondary,
            height: 1.6,
          ),
          textAlign: TextAlign.center,
        )
            .animate()
            .fadeIn(delay: 500.ms, duration: 500.ms)
            .slideY(begin: 0.15, end: 0, delay: 500.ms, duration: 500.ms),
      ],
    );
  }

  Widget _buildButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () => Navigator.of(context).pushAndRemoveUntil(
          AppTheme.slideRoute(const HomeScreen()),
          (route) => false,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Get Started', style: TextStyle(fontSize: 16)),
            SizedBox(width: 10),
            Icon(Icons.arrow_forward_rounded, size: 18),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(delay: 700.ms, duration: 400.ms)
        .slideY(begin: 0.2, end: 0, delay: 700.ms, duration: 400.ms);
  }
}
