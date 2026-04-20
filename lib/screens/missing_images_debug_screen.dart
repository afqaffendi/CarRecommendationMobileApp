import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/car.dart';
import '../services/cloudinary_image_map.dart';
import '../services/firestore_service.dart';

class MissingImagesDebugScreen extends StatefulWidget {
  const MissingImagesDebugScreen({super.key});

  @override
  State<MissingImagesDebugScreen> createState() => _MissingImagesDebugScreenState();
}

class _MissingImagesDebugScreenState extends State<MissingImagesDebugScreen> {
  List<Car> _allCars = [];
  bool _isLoading = true;
  final FirestoreService _firestoreService = FirestoreService();
  
  @override
  void initState() {
    super.initState();
    _loadCars();
  }

  Future<void> _loadCars() async {
    try {
      final cars = await _firestoreService.getCars();
      setState(() {
        _allCars = cars;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Missing Images Debug'),
          backgroundColor: Colors.blue[800],
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Analyze cars with and without images
    Map<String, List<Car>> analysis = _analyzeCars();
    List<Car> carsWithImages = analysis['withImages'] ?? [];
    List<Car> carsWithoutImages = analysis['withoutImages'] ?? [];
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Missing Images Debug'),
        backgroundColor: Colors.blue[800],
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy Missing Car Names',
            onPressed: () => _copyMissingCarNames(carsWithoutImages),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Card
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Image Analysis Summary',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Total Cars',
                            _allCars.length.toString(),
                            Colors.blue,
                            Icons.directions_car,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'With Images',
                            carsWithImages.length.toString(),
                            Colors.green,
                            Icons.check_circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Missing Images',
                            carsWithoutImages.length.toString(),
                            Colors.red,
                            Icons.image_not_supported,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Cars WITH Images
            Text(
              '✅ Cars With Images (${carsWithImages.length})',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.green[700],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (carsWithImages.isNotEmpty) 
              _buildCarsList(carsWithImages, hasImages: true)
            else
              const Text('No cars have images yet'),

            const SizedBox(height: 24),

            // Cars WITHOUT Images  
            Text(
              '❌ Cars Missing Images (${carsWithoutImages.length})',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.red[700],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (carsWithoutImages.isNotEmpty) 
              _buildCarsList(carsWithoutImages, hasImages: false)
            else
              const Text('All cars have images! 🎉'),

            const SizedBox(height: 24),

            // Instructions
            Card(
              color: Colors.orange[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📝 How to Add Missing Images',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '1. Upload car images to your Cloudinary account\n'
                      '2. Copy the public ID from Cloudinary (e.g., "Honda_Civic_abc123")\n'
                      '3. Add the mapping to CloudinaryImageMap.dart:\n'
                      '   \'Honda Civic 1.5 E\': \'Honda_Civic_abc123\',\n'
                      '4. Update the image format in getImageFormat method\n'
                      '5. Tap the copy button above to copy missing car names',
                      style: TextStyle(height: 1.5),
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

  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCarsList(List<Car> cars, {required bool hasImages}) {
    return Card(
      child: Column(
        children: cars.map((car) {
          String displayName = '${car.brand} ${car.model}';
          String? publicId = CloudinaryImageMap.getPublicId(car.brand, car.model);
          
          return ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 12,
              backgroundColor: hasImages ? Colors.green[100] : Colors.red[100],
              child: Icon(
                hasImages ? Icons.check : Icons.close,
                size: 16,
                color: hasImages ? Colors.green[700] : Colors.red[700],
              ),
            ),
            title: Text(
              displayName,
              style: const TextStyle(fontSize: 14),
            ),
            subtitle: hasImages && publicId != null
                ? Text(
                    'Public ID: $publicId',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontFamily: 'monospace',
                    ),
                  )
                : Text(
                    'Price: RM${car.price.toStringAsFixed(0)} • ${car.seats} seats',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
            trailing: hasImages 
                ? const Icon(Icons.image, color: Colors.green, size: 16)
                : const Icon(Icons.image_not_supported, color: Colors.red, size: 16),
          );
        }).toList(),
      ),
    );
  }

  Map<String, List<Car>> _analyzeCars() {
    List<Car> carsWithImages = [];
    List<Car> carsWithoutImages = [];
    
    for (Car car in _allCars) {
      if (CloudinaryImageMap.hasImage(car.brand, car.model)) {
        carsWithImages.add(car);
      } else {
        carsWithoutImages.add(car);
      }
    }
    
    return {
      'withImages': carsWithImages,
      'withoutImages': carsWithoutImages,
    };
  }

  void _copyMissingCarNames(List<Car> carsWithoutImages) {
    if (carsWithoutImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No missing cars to copy!')),
      );
      return;
    }

    // Create a formatted list for easy copying
    StringBuffer buffer = StringBuffer();
    buffer.writeln('CARS MISSING IMAGES (${carsWithoutImages.length} total):');
    buffer.writeln('=' * 50);
    
    for (int i = 0; i < carsWithoutImages.length; i++) {
      Car car = carsWithoutImages[i];
      String displayName = '${car.brand} ${car.model}';
      buffer.writeln('${i + 1}. $displayName');
      buffer.writeln('   Suggested mapping: \'$displayName\': \'${_suggestPublicId(displayName)}\',');
      buffer.writeln();
    }
    
    buffer.writeln('COPY AND ADD TO CloudinaryImageMap.dart _imageMap:');
    for (Car car in carsWithoutImages) {
      String displayName = '${car.brand} ${car.model}';
      buffer.writeln('    \'$displayName\': \'${_suggestPublicId(displayName)}\',');
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied ${carsWithoutImages.length} missing car names to clipboard!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  String _suggestPublicId(String carName) {
    // Generate suggested public ID format based on existing pattern
    return '${carName
        .replaceAll(' ', '_')
        .replaceAll('.', '')
        .replaceAll('-', '_')}_xxxxxx'; // Placeholder for actual Cloudinary ID
  }
}
