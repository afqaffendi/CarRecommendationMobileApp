import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/lifestyle_parser_service.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_title.dart';
import '../widgets/glass_card.dart';
import '../widgets/pressable_button.dart';
import 'preference_sliders_screen.dart';

class LifestyleInputScreen extends StatefulWidget {
  const LifestyleInputScreen({super.key});

  @override
  State<LifestyleInputScreen> createState() => _LifestyleInputScreenState();
}

class _LifestyleInputScreenState extends State<LifestyleInputScreen> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  final _parserService = LifestyleParserService();

  bool _isParsing = false;
  ParsedLifestyle? _parsedResult;

  final List<String> _examplePrompts = [
    "nak kereta murah untuk kerja KL",
    "family car, safety penting, balik kampung selalu",
    "first car fresh grad, jimat minyak",
    "SUV bawah 120k untuk family",
    "EV under 200k, city driving",
  ];

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _parseInput() async {
    final input = _textController.text.trim();
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please type something first')),
      );
      return;
    }

    _focusNode.unfocus();
    setState(() {
      _isParsing = true;
      _parsedResult = null;
    });

    await DatabaseService.addSearchHistory(input);
    final result = await _parserService.parseLifestyleInput(input);

    setState(() {
      _isParsing = false;
      _parsedResult = result;
    });
  }

  void _useExample(String example) {
    _textController.text = example;
    _parseInput();
  }

  void _proceedWithPreferences() {
    if (_parsedResult == null) return;
    final prefs = _parserService.toUserPreferences(_parsedResult!);
    prefs.originalInput = _textController.text.trim();
    DatabaseService.savePreferences(prefs);
    Navigator.push(
      context,
      AppTheme.slideRoute(PreferenceSlidersScreen(preferences: prefs)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.warmBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          _buildBackground(),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedTitle(
                  text: 'What car\ndo you need?',
                  charDelayMs: 38,
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    height: 1.1,
                    letterSpacing: -1.2,
                  ),
                ),
                const SizedBox(height: 10),
                AnimatedFadeSlide(
                  delay: const Duration(milliseconds: 1050),
                  child: const Text(
                    'Type in English, Malay, or mix — our AI understands you.',
                    style: TextStyle(
                      fontSize: 15,
                      color: AppTheme.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Input glass card
                GlassCard(
                  padding: EdgeInsets.zero,
                  blur: false,
                  child: Column(
                    children: [
                      TextField(
                        controller: _textController,
                        focusNode: _focusNode,
                        maxLines: 4,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.5,
                          color: AppTheme.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              'e.g. "nak kereta jimat minyak untuk kerja" or "SUV below 100k for family"...',
                          hintStyle: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.fromLTRB(20, 20, 20, 12),
                        ),
                        onChanged: (_) {
                          if (_parsedResult != null) {
                            setState(() => _parsedResult = null);
                          }
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: SizedBox(
                          width: double.infinity,
                          child: PressableButton(
                            glass: true,
                            borderRadius: BorderRadius.circular(14),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            onPressed: _isParsing ? null : _parseInput,
                            child: _isParsing
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 17,
                                        height: 17,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  AppTheme.accent),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Analyzing...',
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: AppTheme.textPrimary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.auto_awesome_rounded,
                                          size: 17, color: AppTheme.accent),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Analyze My Needs',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (_parsedResult != null) ...[
                  const SizedBox(height: 24),
                  _buildParsedResultsCard(),
                ],

                const SizedBox(height: 32),
                const Text(
                  'Try an example',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _examplePrompts
                        .map((e) => _buildExampleChip(e))
                        .toList(),
                  ),
                ),
              ],
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
          bottom: -80,
          right: -60,
          child: Container(
            width: 280,
            height: 280,
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
          left: -60,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppTheme.accentBlue.withValues(alpha: 0.25),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildParsedResultsCard() {
    final result = _parsedResult!;

    return GlassCard(
      blur: false,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.accent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Analysis Complete',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              _buildConfidenceBadge(result.confidence),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            result.summary,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 20),
          const Divider(height: 1, color: AppTheme.cardBorder),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: _buildInfoTile(
                  Icons.account_balance_wallet_rounded,
                  'Budget',
                  result.hasBudgetConstraint
                      ? 'RM ${_formatNumber(result.budget)}'
                      : 'Open',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildInfoTile(
                  Icons.route_rounded,
                  'Usage',
                  _formatUsageType(result.usageType),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildInfoTile(
                  Icons.directions_car_rounded,
                  'Type',
                  _formatCarType(result.carType),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildInfoTile(
                  Icons.local_gas_station_rounded,
                  'Fuel',
                  _formatFuelType(result.fuelType),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          const Text(
            'Priority Weights',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _buildPriorityBar('Price', result.priceImportance),
          _buildPriorityBar('Fuel Economy', result.fuelImportance),
          _buildPriorityBar('Safety', result.safetyImportance),

          if (result.detectedNeeds.isNotEmpty) ...[
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: result.detectedNeeds
                  .map((need) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.accentLight,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          need,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.accent,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ],

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: PressableButton(
              glass: true,
              borderRadius: BorderRadius.circular(16),
              padding: const EdgeInsets.symmetric(vertical: 16),
              onPressed: _proceedWithPreferences,
              child: Text(
                'Continue with these preferences',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () {
                final prefs = _parserService.toUserPreferences(result);
                prefs.originalInput = _textController.text.trim();
                Navigator.push(
                  context,
                  AppTheme.slideRoute(
                      PreferenceSlidersScreen(preferences: prefs)),
                );
              },
              child: const Text(
                'Adjust preferences manually',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.accentLight.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityBar(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style:
                  const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 6,
                backgroundColor: AppTheme.accentLight.withValues(alpha: 0.5),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppTheme.accent),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 32,
            child: Text(
              '${(value * 100).toInt()}%',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExampleChip(String example) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: () => _useExample(example),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.14), width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.20),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.north_west_rounded,
                  size: 11, color: AppTheme.accent),
              const SizedBox(width: 6),
              Text(
                example,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfidenceBadge(String confidence) {
    Color bg;
    Color textColor;
    String label;
    switch (confidence) {
      case 'high':
        bg = AppTheme.accent;           // coral bg — stands out
        textColor = Colors.white;
        label = 'High';
        break;
      case 'low':
        bg = const Color(0xFF3A3A3A);   // dark gray — clearly distinct from bg
        textColor = AppTheme.textSecondary;
        label = 'Low';
        break;
      default:
        bg = AppTheme.accentBlue;       // purple bg — stands out, distinct from accent
        textColor = Colors.white;
        label = 'Good';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatNumber(double v) {
    if (v >= 1000) {
      final thousands = (v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1);
      return '${thousands}k';
    }
    return v.toStringAsFixed(0);
  }

  String _formatUsageType(String type) {
    switch (type) {
      case 'city':
        return 'City';
      case 'highway':
        return 'Highway';
      case 'both':
        return 'Mixed';
      default:
        return type;
    }
  }

  String _formatCarType(String type) {
    switch (type) {
      case 'any':
        return 'Any';
      case 'sedan':
        return 'Sedan';
      case 'suv':
        return 'SUV';
      case 'mpv':
        return 'MPV';
      case 'hatchback':
        return 'Hatchback';
      case 'truck':
        return 'Truck';
      case 'van':
        return 'Van';
      default:
        return type;
    }
  }

  String _formatFuelType(String type) {
    switch (type) {
      case 'any':
        return 'Any';
      case 'petrol':
        return 'Petrol';
      case 'ev':
        return 'Electric';
      case 'hybrid':
        return 'Hybrid';
      default:
        return type;
    }
  }
}
