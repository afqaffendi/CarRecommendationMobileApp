import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
        title: Text(
          'Your Priorities',
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
            Text(
              'What matters most to you?',
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Adjust sliders to prioritize your preferences',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Colors.black54,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),

            // Price Priority Slider
            _buildSliderSection(
              icon: Icons.attach_money_rounded,
              title: 'Price',
              subtitle: 'Lower price cars ranked higher',
              value: _prefs.priceWeight,
              onChanged: (v) => setState(() => _prefs.priceWeight = v),
            ),
            const SizedBox(height: 24),

            // Fuel Economy Slider
            _buildSliderSection(
              icon: Icons.local_gas_station_rounded,
              title: 'Fuel Economy',
              subtitle: 'Better mileage ranked higher',
              value: _prefs.fuelEconomyWeight,
              onChanged: (v) => setState(() => _prefs.fuelEconomyWeight = v),
            ),
            const SizedBox(height: 24),

            // Safety Slider
            _buildSliderSection(
              icon: Icons.health_and_safety_rounded,
              title: 'Safety',
              subtitle: 'Higher safety rating ranked higher',
              value: _prefs.safetyWeight,
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
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.auto_awesome_rounded),
                    const SizedBox(width: 8),
                    Text(
                      'Get Recommendations',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
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
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black.withOpacity(0.1)),
                ),
                child: Text(
                  '${(value * 100).toInt()}%',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: Colors.black,
              inactiveTrackColor: Colors.black.withOpacity(0.1),
              thumbColor: Colors.black,
              overlayColor: Colors.black.withOpacity(0.1),
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 10,
              ),
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
              Text(
                'Not Important',
                style: GoogleFonts.inter(
                  color: Colors.black38,
                  fontSize: 12,
                ),
              ),
              Text(
                'Very Important',
                style: GoogleFonts.inter(
                  color: Colors.black38,
                  fontSize: 12,
                ),
              ),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weight Distribution',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 32,
              child: Row(
                children: [
                  Expanded(
                    flex: pricePercent,
                    child: Container(
                      color: Colors.black,
                      alignment: Alignment.center,
                      child: Text(
                        '$pricePercent%',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: fuelPercent,
                    child: Container(
                      color: Colors.black.withOpacity(0.7),
                      alignment: Alignment.center,
                      child: Text(
                        '$fuelPercent%',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: safetyPercent,
                    child: Container(
                      color: Colors.black.withOpacity(0.5),
                      alignment: Alignment.center,
                      child: Text(
                        '$safetyPercent%',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLegendItem(Colors.black, 'Price'),
              _buildLegendItem(Colors.black.withOpacity(0.7), 'Fuel'),
              _buildLegendItem(Colors.black.withOpacity(0.5), 'Safety'),
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
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.black87,
          ),
        ),
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
