import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/car.dart';
import '../services/database_service.dart';
import '../services/firestore_service.dart';
import '../services/simple_cloudinary_service.dart';
import '../theme/app_theme.dart';
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
            content: Text('Failed to load cars: $e',
                style: const TextStyle(color: AppTheme.textPrimary)),
            backgroundColor: const Color(0xFFE53935),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      appBar: AppBar(
        title: const Text('Car Gallery'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
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
              child: CircularProgressIndicator(color: AppTheme.accent),
            )
          : Column(
              children: [
                _buildHeader(),
                _buildSearchBar(),
                Expanded(
                  child: filtered.isEmpty
                      ? _buildEmptyState()
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
        color: AppTheme.warmSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
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
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 6,
                    backgroundColor: AppTheme.accentLight,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accent),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.accentLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Text(
              '${(pct * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppTheme.accent,
              ),
            ),
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
        style: const TextStyle(color: AppTheme.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search brand or model...',
          hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.5)),
          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppTheme.textSecondary),
          filled: true,
          fillColor: AppTheme.warmSurface,
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.cardBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.cardBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.accent),
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
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AppTheme.accentLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.photo_library_rounded,
              size: 48,
              color: AppTheme.accent,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _filter.isEmpty ? 'No cars found' : 'No results for "$_filter"',
            style: const TextStyle(fontSize: 16, color: AppTheme.textSecondary),
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
          color: AppTheme.warmSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.cardBorder),
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
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(15)),
                    child: CarImageWidget(
                      car: car,
                      width: double.infinity,
                      height: double.infinity,
                      size: 'medium',
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                  // Image status dot
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: hasImage
                            ? const Color(0xFF4CAF82).withValues(alpha: 0.9)
                            : const Color(0xFFFFB74D).withValues(alpha: 0.9),
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
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      car.model,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Text(
                      'RM ${_formatPrice(car.price)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.accent,
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

  void _showDetails(Car car) {
    final publicId =
        CloudinaryImageService.conventionPublicIdFor(car.brand, car.model);
    final actualUrl = CloudinaryImageService.getCarImageUrl(car) ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SingleChildScrollView(
        child: Container(
          decoration: const BoxDecoration(
            color: AppTheme.warmSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Text(
                car.displayName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'RM ${_formatPrice(car.price)}',
                style: const TextStyle(fontSize: 14, color: AppTheme.accent),
              ),
              const SizedBox(height: 20),

              // Image preview
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CarImageWidget(
                  car: car,
                  width: double.infinity,
                  height: 180,
                  size: 'large',
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 20),

              // Expected Cloudinary public ID
              const Text(
                'Expected Cloudinary public ID:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              _copyableBox(
                text: publicId,
                onCopy: () => _copy(context, publicId, 'Public ID copied'),
              ),

              const SizedBox(height: 16),

              // URL the app is requesting
              const Text(
                'URL the app is trying to load:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Paste this in your browser — if it shows the image, the app will too.',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 6),
              _copyableBox(
                text: actualUrl,
                onCopy: () => _copy(context, actualUrl, 'URL copied'),
              ),

              const SizedBox(height: 16),

              // Troubleshooting checklist
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.accentLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Troubleshooting checklist:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _checkItem('Image is inside the car-images folder in Cloudinary'),
                    _checkItem('Filename matches the public ID above (no extra suffix)'),
                    _checkItem('Pasting the URL above in browser shows the image'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _copyableBox({required String text, required VoidCallback onCopy}) {
    return GestureDetector(
      onTap: onCopy,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.accentLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: AppTheme.textSecondary.withValues(alpha: 0.85),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.copy_rounded, size: 15, color: AppTheme.accent),
          ],
        ),
      ),
    );
  }

  Widget _checkItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_box_outline_blank_rounded,
              size: 14, color: AppTheme.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  void _copy(BuildContext ctx, String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: AppTheme.textPrimary)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.warmSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppTheme.cardBorder),
        ),
        duration: const Duration(seconds: 2),
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
