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
        const SnackBar(content: Text('Please type something first')),
      );
      return;
    }

    setState(() {
      _isParsing = true;
      _parsedResult = null;
    });

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
        title: const Text('Tell Us About You'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text(
              'What car do you need?',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Just type naturally - in English, Malay, or mix! Our AI understands you.',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),

            // Text Input
            TextField(
              controller: _textController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Type anything! e.g. "nak kereta murah untuk kerja" or "family car with good safety"...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              onChanged: (_) {
                if (_parsedResult != null) {
                  setState(() => _parsedResult = null);
                }
              },
            ),
            const SizedBox(height: 16),

            // Analyze Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: _isParsing ? null : _parseInput,
                icon: _isParsing 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(_isParsing ? 'Analyzing...' : 'Analyze My Needs'),
              ),
            ),

            // Parsed Results - AI always gives a result
            if (_parsedResult != null) ...[
              const SizedBox(height: 24),
              _buildParsedResultsCard(),
            ],

            // Example Prompts
            const SizedBox(height: 32),
            const Text(
              'Or try an example:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ..._examplePrompts.map((example) => _buildExampleChip(example)),
          ],
        ),
      ),
    );
  }

  Widget _buildParsedResultsCard() {
    final result = _parsedResult!;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade700),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'AI Analysis Complete',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              _buildConfidenceBadge(result.confidence),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            result.summary,
            style: TextStyle(color: Colors.grey.shade700, fontStyle: FontStyle.italic),
          ),
          const Divider(height: 24),
          
          // Extracted Values
          _buildExtractedRow(Icons.attach_money, 'Budget', 'RM ${result.budget.toStringAsFixed(0)}'),
          _buildExtractedRow(Icons.route, 'Usage', _formatUsageType(result.usageType)),
          _buildExtractedRow(Icons.local_parking, 'Parking', _formatParkingSpace(result.parkingSpace)),
          
          const Divider(height: 24),
          const Text('Detected Priorities:', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _buildPriorityBar('Price', result.priceImportance, Colors.green),
          _buildPriorityBar('Fuel Economy', result.fuelImportance, Colors.blue),
          _buildPriorityBar('Safety', result.safetyImportance, Colors.orange),
          
          if (result.detectedNeeds.isNotEmpty) ...[
            const Divider(height: 24),
            const Text('What I Detected:', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: result.detectedNeeds.map((need) => Chip(
                label: Text(need, style: const TextStyle(fontSize: 12)),
                backgroundColor: Colors.blue.shade50,
              )).toList(),
            ),
          ],
          
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _proceedWithPreferences,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Continue with these preferences'),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
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
              child: const Text('Adjust preferences manually'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtractedRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildPriorityBar(String label, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(fontSize: 13))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(color),
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('${(value * 100).toInt()}%', style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildExampleChip(String example) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _useExample(example),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Icon(Icons.lightbulb_outline, size: 18, color: Colors.amber.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  example,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
              ),
            ],
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
    Color color;
    String label;
    
    switch (confidence) {
      case 'high':
        color = Colors.green;
        label = 'High Confidence';
        break;
      case 'low':
        color = Colors.orange;
        label = 'Best Guess';
        break;
      default:
        color = Colors.blue;
        label = 'Confident';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
