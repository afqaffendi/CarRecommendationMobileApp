import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/database_service.dart';
import 'screens/lifestyle_input_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/image_gallery_screen.dart';
import 'package:car_recommendation_app/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'theme/app_theme.dart';
import 'widgets/animated_title.dart';
import 'widgets/glass_card.dart';
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
    _signInAnonymously(),
    dotenv.load(fileName: ".env"),
    DatabaseService.initializeAsync(),
  ]);

  runApp(const MyApp());

  DatabaseService.refreshCarsFromFirestore();
}

Future<void> _signInAnonymously() async {
  try {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      await auth.signInAnonymously();
    }
  } catch (e) {
    debugPrint('Anonymous auth failed: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Car Recommendation',
      theme: AppTheme.theme,
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.warmBackground,
      body: Stack(
        children: [
          const _WarmBackground(),
          SafeArea(
            child: FadeTransition(
              opacity: _fade,
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
                    _buildFeatureCard(),
                    const Spacer(flex: 2),
                    _buildActions(),
                    const SizedBox(height: 40),
                  ],
                ),
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
              'CarFinder',
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

  Widget _buildFeatureCard() {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      child: Column(
        children: [
          _FeatureRow(
            icon: Icons.psychology_rounded,
            label: 'Natural Language',
            description: 'Describe your needs in plain text',
            animDelay: 1600.ms,
          ),
          Divider(height: 24, color: AppTheme.divider),
          _FeatureRow(
            icon: Icons.tune_rounded,
            label: 'Smart Filtering',
            description: 'Auto-adjust preferences with AI',
            animDelay: 1750.ms,
          ),
          Divider(height: 24, color: AppTheme.divider),
          _FeatureRow(
            icon: Icons.leaderboard_rounded,
            label: 'TOPSIS Ranking',
            description: 'Multi-criteria decision analysis',
            animDelay: 1900.ms,
          ),
        ],
      ),
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
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _OutlineSecondaryButton(
                icon: Icons.favorite_rounded,
                label: 'Favorites',
                onTap: () => Navigator.push(
                  context,
                  AppTheme.slideRoute(const FavoritesScreen()),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _OutlineSecondaryButton(
                icon: Icons.photo_library_rounded,
                label: 'Car Gallery',
                onTap: () => Navigator.push(
                  context,
                  AppTheme.slideRoute(const ImageGalleryScreen()),
                ),
              ),
            ),
          ],
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

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final Duration animDelay;

  const _FeatureRow({
    required this.icon,
    required this.label,
    required this.description,
    required this.animDelay,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppTheme.accentLight,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: Icon(icon, size: 19, color: AppTheme.accent),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded,
            size: 16, color: AppTheme.textSecondary),
      ],
    )
        .animate()
        .fadeIn(delay: animDelay, duration: 400.ms)
        .slideX(
          begin: 0.06,
          end: 0,
          delay: animDelay,
          duration: 400.ms,
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
