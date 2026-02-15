import 'package:flutter/material.dart';
import '../models/user_preferences.dart';
import '../services/database_service.dart';
import 'recommendation_results_screen.dart';

class PreferenceSlidersScreen extends StatefulWidget {
  final UserPreferences preferences;

  const PreferenceSlidersScreen({super.key, required this.preferences});

  @override
  State<PreferenceSlidersScreen> createState() => _PreferenceSlidersScreenState();
}

class _PreferenceSlidersScreenState extends State<PreferenceSlidersScreen> {
  late UserPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _prefs = widget.preferences;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Priorities'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'What matters most to you?',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Adjust sliders to prioritize your preferences',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),

            // Price Priority Slider
            _buildSliderSection(
              icon: Icons.attach_money,
              title: 'Price',
              subtitle: 'Lower price cars ranked higher',
              value: _prefs.priceWeight,
              color: Colors.green,
              onChanged: (v) => setState(() => _prefs.priceWeight = v),
            ),
            const SizedBox(height: 24),

            // Fuel Economy Slider
            _buildSliderSection(
              icon: Icons.local_gas_station,
              title: 'Fuel Economy',
              subtitle: 'Better mileage ranked higher',
              value: _prefs.fuelEconomyWeight,
              color: Colors.blue,
              onChanged: (v) => setState(() => _prefs.fuelEconomyWeight = v),
            ),
            const SizedBox(height: 24),

            // Safety Slider
            _buildSliderSection(
              icon: Icons.health_and_safety,
              title: 'Safety',
              subtitle: 'Higher safety rating ranked higher',
              value: _prefs.safetyWeight,
              color: Colors.orange,
              onChanged: (v) => setState(() => _prefs.safetyWeight = v),
            ),
            const SizedBox(height: 32),

            // Weight Distribution Summary
            _buildWeightSummary(),
            const SizedBox(height: 40),

            // Get Recommendations Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: _onGetRecommendations,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_awesome),
                    SizedBox(width: 8),
                    Text('Get Recommendations', style: TextStyle(fontSize: 18)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderSection({
    required IconData icon,
    required String title,
    required String subtitle,
    required double value,
    required Color color,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withAlpha(51),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withAlpha(51),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${(value * 100).toInt()}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: color,
              inactiveTrackColor: color.withAlpha(77),
              thumbColor: color,
              overlayColor: color.withAlpha(51),
              trackHeight: 8,
            ),
            child: Slider(
              value: value,
              min: 0,
              max: 1,
              divisions: 10,
              onChanged: onChanged,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Not Important', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              Text('Very Important', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeightSummary() {
    final total = _prefs.priceWeight + _prefs.fuelEconomyWeight + _prefs.safetyWeight;
    final pricePercent = total > 0 ? (_prefs.priceWeight / total * 100).toInt() : 33;
    final fuelPercent = total > 0 ? (_prefs.fuelEconomyWeight / total * 100).toInt() : 33;
    final safetyPercent = total > 0 ? (_prefs.safetyWeight / total * 100).toInt() : 34;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withAlpha(77),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Weight Distribution',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 24,
              child: Row(
                children: [
                  Expanded(
                    flex: pricePercent,
                    child: Container(color: Colors.green, alignment: Alignment.center,
                      child: Text('$pricePercent%', style: const TextStyle(color: Colors.white, fontSize: 12))),
                  ),
                  Expanded(
                    flex: fuelPercent,
                    child: Container(color: Colors.blue, alignment: Alignment.center,
                      child: Text('$fuelPercent%', style: const TextStyle(color: Colors.white, fontSize: 12))),
                  ),
                  Expanded(
                    flex: safetyPercent,
                    child: Container(color: Colors.orange, alignment: Alignment.center,
                      child: Text('$safetyPercent%', style: const TextStyle(color: Colors.white, fontSize: 12))),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLegendItem(Colors.green, 'Price'),
              _buildLegendItem(Colors.blue, 'Fuel'),
              _buildLegendItem(Colors.orange, 'Safety'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Future<void> _onGetRecommendations() async {
    await DatabaseService.savePreferences(_prefs);
    
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RecommendationResultsScreen(preferences: _prefs),
        ),
      );
    }
  }
}
