import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/database_service.dart';
import 'screens/lifestyle_input_screen.dart';
import 'screens/auth/auth_gate.dart';
import 'screens/profile_screen.dart';
import 'package:car_recommendation_app/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'theme/app_theme.dart';
import 'widgets/animated_title.dart';
import 'widgets/pressable_button.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  await Hive.initFlutter();

  await Future.wait([
    dotenv.load(fileName: ".env"),
    DatabaseService.initializeAsync(),
  ]);

  runApp(const MyApp());

  DatabaseService.refreshCarsFromFirestore();
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Car Recommendation',
      theme: AppTheme.theme,
      home: const AuthGate(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.warmBackground,
      body: Stack(
        children: [
          const _WarmBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  _buildBrand(),
                  const Spacer(flex: 1),
                  _buildHero(),
                  const SizedBox(height: 32),
                  _buildFeatureBubbles(),
                  const Spacer(flex: 2),
                  _buildActions(),
                  const SizedBox(height: 40),
                ],
              )
                  .animate()
                  .fadeIn(duration: 700.ms, curve: Curves.easeOut)
                  .blur(
                    begin: const Offset(20, 20),
                    end: Offset.zero,
                    duration: 700.ms,
                    curve: Curves.easeOut,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrand() {
    return Row(
      children: [
        // Logo mark
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.textPrimary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.directions_car_rounded,
            size: 20,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'AutoPilih',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              'MALAYSIA',
              style: TextStyle(
                fontSize: 9,
                color: AppTheme.textSecondary,
                letterSpacing: 2.0,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: AppTheme.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(100),
          ),
          child: const Text(
            'AI Powered',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.accent,
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            AppTheme.slideRoute(const ProfileScreen()),
          ),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.warmSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: const Icon(
              Icons.person_rounded,
              size: 18,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHero() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Editorial-style title: thin weight large display text
        AnimatedTitle(
          text: 'Find your\nperfect car.',
          delay: const Duration(milliseconds: 300),
          charDelayMs: 38,
          style: const TextStyle(
            fontSize: 46,
            fontWeight: FontWeight.w300,
            color: AppTheme.textPrimary,
            height: 1.08,
            letterSpacing: -2.0,
          ),
        ),
        const SizedBox(height: 18),
        AnimatedFadeSlide(
          delay: const Duration(milliseconds: 1400),
          child: const Text(
            'AI-powered recommendations\ntailored for Malaysian buyers.',
            style: TextStyle(
              fontSize: 15,
              color: AppTheme.textSecondary,
              height: 1.65,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureBubbles() {
    return Row(
      children: [
        Expanded(
          child: _BubbleCard(
            icon: Icons.psychology_rounded,
            label: 'Natural\nLanguage',
            description: 'Describe in plain text',
            color: AppTheme.accent,
            animDelay: 1600.ms,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _BubbleCard(
            icon: Icons.tune_rounded,
            label: 'Smart\nFiltering',
            description: 'AI-adjusted preferences',
            color: AppTheme.accentBlue,
            animDelay: 1750.ms,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _BubbleCard(
            icon: Icons.leaderboard_rounded,
            label: 'TOPSIS\nRanking',
            description: 'Multi-criteria analysis',
            color: const Color(0xFF7C6AF7),
            animDelay: 1900.ms,
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Column(
      children: [
        // Primary dark pill CTA
        SizedBox(
          width: double.infinity,
          child: PressableButton(
            glass: true,
            borderRadius: BorderRadius.circular(100),
            padding: const EdgeInsets.symmetric(vertical: 18),
            onPressed: () => Navigator.push(
              context,
              AppTheme.slideRoute(const LifestyleInputScreen()),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Find My Car',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Warm animated background — large orange blob like the reference image
class _WarmBackground extends StatefulWidget {
  const _WarmBackground();

  @override
  State<_WarmBackground> createState() => _WarmBackgroundState();
}

class _WarmBackgroundState extends State<_WarmBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    )..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Positioned.fill(
        child: Stack(
          children: [
            // Large warm orange blob — the hero visual (like the reference image)
            Positioned(
              bottom: -60,
              right: -80,
              child: Container(
                width: 380,
                height: 380,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.accent
                          .withValues(alpha: 0.30 + _pulse.value * 0.12),
                      AppTheme.accent.withValues(alpha: 0.10 + _pulse.value * 0.05),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
            // Smaller warm amber blob — top left (secondary)
            Positioned(
              top: 60,
              left: -90,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.accentBlue
                          .withValues(alpha: 0.18 + (1 - _pulse.value) * 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Very subtle top-right warmth
            Positioned(
              top: -40,
              right: 40,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.accent
                          .withValues(alpha: 0.08 + _pulse.value * 0.04),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BubbleCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final Duration animDelay;

  const _BubbleCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.animDelay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 21, color: color),
          ),
          const SizedBox(height: 14),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              height: 1.3,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            description,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: animDelay, duration: 500.ms)
        .blur(
          begin: const Offset(10, 10),
          end: Offset.zero,
          delay: animDelay,
          duration: 500.ms,
          curve: Curves.easeOut,
        )
        .slideY(
          begin: 0.15,
          end: 0,
          delay: animDelay,
          duration: 500.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

// Outline secondary button (white with border)
class _OutlineSecondaryButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _OutlineSecondaryButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_OutlineSecondaryButton> createState() =>
      _OutlineSecondaryButtonState();
}

class _OutlineSecondaryButtonState extends State<_OutlineSecondaryButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 220),
      vsync: this,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.warmSurface,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: AppTheme.cardBorder),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B7355).withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
