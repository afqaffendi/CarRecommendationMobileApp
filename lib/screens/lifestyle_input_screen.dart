import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/lifestyle_parser_service.dart';
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
      MaterialPageRoute(
        builder: (_) => PreferenceSlidersScreen(preferences: prefs),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text(
              'What car\ndo you need?',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Type in English, Malay, or mix — our AI understands you.',
              style: TextStyle(
                fontSize: 15,
                color: Colors.black54,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),

            // Text Input Card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    maxLines: 4,
                    style: const TextStyle(fontSize: 16, height: 1.5),
                    decoration: InputDecoration(
                      hintText:
                          'e.g. "nak kereta jimat minyak untuk kerja" or "SUV below 100k for family"...',
                      hintStyle: TextStyle(
                        color: Colors.black.withValues(alpha: 0.3),
                        fontSize: 15,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    ),
                    onChanged: (_) {
                      if (_parsedResult != null) {
                        setState(() => _parsedResult = null);
                      }
                    },
                  ),
                  // Analyze button inside the card
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: _isParsing ? null : _parseInput,
                        style: FilledButton.styleFrom(
                          backgroundColor: _isParsing ? Colors.black38 : Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isParsing
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Text('Analyzing...', style: TextStyle(fontSize: 15)),
                                ],
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.auto_awesome_rounded, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'Analyze My Needs',
                                    style: TextStyle(
                                        fontSize: 15, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Parsed Results
            if (_parsedResult != null) ...[
              const SizedBox(height: 24),
              _buildParsedResultsCard(),
            ],

            // Example Prompts — horizontal scroll
            const SizedBox(height: 32),
            const Text(
              'Try an example',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: Colors.black87,
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
    );
  }

  Widget _buildParsedResultsCard() {
    final result = _parsedResult!;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Analysis Complete',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ),
              _buildConfidenceBadge(result.confidence),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            result.summary,
            style: TextStyle(color: Colors.black54, fontSize: 14, height: 1.5),
          ),

          const SizedBox(height: 20),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          const SizedBox(height: 20),

          // Extracted values in a compact 2-column grid
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
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoTile(
                  Icons.route_rounded,
                  'Usage',
                  _formatUsageType(result.usageType),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInfoTile(
                  Icons.directions_car_rounded,
                  'Type',
                  _formatCarType(result.carType),
                ),
              ),
              const SizedBox(width: 12),
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
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
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
                          color: Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          need,
                          style: const TextStyle(fontSize: 12, color: Colors.black87),
                        ),
                      ))
                  .toList(),
            ),
          ],

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _proceedWithPreferences,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Continue with these preferences',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
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
                  MaterialPageRoute(
                    builder: (_) => PreferenceSlidersScreen(preferences: prefs),
                  ),
                );
              },
              child: const Text(
                'Adjust preferences manually',
                style: TextStyle(fontSize: 13, color: Colors.black45),
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
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: Colors.black38),
              const SizedBox(width: 4),
              Text(label,
                  style: const TextStyle(fontSize: 11, color: Colors.black38)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
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
            child: Text(label,
                style: const TextStyle(fontSize: 13, color: Colors.black87)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 6,
                backgroundColor: Colors.black.withValues(alpha: 0.06),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.black),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 32,
            child: Text(
              '${(value * 100).toInt()}%',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.north_west_rounded, size: 12, color: Colors.black38),
              const SizedBox(width: 6),
              Text(
                example,
                style: const TextStyle(fontSize: 13, color: Colors.black87),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfidenceBadge(String confidence) {
    Color bg;
    String label;
    switch (confidence) {
      case 'high':
        bg = Colors.black;
        label = 'High';
        break;
      case 'low':
        bg = Colors.black38;
        label = 'Low';
        break;
      default:
        bg = Colors.black87;
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
        style: const TextStyle(
            fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500),
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
