import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/car.dart';
import '../services/database_service.dart';
import '../services/simple_cloudinary_service.dart';
import '../services/cloudinary_image_map.dart';
import 'package:flutter/services.dart';

class ImageDebugScreen extends StatefulWidget {
  const ImageDebugScreen({super.key});

  @override
  State<ImageDebugScreen> createState() => _ImageDebugScreenState();
}

class _ImageDebugScreenState extends State<ImageDebugScreen> {
  List<Car> cars = [];
  bool isLoading = true;
  String? testImageUrl;

  @override
  void initState() {
    super.initState();
    _loadCars();
    _generateTestUrl();
  }

  void _generateTestUrl() {
    // Test with a simple, known image URL
    testImageUrl = 'https://res.cloudinary.com/dodi1j67s/image/upload/w_400,h_300,c_fill,q_auto,f_auto/sample.jpg';
  }

  Future<void> _loadCars() async {
    try {
      List<Car> allCars;
      if (DatabaseService.hasCachedCars()) {
        allCars = DatabaseService.getCachedCars();
      } else {
        setState(() {
          isLoading = false;
        });
        _showMessage('No cars found. Please import your car data first.');
        return;
      }
      
      setState(() {
        cars = allCars.take(5).toList(); // Only show first 5 cars for debugging
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      _showMessage('Failed to load cars: $e');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    _showMessage('Copied to clipboard');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Image URL Debug', style: GoogleFonts.poppins()),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTestSection(),
                  const SizedBox(height: 24),
                  _buildCloudinaryConfigSection(),
                  const SizedBox(height: 24),
                  _buildCarUrlsSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildTestSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cloudinary Connection Test',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            Text('Test Image URL:', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      testImageUrl ?? 'No URL',
                      style: GoogleFonts.sourceCodePro(fontSize: 12),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () => _copyToClipboard(testImageUrl ?? ''),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: testImageUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        testImageUrl!,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(child: CircularProgressIndicator());
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error, color: Colors.red, size: 48),
                                const SizedBox(height: 8),
                                Text(
                                  'Test Image Failed to Load',
                                  style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Check your Cloudinary credentials',
                                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    )
                  : const Center(child: Text('No test URL')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCloudinaryConfigSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cloudinary Configuration',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            
            _buildConfigRow('Cloud Name:', 'dodi1j67s'),
            _buildConfigRow('Configured:', CloudinaryImageService.isConfigured ? 'YES' : 'NO'),
            
            const SizedBox(height: 16),
            
            Text(
              'Expected URL Pattern:',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Text(
                'https://res.cloudinary.com/dodi1j67s/image/upload/w_400,h_300,c_fill,q_auto,f_auto/[public_id].jpg',
                style: GoogleFonts.sourceCodePro(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarUrlsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Car Image URLs (First 5 Cars)',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            if (cars.isEmpty)
              const Text('No cars loaded')
            else
              ...cars.map((car) => _buildCarUrlCard(car)),
          ],
        ),
      ),
    );
  }

  Widget _buildCarUrlCard(Car car) {
    final publicId = CloudinaryImageMap.getPublicId(car.brand, car.model);
    final imageUrl = CloudinaryImageService.getCarImageUrl(car);
    final hasImage = CloudinaryImageService.hasImage(car);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: hasImage ? Colors.green[50] : Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    car.displayName,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                  ),
                ),
                Icon(
                  hasImage ? Icons.check_circle : Icons.error,
                  color: hasImage ? Colors.green : Colors.red,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            _buildUrlRow('Brand:', car.brand),
            _buildUrlRow('Model:', car.model),
            _buildUrlRow('Type:', car.type),
            
            const SizedBox(height: 8),
            
            if (publicId != null) ...[
              _buildUrlRow('Found Public ID:', publicId, canCopy: true),
              _buildUrlRow('Image Format:', CloudinaryImageMap.getImageFormat(publicId)),
            ] else ...[
              Text(
                '❌ No image mapping found',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: Colors.red[700],
                ),
              ),
            ],
            
            const SizedBox(height: 8),
            
            if (imageUrl != null) ...[
              Text('Full URL:', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12)),
              const SizedBox(height: 4),
              
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        imageUrl,
                        style: GoogleFonts.sourceCodePro(fontSize: 10),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      onPressed: () => _copyToClipboard(imageUrl),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Test the actual image
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.red[50],
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.broken_image, color: Colors.red[400], size: 24),
                              const SizedBox(height: 4),
                              Text(
                                'Failed to load image',
                                style: GoogleFonts.inter(fontSize: 10, color: Colors.red[600]),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ] else ...[
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image_not_supported, color: Colors.grey[600], size: 32),
                      const SizedBox(height: 8),
                      Text(
                        'No image available',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Add mapping in CloudinaryImageMap',
                        style: GoogleFonts.inter(fontSize: 10, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConfigRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.sourceCodePro(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildUrlRow(String label, String value, {bool canCopy = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.sourceCodePro(fontSize: 12),
            ),
          ),
          if (canCopy)
            IconButton(
              icon: const Icon(Icons.copy, size: 16),
              onPressed: () => _copyToClipboard(value),
            ),
        ],
      ),
    );
  }
}