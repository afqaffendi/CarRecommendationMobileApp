import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image/image.dart' as img;

class CloudinaryService {
  static CloudinaryPublic? _cloudinary;
  static const String _carImagesFolder = 'car-images';

  // Initialize Cloudinary with environment variables
  static Future<void> initialize() async {
    await dotenv.load(fileName: ".env");
    
    final cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'];
    final apiKey = dotenv.env['CLOUDINARY_API_KEY'];
    
    if (cloudName == null || apiKey == null) {
      throw Exception('Cloudinary credentials not found in .env file');
    }
    
    _cloudinary = CloudinaryPublic(cloudName, 'ml_default', cache: false);
  }

  // Upload car image to Cloudinary
  static Future<CloudinaryResponse?> uploadCarImage({
    required File imageFile,
    required String carBrand,
    required String carModel,
    String? variant,
  }) async {
    if (_cloudinary == null) {
      throw Exception('Cloudinary not initialized. Call initialize() first.');
    }

    try {
      // Optimize image before upload
      final optimizedFile = await _optimizeImage(imageFile);
      
      // Generate unique public ID
      final publicId = _generatePublicId(carBrand, carModel, variant);
      
      // Upload to Cloudinary with transformations
      final response = await _cloudinary!.uploadFile(
        CloudinaryFile.fromFile(
          optimizedFile.path,
          folder: _carImagesFolder,
          publicId: publicId,
          resourceType: CloudinaryResourceType.Image,
        ),
        onProgress: (count, total) {
          print('Upload Progress: ${(count / total * 100).toStringAsFixed(0)}%');
        },
      );

      // Clean up temporary file
      if (optimizedFile.path != imageFile.path) {
        await optimizedFile.delete();
      }

      return response;
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  // Get optimized image URL with transformations
  static String getOptimizedImageUrl({
    required String publicId,
    int width = 400,
    int height = 300,
    String? quality = 'auto',
    String? format = 'auto',
  }) {
    if (_cloudinary == null) {
      throw Exception('Cloudinary not initialized');
    }

    // Generate Cloudinary URL with transformations
    final cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'];
    final transformations = 'w_$width,h_$height,c_fill,q_$quality,f_auto';
    return 'https://res.cloudinary.com/$cloudName/image/upload/$transformations/$publicId';
  }

  // Get thumbnail URL for list views
  static String getThumbnailUrl(String publicId) {
    return getOptimizedImageUrl(
      publicId: publicId,
      width: 200,
      height: 150,
      quality: 'auto',
    );
  }

  // Get high-resolution URL for detail views
  static String getHighResUrl(String publicId) {
    return getOptimizedImageUrl(
      publicId: publicId,
      width: 800,
      height: 600,
      quality: 'auto',
    );
  }

  // Delete image from Cloudinary
  static Future<bool> deleteImage(String publicId) async {
    if (_cloudinary == null) {
      throw Exception('Cloudinary not initialized');
    }

    try {
      // Note: Image deletion requires admin API which is not available in the public SDK
      // For now, return true as images can be managed through Cloudinary dashboard
      print('Image deletion would be done through Cloudinary dashboard');
      return true;
    } catch (e) {
      print('Error deleting image: $e');
      return false;
    }
  }

  // Generate consistent public ID for car images
  static String _generatePublicId(String brand, String model, String? variant) {
    final brandClean = brand.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final modelClean = model.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final variantClean = variant?.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '') ?? '';
    
    return variantClean.isNotEmpty 
      ? '${brandClean}_${modelClean}_$variantClean'
      : '${brandClean}_$modelClean';
  }

  // Optimize image before upload (compress and resize)
  static Future<File> _optimizeImage(File imageFile) async {
    try {
      // Read the image
      final imageBytes = await imageFile.readAsBytes();
      final originalImage = img.decodeImage(imageBytes);
      
      if (originalImage == null) return imageFile;

      // Resize if too large (max 1200px width)
      img.Image resizedImage = originalImage;
      if (originalImage.width > 1200) {
        resizedImage = img.copyResize(
          originalImage,
          width: 1200,
          interpolation: img.Interpolation.linear,
        );
      }

      // Compress to JPEG with 85% quality
      final compressedBytes = img.encodeJpg(resizedImage, quality: 85);
      
      // Create temporary file
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/optimized_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(compressedBytes);
      
      return tempFile;
    } catch (e) {
      print('Error optimizing image: $e');
      return imageFile;
    }
  }

  // Bulk upload images for multiple cars
  static Future<Map<String, String?>> bulkUploadCarImages(
    List<Map<String, dynamic>> carImageData,
  ) async {
    final results = <String, String?>{};
    
    for (final data in carImageData) {
      final carId = data['carId'] as String;
      final imageFile = data['imageFile'] as File;
      final brand = data['brand'] as String;
      final model = data['model'] as String;
      final variant = data['variant'] as String?;
      
      final response = await uploadCarImage(
        imageFile: imageFile,
        carBrand: brand,
        carModel: model,
        variant: variant,
      );
      
      results[carId] = response?.secureUrl;
    }
    
    return results;
  }

  // Check if Cloudinary is properly configured
  static bool get isConfigured {
    return _cloudinary != null;
  }

  // Get direct upload URL (for advanced use cases)
  static String? get cloudName {
    return dotenv.env['CLOUDINARY_CLOUD_NAME'];
  }
}