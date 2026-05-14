import 'package:flutter/material.dart';
import 'dart:io';
import '../models/car.dart';
import '../services/image_management_service.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CarImageManagementScreen extends StatefulWidget {
  final Car? selectedCar;

  const CarImageManagementScreen({super.key, this.selectedCar});

  @override
  State<CarImageManagementScreen> createState() => _CarImageManagementScreenState();
}

class _CarImageManagementScreenState extends State<CarImageManagementScreen> {
  List<Car> cars = [];
  bool isLoading = false;
  Car? selectedCar;

  @override
  void initState() {
    super.initState();
    selectedCar = widget.selectedCar;
    _loadCars();
  }

  Future<void> _loadCars() async {
    final loadedCars = DatabaseService.getAllCars();
    setState(() {
      cars = loadedCars;
    });
  }

  Future<void> _uploadImage(Car car) async {
    setState(() => isLoading = true);

    try {
      final imageSource = await _showImageSourceDialog();
      if (imageSource == null) {
        setState(() => isLoading = false);
        return;
      }

      File? imageFile;
      if (imageSource == ImageSource.gallery) {
        imageFile = await ImageManagementService.pickImageFromGallery();
      } else {
        imageFile = await ImageManagementService.pickImageFromCamera();
      }

      if (imageFile != null) {
        final success = await ImageManagementService.uploadCarImage(
          car: car,
          imageFile: imageFile,
        );

        if (success) {
          _showSnackBar('Image uploaded successfully!', const Color(0xFF4CAF82));
          await _loadCars();
        } else {
          _showSnackBar('Failed to upload image', const Color(0xFFE53935));
        }
      }
    } catch (e) {
      _showSnackBar('Error uploading image: $e', const Color(0xFFE53935));
    }

    setState(() => isLoading = false);
  }

  Future<void> _removeImage(Car car) async {
    final confirm = await _showConfirmDialog(
      'Remove Image',
      'Are you sure you want to remove the image for ${car.displayName}?',
    );

    if (confirm) {
      setState(() => isLoading = true);

      final success = await ImageManagementService.removeCarImage(car);

      if (success) {
        _showSnackBar('Image removed successfully!', const Color(0xFF4CAF82));
        await _loadCars();
      } else {
        _showSnackBar('Failed to remove image', const Color(0xFFE53935));
      }

      setState(() => isLoading = false);
    }
  }

  Future<ImageSource?> _showImageSourceDialog() async {
    return showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppTheme.warmSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppTheme.cardBorder),
          ),
          title: const Text(
            'Select Image Source',
            style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogOption(
                icon: Icons.photo_library_rounded,
                label: 'Gallery',
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              const SizedBox(height: 8),
              _buildDialogOption(
                icon: Icons.camera_alt_rounded,
                label: 'Camera',
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDialogOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.accentLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.accent, size: 22),
            const SizedBox(width: 14),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _showConfirmDialog(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppTheme.warmSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppTheme.cardBorder),
          ),
          title: Text(
            title,
            style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
          ),
          content: Text(
            message,
            style: const TextStyle(color: AppTheme.textSecondary, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              style: TextButton.styleFrom(foregroundColor: AppTheme.textSecondary),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: AppTheme.textPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: AppTheme.textPrimary)),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildCarImageTile(Car car) {
    final hasImage = ImageManagementService.hasImage(car);
    final imageUrl = hasImage
        ? ImageManagementService.getCarImageUrl(car, size: ImageSize.thumbnail)
        : ImageManagementService.getPlaceholderImageUrl();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.warmSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 56,
            height: 56,
            child: hasImage && imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: AppTheme.accentLight,
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.accent,
                          ),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: AppTheme.accentLight,
                      child: const Icon(Icons.broken_image_rounded, color: AppTheme.accent),
                    ),
                  )
                : Container(
                    color: AppTheme.accentLight,
                    child: const Icon(Icons.directions_car_rounded, color: AppTheme.accent),
                  ),
          ),
        ),
        title: Text(
          car.displayName,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 6, top: 1),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hasImage ? const Color(0xFF4CAF82) : const Color(0xFFFFB74D),
              ),
            ),
            Text(
              hasImage ? 'Image available' : 'No image',
              style: TextStyle(
                color: hasImage ? const Color(0xFF4CAF82) : const Color(0xFFFFB74D),
                fontSize: 13,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildIconBtn(
              icon: Icons.camera_alt_rounded,
              tooltip: 'Upload Image',
              onTap: isLoading ? null : () => _uploadImage(car),
            ),
            if (hasImage) ...[
              const SizedBox(width: 4),
              _buildIconBtn(
                icon: Icons.delete_rounded,
                tooltip: 'Remove Image',
                color: AppTheme.accent,
                onTap: isLoading ? null : () => _removeImage(car),
              ),
            ],
          ],
        ),
        onTap: () => _showImagePreview(car),
      ),
    );
  }

  Widget _buildIconBtn({
    required IconData icon,
    required String tooltip,
    Color color = AppTheme.textSecondary,
    VoidCallback? onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.accentLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: onTap == null ? AppTheme.textSecondary.withValues(alpha: 0.4) : color, size: 18),
        ),
      ),
    );
  }

  void _showImagePreview(Car car) {
    final imageUrl = ImageManagementService.getCarImageUrl(car, size: ImageSize.large);

    if (imageUrl != null) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: AppTheme.warmSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppTheme.cardBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        car.displayName,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(color: AppTheme.cardBorder, height: 0),
              ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const SizedBox(
                    height: 200,
                    child: Center(
                      child: CircularProgressIndicator(color: AppTheme.accent),
                    ),
                  ),
                  errorWidget: (context, url, error) => const SizedBox(
                    height: 200,
                    child: Center(
                      child: Icon(Icons.broken_image_rounded, size: 50, color: AppTheme.accent),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
      body: Column(
        children: [
          if (isLoading)
            LinearProgressIndicator(
              color: AppTheme.accent,
              backgroundColor: AppTheme.accentLight,
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.accentLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: AppTheme.accent, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${cars.length} cars in database',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const Text(
                        'Tap a car to preview · camera icon to upload',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: AppTheme.divider, height: 0, indent: 24, endIndent: 24),
          const SizedBox(height: 8),
          Expanded(
            child: cars.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppTheme.accentLight,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.directions_car_rounded,
                            color: AppTheme.accent,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No cars found',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Import your car data first',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 100),
                    itemCount: cars.length,
                    itemBuilder: (context, index) => _buildCarImageTile(cars[index]),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: isLoading ? null : _bulkUploadImages,
        backgroundColor: AppTheme.accent,
        foregroundColor: AppTheme.textPrimary,
        icon: const Icon(Icons.cloud_upload_rounded),
        label: const Text('Bulk Upload', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  Future<void> _bulkUploadImages() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.warmSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.cardBorder),
        ),
        title: const Text(
          'Bulk Upload',
          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
        ),
        content: const Text(
          'Bulk upload lets you upload multiple car images at once. '
          'This feature can be configured based on your specific needs.',
          style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: AppTheme.textPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

enum ImageSource { gallery, camera }
