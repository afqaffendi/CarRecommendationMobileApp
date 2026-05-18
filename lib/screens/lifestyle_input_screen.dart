import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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

  // Manual mode state
  bool _isManualMode = false;
  bool _offlineDetected = false;
  int _manualBudgetIndex = 1;
  String _manualCarType = 'any';
  String _manualFuelType = 'any';
  String _manualUsageType = 'both';
  final Set<String> _manualPriorities = {'price'};

  static const _budgetLabels = [
    'Under RM50k',
    'RM50k–80k',
    'RM80k–120k',
    'RM120k–200k',
    'Over RM200k',
  ];
  static const _budgetValues = [45000.0, 65000.0, 100000.0, 160000.0, 280000.0];
  static const _budgetConstrained = [true, true, true, true, false];

  final List<String> _examplePrompts = [
    'nak kereta murah untuk kerja KL',
    'family car, safety penting, balik kampung selalu',
    'first car fresh grad, jimat minyak',
    'SUV bawah 120k untuk family',
    'EV under 200k, city driving',
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

    if (!mounted) return;

    if (result.isOffline) {
      setState(() {
        _isParsing = false;
        _offlineDetected = true;
        _isManualMode = true;
        _parsedResult = null;
      });
    } else {
      setState(() {
        _isParsing = false;
        _parsedResult = result;
        _offlineDetected = false;
      });
    }
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

  void _proceedManually() {
    final budget = _budgetValues[_manualBudgetIndex];
    final hasBudget = _budgetConstrained[_manualBudgetIndex];

    final parsed = ParsedLifestyle(
      budget: budget,
      hasBudgetConstraint: hasBudget,
      usageType: _manualUsageType,
      carType: _manualCarType,
      fuelType: _manualFuelType,
      preferredBrand: '',
      preferredModel: '',
      showAll: false,
      priceImportance: _manualPriorities.contains('price') ? 0.85 : 0.3,
      fuelImportance: _manualPriorities.contains('fuel') ? 0.85 : 0.3,
      safetyImportance: _manualPriorities.contains('safety') ? 0.85 : 0.3,
      detectedNeeds: [
        '${_formatBudgetLabel(_manualBudgetIndex)} budget',
        _formatCarTypeLabel(_manualCarType),
        _formatFuelLabel(_manualFuelType),
        ..._manualPriorities.map((p) => '${_formatPriorityLabel(p)} priority'),
      ],
      summary:
          'Looking for a ${_formatCarTypeLabel(_manualCarType).toLowerCase()} car'
          ' with ${_budgetLabels[_manualBudgetIndex]} budget.',
      confidence: 'high',
      rawInput: '[Manual selection]',
      isOffline: false,
    );

    final prefs = _parserService.toUserPreferences(parsed);
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
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
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
                  child: Text(
                    _isManualMode
                        ? 'Pick your preferences manually.'
                        : 'Type in English, Malay, or mix — our AI understands you.',
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppTheme.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 22),

                // Mode toggle
                _buildModeToggle()
                    .animate()
                    .fadeIn(delay: 1200.ms, duration: 350.ms),

                const SizedBox(height: 18),

                // Offline banner
                if (_offlineDetected) ...[
                  _buildOfflineBanner()
                      .animate()
                      .fadeIn(duration: 300.ms)
                      .slideY(begin: -0.1, end: 0, duration: 300.ms),
                  const SizedBox(height: 14),
                ],

                // Content
                if (_isManualMode)
                  _buildManualSpecPicker()
                      .animate()
                      .fadeIn(duration: 350.ms)
                      .slideY(
                          begin: 0.06,
                          end: 0,
                          duration: 350.ms,
                          curve: Curves.easeOutCubic)
                else ...[
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
                          decoration: const InputDecoration(
                            hintText:
                                'e.g. "nak kereta jimat minyak untuk kerja" or "SUV below 100k for family"...',
                            hintStyle: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding:
                                EdgeInsets.fromLTRB(20, 20, 20, 12),
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
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              onPressed: _isParsing ? null : _parseInput,
                              child: _isParsing
                                  ? Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
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
                                        const Text(
                                          'Analyzing...',
                                          style: TextStyle(
                                            fontSize: 15,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    )
                                  : const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.auto_awesome_rounded,
                                            size: 17, color: Colors.white70),
                                        SizedBox(width: 8),
                                        Text(
                                          'Analyze My Needs',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
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
                    if (_parsedResult!.confidence == 'low')
                      _buildLowConfidenceBanner()
                          .animate()
                          .fadeIn(duration: 300.ms)
                          .slideY(begin: -0.08, end: 0, duration: 300.ms),
                    if (_parsedResult!.confidence == 'low')
                      const SizedBox(height: 12),
                    _buildParsedResultsCard()
                        .animate()
                        .fadeIn(duration: 400.ms)
                        .slideY(
                            begin: 0.08,
                            end: 0,
                            duration: 400.ms,
                            curve: Curves.easeOutCubic),
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
                          .asMap()
                          .entries
                          .map((e) => _buildExampleChip(e.value, e.key))
                          .toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeToggle() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppTheme.warmSurface,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          _modeTab(
            Icons.auto_awesome_rounded,
            'AI Input',
            !_isManualMode,
            () => setState(() {
              _isManualMode = false;
              _offlineDetected = false;
            }),
          ),
          _modeTab(
            Icons.tune_rounded,
            'Manual Pick',
            _isManualMode,
            () => setState(() => _isManualMode = true),
          ),
        ],
      ),
    );
  }

  Widget _modeTab(
      IconData icon, String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppTheme.textPrimary : Colors.transparent,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 15,
                  color: active ? Colors.white : AppTheme.textSecondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLowConfidenceBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFCA28).withValues(alpha: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.help_outline_rounded, size: 18, color: Color(0xFFF57F17)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'We couldn\'t fully understand your needs',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFE65100),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Try describing your lifestyle — e.g. budget, family size, how you drive. Or use Manual Pick for faster setup.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFFBF360C),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => setState(() => _isManualMode = true),
                  child: const Text(
                    'Switch to Manual Pick →',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFE65100),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFB74D).withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, size: 16, color: Color(0xFFE65100)),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'No internet detected — switched to manual mode. Select your preferences below.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFFBF360C),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualSpecPicker() {
    return GlassCard(
      blur: false,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Budget
          _sectionHeader(Icons.account_balance_wallet_rounded, 'Budget Range'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_budgetLabels.length, (i) {
              return _selectionChip(
                _budgetLabels[i],
                _manualBudgetIndex == i,
                () => setState(() => _manualBudgetIndex = i),
              );
            }),
          ),

          _divider(),

          // Car type
          _sectionHeader(Icons.directions_car_rounded, 'Car Type'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in {
                'any': 'Any',
                'sedan': 'Sedan',
                'suv': 'SUV',
                'hatchback': 'Hatchback',
                'mpv': 'MPV',
              }.entries)
                _selectionChip(
                  e.value,
                  _manualCarType == e.key,
                  () => setState(() => _manualCarType = e.key),
                ),
            ],
          ),

          _divider(),

          // Fuel type
          _sectionHeader(Icons.local_gas_station_rounded, 'Fuel Type'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in {
                'any': 'Any',
                'petrol': 'Petrol',
                'hybrid': 'Hybrid',
                'ev': 'Electric (EV)',
              }.entries)
                _selectionChip(
                  e.value,
                  _manualFuelType == e.key,
                  () => setState(() => _manualFuelType = e.key),
                ),
            ],
          ),

          _divider(),

          // Usage
          _sectionHeader(Icons.route_rounded, 'Typical Usage'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in {
                'city': 'City / Commute',
                'both': 'Mixed',
                'highway': 'Highway / Outstation',
              }.entries)
                _selectionChip(
                  e.value,
                  _manualUsageType == e.key,
                  () => setState(() => _manualUsageType = e.key),
                ),
            ],
          ),

          _divider(),

          // Priorities (multi-select)
          _sectionHeader(Icons.star_rounded, 'What matters most?'),
          const SizedBox(height: 4),
          const Text(
            'Select all that apply',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in {
                'price': 'Price',
                'fuel': 'Fuel Economy',
                'safety': 'Safety',
              }.entries)
                _multiSelectChip(
                  e.value,
                  _manualPriorities.contains(e.key),
                  () => setState(() {
                    if (_manualPriorities.contains(e.key)) {
                      if (_manualPriorities.length > 1) {
                        _manualPriorities.remove(e.key);
                      }
                    } else {
                      _manualPriorities.add(e.key);
                    }
                  }),
                ),
            ],
          ),

          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: PressableButton(
              glass: true,
              borderRadius: BorderRadius.circular(16),
              padding: const EdgeInsets.symmetric(vertical: 16),
              onPressed: _proceedManually,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_rounded, size: 18, color: Colors.white70),
                  SizedBox(width: 8),
                  Text(
                    'Find My Car',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppTheme.accentLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: AppTheme.accent),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  Widget _divider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 18),
      child: Divider(height: 1, color: AppTheme.cardBorder),
    );
  }

  Widget _selectionChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.textPrimary : AppTheme.accentLight.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected ? AppTheme.textPrimary : AppTheme.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _multiSelectChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accent : AppTheme.accentLight.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected ? AppTheme.accent : AppTheme.cardBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check_rounded, size: 13, color: Colors.white),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
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
                  _formatCarTypeLabel(result.carType),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildInfoTile(
                  Icons.local_gas_station_rounded,
                  'Fuel',
                  _formatFuelLabel(result.fuelType),
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
              child: const Text(
                'Continue with these preferences',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: Colors.white,
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
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.textPrimary),
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

  Widget _buildExampleChip(String example, int index) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: () => _useExample(example),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: AppTheme.warmSurface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.cardBorder),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B7355).withValues(alpha: 0.08),
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
    )
        .animate(delay: (1400 + index * 100).ms)
        .fadeIn(duration: 350.ms)
        .slideX(
            begin: 0.15,
            end: 0,
            duration: 350.ms,
            curve: Curves.easeOutCubic);
  }

  Widget _buildConfidenceBadge(String confidence) {
    Color bg;
    Color textColor;
    String label;
    switch (confidence) {
      case 'high':
        bg = AppTheme.accent;
        textColor = Colors.white;
        label = 'High';
        break;
      case 'low':
        bg = const Color(0xFFEDE8E3);
        textColor = AppTheme.textSecondary;
        label = 'Low';
        break;
      default:
        bg = AppTheme.accentBlue;
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

  String _formatBudgetLabel(int index) => _budgetLabels[index];

  String _formatNumber(double v) {
    if (v >= 1000) {
      final thousands =
          (v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1);
      return '${thousands}k';
    }
    return v.toStringAsFixed(0);
  }

  String _formatUsageType(String type) {
    switch (type) {
      case 'city': return 'City';
      case 'highway': return 'Highway';
      case 'both': return 'Mixed';
      default: return type;
    }
  }

  String _formatCarTypeLabel(String type) {
    switch (type) {
      case 'any': return 'Any';
      case 'sedan': return 'Sedan';
      case 'suv': return 'SUV';
      case 'mpv': return 'MPV';
      case 'hatchback': return 'Hatchback';
      case 'truck': return 'Truck';
      case 'van': return 'Van';
      default: return type;
    }
  }

  String _formatFuelLabel(String type) {
    switch (type) {
      case 'any': return 'Any';
      case 'petrol': return 'Petrol';
      case 'ev': return 'Electric';
      case 'hybrid': return 'Hybrid';
      default: return type;
    }
  }

  String _formatPriorityLabel(String p) {
    switch (p) {
      case 'price': return 'Price';
      case 'fuel': return 'Fuel Economy';
      case 'safety': return 'Safety';
      default: return p;
    }
  }
}
