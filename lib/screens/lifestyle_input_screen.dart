import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
  final _parserService = LifestyleParserService();
  
  bool _isParsing = false;
  ParsedLifestyle? _parsedResult;

  final List<String> _examplePrompts = [
    "nak kereta murah untuk kerja KL",
    "family car, safety penting, balik kampung selalu", 
    "first car fresh grad, jimat minyak",
    "SUV bawah 120k, parking rumah besar",
  ];

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _parseInput() async {
    final input = _textController.text.trim();
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please type something first',
            style: GoogleFonts.inter(),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isParsing = true;
      _parsedResult = null;
    });

    // Save to search history
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
    DatabaseService.savePreferences(prefs);
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PreferenceSlidersScreen(preferences: prefs),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Tell Us About You',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'What car do you need?',
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Just type naturally - in English, Malay, or mix!\nOur AI understands you.',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Colors.black54,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),

            // Text Input Card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black.withOpacity(0.1)),
              ),
              child: TextField(
                controller: _textController,
                maxLines: 4,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  height: 1.5,
                ),
                decoration: InputDecoration(
                  hintText: 'Type anything! e.g. "nak kereta murah untuk kerja" or "family car with good safety"...',
                  hintStyle: GoogleFonts.inter(
                    color: Colors.black38,
                    fontSize: 15,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(20),
                ),
                onChanged: (_) {
                  if (_parsedResult != null) {
                    setState(() => _parsedResult = null);
                  }
                },
              ),
            ),
            const SizedBox(height: 20),

            // Analyze Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: _isParsing ? null : _parseInput,
                style: FilledButton.styleFrom(
                  backgroundColor: _isParsing ? Colors.black38 : Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isParsing 
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Analyzing...',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.auto_awesome_rounded),
                          const SizedBox(width: 8),
                          Text(
                            'Analyze My Needs',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            // Parsed Results
            if (_parsedResult != null) ...[
              const SizedBox(height: 32),
              _buildParsedResultsCard(),
            ],

            // Example Prompts
            const SizedBox(height: 40),
            Text(
              'Or try an example:',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            ..._examplePrompts.map((example) => _buildExampleChip(example)),
            const SizedBox(height: 32),
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
        border: Border.all(color: Colors.black.withOpacity(0.1)),
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
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Analysis Complete',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              _buildConfidenceBadge(result.confidence),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            result.summary,
            style: GoogleFonts.inter(
              color: Colors.black54,
              fontSize: 15,
              height: 1.5,
            ),
          ),
          
          const SizedBox(height: 24),
          // Extracted Values  
          _buildInfoRow(
            Icons.account_balance_wallet_rounded,
            'Budget',
            'RM ${result.budget.toStringAsFixed(0)}',
          ),
          _buildInfoRow(
            Icons.route_rounded,
            'Usage',
            _formatUsageType(result.usageType),
          ),
          _buildInfoRow(
            Icons.local_parking_rounded,
            'Parking',
            _formatParkingSpace(result.parkingSpace),
          ),
          
          const SizedBox(height: 24),
          Text(
            'Detected Priorities',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          _buildPriorityBar('Price', result.priceImportance),
          _buildPriorityBar('Fuel Economy', result.fuelImportance),
          _buildPriorityBar('Safety', result.safetyImportance),
          
          if (result.detectedNeeds.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'What I Detected',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: result.detectedNeeds.map((need) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black.withOpacity(0.1)),
                ),
                child: Text(
                  need,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.black87,
                  ),
                ),
              )).toList(),
            ),
          ],
          
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _proceedWithPreferences,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'Continue with these preferences',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () {
                final prefs = _parserService.toUserPreferences(result);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PreferenceSlidersScreen(preferences: prefs),
                  ),
                );
              },
              child: Text(
                'Adjust preferences manually',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: Colors.black54,
          ),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w500,
              fontSize: 15,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityBar(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(3),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: value,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${(value * 100).toInt()}%',
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExampleChip(String example) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _useExample(example),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black.withOpacity(0.1)),
          ),
          child: Text(
            example,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  String _formatUsageType(String type) {
    switch (type) {
      case 'city': return 'City driving';
      case 'highway': return 'Highway driving';
      case 'both': return 'Mixed (city + highway)';
      default: return type;
    }
  }

  String _formatParkingSpace(String space) {
    switch (space) {
      case 'compact': return 'Compact/tight space';
      case 'medium': return 'Standard parking';
      case 'large': return 'Large space available';
      default: return space;
    }
  }

  Widget _buildConfidenceBadge(String confidence) {
    Color bgColor;
    String label;
    
    switch (confidence) {
      case 'high':
        bgColor = Colors.black;
        label = 'High Confidence';
        break;
      case 'low':
        bgColor = Colors.black38;
        label = 'Best Guess';
        break;
      default:
        bgColor = Colors.black87;
        label = 'Confident';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: GoogleFonts.montserrat(
          fontSize: 10,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}