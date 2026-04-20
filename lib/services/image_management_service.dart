import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../models/car.dart';
import 'cloudinary_service.dart';
import 'database_service.dart';

class ImageManagementService {
  static final ImagePicker _picker = ImagePicker();

  // Pick image from gallery
  static Future<File?> pickImageFromGallery() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 800,
        imageQuality: 85,
      );
      
      return pickedFile != null ? File(pickedFile.path) : null;
    } catch (e) {
      print('Error picking image from gallery: $e');
      return null;
    }
  }

  // Pick image from camera
  static Future<File?> pickImageFromCamera() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 800,
        imageQuality: 85,
      );
      
      return pickedFile != null ? File(pickedFile.path) : null;
    } catch (e) {
      print('Error taking photo: $e');
      return null;
    }
  }

  // Upload image and update car in database
  static Future<bool> uploadCarImage({
    required Car car,
    required File imageFile,
  }) async {
    try {
      // Upload to Cloudinary
      final response = await CloudinaryService.uploadCarImage(
        imageFile: imageFile,
        carBrand: car.brand,
        carModel: car.model,
      );

      if (response != null && response.secureUrl.isNotEmpty) {
        // Update car with new image URL
        final updatedCar = Car(
          brand: car.brand,
          model: car.model,
          price: car.price,
          fuelEconomy: car.fuelEconomy,
          seats: car.seats,
          bootSpace: car.bootSpace,
          safetyRating: car.safetyRating,
          horsepower: car.horsepower,
          type: car.type,
          year: car.year,
          imageUrl: response.secureUrl,
        );

        // Save updated car to database
        await DatabaseService.updateCar(DatabaseService.carKeyFromCar(car), updatedCar);
        return true;
      }
      
      return false;
    } catch (e) {
      print('Error uploading car image: $e');
      return false;
    }
  }

  // Get optimized image URL for display
  static String? getCarImageUrl(Car car, {ImageSize size = ImageSize.medium}) {
    if (car.imageUrl == null || car.imageUrl!.isEmpty) {
      return null;
    }

    // Check if it's already a Cloudinary URL
    if (!car.imageUrl!.contains('cloudinary.com')) {
      return car.imageUrl; // Return as-is if not from Cloudinary
    }

    // Extract public ID from Cloudinary URL
    final publicId = _extractPublicIdFromUrl(car.imageUrl!);
    if (publicId == null) return car.imageUrl;

    // Return optimized URL based on size
    switch (size) {
      case ImageSize.thumbnail:
        return CloudinaryService.getThumbnailUrl(publicId);
      case ImageSize.medium:
        return CloudinaryService.getOptimizedImageUrl(publicId: publicId);
      case ImageSize.large:
        return CloudinaryService.getHighResUrl(publicId);
    }
  }

  // Remove car image
  static Future<bool> removeCarImage(Car car) async {
    try {
      if (car.imageUrl != null && car.imageUrl!.contains('cloudinary.com')) {
        final publicId = _extractPublicIdFromUrl(car.imageUrl!);
        if (publicId != null) {
          await CloudinaryService.deleteImage(publicId);
        }
      }

      // Update car to remove image URL
      final updatedCar = Car(
        brand: car.brand,
        model: car.model,
        price: car.price,
        fuelEconomy: car.fuelEconomy,
        seats: car.seats,
        bootSpace: car.bootSpace,
        safetyRating: car.safetyRating,
        horsepower: car.horsepower,
        type: car.type,
        year: car.year,
        imageUrl: null,
      );

      await DatabaseService.updateCar(DatabaseService.carKeyFromCar(car), updatedCar);
      return true;
    } catch (e) {
      print('Error removing car image: $e');
      return false;
    }
  }

  // Batch upload images for multiple cars
  static Future<Map<String, bool>> batchUploadCarImages(
    Map<Car, File> carImageMap,
  ) async {
    final results = <String, bool>{};
    
    for (final entry in carImageMap.entries) {
      final car = entry.key;
      final imageFile = entry.value;
      final success = await uploadCarImage(car: car, imageFile: imageFile);
      results[car.displayName] = success;
    }
    
    return results;
  }

  // Show image picker dialog (returns selected File)
  static Future<File?> showImagePickerDialog() async {
    // This would typically be implemented with a dialog in the UI layer
    // For now, we'll default to gallery
    return pickImageFromGallery();
  }

  // Extract public ID from Cloudinary URL
  static String? _extractPublicIdFromUrl(String url) {
    try {
      // Cloudinary URL format: https://res.cloudinary.com/{cloud_name}/image/upload/v{version}/{public_id}.{format}
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      
      if (pathSegments.length >= 4 && pathSegments[1] == 'image') {
        final publicIdWithFormat = pathSegments.last;
        final publicId = publicIdWithFormat.split('.').first;
        return 'car-images/$publicId'; // Include folder path
      }
    } catch (e) {
      print('Error extracting public ID from URL: $e');
    }
    return null;
  }

  // Check if car has image
  static bool hasImage(Car car) {
    return car.imageUrl != null && car.imageUrl!.isNotEmpty;
  }

  // Get placeholder image URL for cars without images
  static String getPlaceholderImageUrl() {
    return 'https://via.placeholder.com/400x300/f0f0f0/999999?text=No+Image';
  }
}

enum ImageSize {
  thumbnail, // 200x150
  medium,    // 400x300
  large,     // 800x600
}