import 'package:flutter/material.dart';
import 'dart:io';
import '../models/car.dart';
import '../services/image_management_service.dart';
import '../services/database_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CarImageManagementScreen extends StatefulWidget {
  final Car? selectedCar;

  const CarImageManagementScreen({Key? key, this.selectedCar}) : super(key: key);

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
      // Show dialog to choose image source
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
          _showSnackBar('Image uploaded successfully!', Colors.green);
          await _loadCars(); // Refresh the list
        } else {
          _showSnackBar('Failed to upload image', Colors.red);
        }
      }
    } catch (e) {
      _showSnackBar('Error uploading image: $e', Colors.red);
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
        _showSnackBar('Image removed successfully!', Colors.green);
        await _loadCars();
      } else {
        _showSnackBar('Failed to remove image', Colors.red);
      }
      
      setState(() => isLoading = false);
    }
  }

  Future<ImageSource?> _showImageSourceDialog() async {
    return showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Image Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<bool> _showConfirmDialog(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
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
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildCarImageTile(Car car) {
    final hasImage = ImageManagementService.hasImage(car);
    final imageUrl = hasImage 
      ? ImageManagementService.getCarImageUrl(car, size: ImageSize.thumbnail)
      : ImageManagementService.getPlaceholderImageUrl();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 60,
            height: 60,
            child: hasImage && imageUrl != null
              ? CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const CircularProgressIndicator(),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                )
              : Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.car_rental, color: Colors.grey),
                ),
          ),
        ),
        title: Text(car.displayName),
        subtitle: Text(
          hasImage ? 'Image available' : 'No image',
          style: TextStyle(
            color: hasImage ? Colors.green : Colors.orange,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.camera_alt),
              onPressed: isLoading ? null : () => _uploadImage(car),
              tooltip: 'Upload Image',
            ),
            if (hasImage)
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: isLoading ? null : () => _removeImage(car),
                tooltip: 'Remove Image',
              ),
          ],
        ),
        onTap: () => _showImagePreview(car),
      ),
    );
  }

  void _showImagePreview(Car car) {
    final imageUrl = ImageManagementService.getCarImageUrl(car, size: ImageSize.large);
    
    if (imageUrl != null) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: Text(car.displayName),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Expanded(
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  errorWidget: (context, url, error) => const Center(
                    child: Icon(Icons.error, size: 50),
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
        title: const Text('Car Image Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCars,
          ),
        ],
      ),
      body: Column(
        children: [
          if (isLoading)
            const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Manage images for your car database. Tap the camera icon to upload, or tap a car to view its image.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: cars.isEmpty
              ? const Center(
                  child: Text('No cars found. Import your car data first.'),
                )
              : ListView.builder(
                  itemCount: cars.length,
                  itemBuilder: (context, index) {
                    return _buildCarImageTile(cars[index]);
                  },
                ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: isLoading ? null : _bulkUploadImages,
        label: const Text('Bulk Upload'),
        icon: const Icon(Icons.cloud_upload),
      ),
    );
  }

  Future<void> _bulkUploadImages() async {
    // This would open a file picker for multiple images
    // For now, show a message about the feature
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bulk Upload'),
        content: const Text(
          'Bulk upload feature allows you to upload multiple car images at once. '
          'This feature can be implemented based on your specific needs.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

enum ImageSource { gallery, camera }