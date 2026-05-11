import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/car.dart';
import '../services/database_service.dart';
import '../services/firestore_service.dart';
import '../services/simple_cloudinary_service.dart';
import '../widgets/car_image_widget.dart';

class ImageGalleryScreen extends StatefulWidget {
  const ImageGalleryScreen({super.key});

  @override
  State<ImageGalleryScreen> createState() => _ImageGalleryScreenState();
}

class _ImageGalleryScreenState extends State<ImageGalleryScreen> {
  List<Car> _cars = [];
  bool _isLoading = true;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _loadCars();
  }

  Future<void> _loadCars() async {
    setState(() => _isLoading = true);
    try {
      List<Car> all;
      if (DatabaseService.hasCachedCars()) {
        all = DatabaseService.getCachedCars();
      } else {
        all = await FirestoreService().getCars();
        if (all.isNotEmpty) DatabaseService.cacheCars(all);
      }
      setState(() {
        _cars = all;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load cars: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Car> get _filtered {
    if (_filter.isEmpty) return _cars;
    final q = _filter.toLowerCase();
    return _cars
        .where((c) =>
            c.brand.toLowerCase().contains(q) ||
            c.model.toLowerCase().contains(q))
        .toList();
  }

  int get _withImages =>
      _cars.where((c) => CloudinaryImageService.hasImage(c)).length;

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Car Gallery',
            style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadCars,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.black))
          : Column(
              children: [
                _buildHeader(),
                _buildSearchBar(),
                Expanded(
                  child: filtered.isEmpty
                      ? _buildEmptyState()
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.72,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) => _buildCarCard(filtered[i]),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    final total = _cars.length;
    final covered = _withImages;
    final pct = total == 0 ? 0.0 : covered / total;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$covered / $total cars with images',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 6,
                    backgroundColor:
                        Colors.black.withValues(alpha: 0.08),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.black),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text(
            '${(pct * 100).toStringAsFixed(0)}%',
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: TextField(
        onChanged: (v) => setState(() => _filter = v),
        decoration: InputDecoration(
          hintText: 'Search brand or model...',
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: Colors.black.withValues(alpha: 0.08)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: Colors.black.withValues(alpha: 0.08)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.black),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_library_outlined, size: 64, color: Colors.black12),
          const SizedBox(height: 16),
          Text(
            _filter.isEmpty ? 'No cars found' : 'No results for "$_filter"',
            style: const TextStyle(fontSize: 16, color: Colors.black45),
          ),
        ],
      ),
    );
  }

  Widget _buildCarCard(Car car) {
    final hasImage = CloudinaryImageService.hasImage(car);

    return GestureDetector(
      onTap: () => _showDetails(car),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.black.withValues(alpha: 0.07),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image area
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(15)),
                    child: CarImageWidget(
                      car: car,
                      width: double.infinity,
                      height: double.infinity,
                      size: 'medium',
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                  // Image status indicator
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: hasImage
                            ? Colors.green.withValues(alpha: 0.9)
                            : Colors.orange.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        hasImage ? Icons.check_rounded : Icons.add_rounded,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Car info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      car.brand,
                      style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black38,
                          fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      car.model,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Text(
                      'RM ${_formatPrice(car.price)}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54),
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

  void _showDetails(Car car) {
    final publicId =
        CloudinaryImageService.conventionPublicIdFor(car.brand, car.model);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            Text(car.displayName,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('RM ${_formatPrice(car.price)}',
                style:
                    const TextStyle(fontSize: 14, color: Colors.black45)),

            const SizedBox(height: 20),

            // Image preview
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CarImageWidget(
                car: car,
                width: double.infinity,
                height: 200,
                size: 'large',
                borderRadius: BorderRadius.circular(12),
              ),
            ),

            const SizedBox(height: 20),

            // Status row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: CloudinaryImageService.hasImage(car)
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CloudinaryImageService.hasImage(car)
                            ? Icons.check_circle_rounded
                            : Icons.image_not_supported_rounded,
                        size: 14,
                        color: CloudinaryImageService.hasImage(car)
                            ? Colors.green
                            : Colors.orange,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        CloudinaryImageService.hasImage(car)
                            ? 'Image available'
                            : 'No image yet',
                        style: TextStyle(
                          fontSize: 12,
                          color: CloudinaryImageService.hasImage(car)
                              ? Colors.green
                              : Colors.orange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Public ID to use for upload
            const Text('Upload this file to Cloudinary:',
                style:
                    TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: '$publicId.jpg'));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Copied to clipboard'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: Colors.black,
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.black.withValues(alpha: 0.08)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$publicId.jpg',
                        style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            color: Colors.black87),
                      ),
                    ),
                    const Icon(Icons.copy_rounded,
                        size: 16, color: Colors.black38),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _formatPrice(double price) {
    final s = price.toStringAsFixed(0);
    final buf = StringBuffer();
    var count = 0;
    for (var i = s.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) buf.write(',');
      buf.write(s[i]);
      count++;
    }
    return buf.toString().split('').reversed.join();
  }
}
