import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/car.dart';

class CloudinaryImageService {
  static const String baseUrl = 'https://res.cloudinary.com';
  
  // Generate Cloudinary URL for a car image
  static String getCarImageUrl(Car car, {int width = 400, int height = 300, String quality = 'auto'}) {
    final cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'];
    
    if (cloudName == null) {
      throw Exception('CLOUDINARY_CLOUD_NAME not found in environment variables');
    }
    
    // Generate consistent public ID from car data
    final publicId = generatePublicId(car);
    
    // Generate Cloudinary URL with transformations
    final transformations = 'w_$width,h_$height,c_fill,q_$quality,f_auto';
    
    return '$baseUrl/$cloudName/image/upload/$transformations/$publicId.jpg';
  }
  
  // Generate different sizes for different use cases
  static Map<String, String> getCarImageUrls(Car car) {
    return {
      'thumbnail': getCarImageUrl(car, width: 200, height: 150),
      'medium': getCarImageUrl(car, width: 400, height: 300),
      'large': getCarImageUrl(car, width: 800, height: 600),
      'full': getCarImageUrl(car, width: 1200, height: 800),
    };
  }
  
  // Generate consistent public ID from car data
  static String generatePublicId(Car car) {
    final brand = car.brand.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final model = car.model.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final variant = car.variant?.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '') ?? '';
    
    // Create consistent naming: brand_model_variant or brand_model
    if (variant.isNotEmpty) {
      return '${brand}_${model}_$variant';
    } else {
      return '${brand}_$model';
    }
  }
  
  // Check if Cloudinary is properly configured
  static bool get isConfigured {
    return dotenv.env['CLOUDINARY_CLOUD_NAME'] != null;
  }
  
  // Get placeholder image URL for missing images
  static String getPlaceholderImageUrl({int width = 400, int height = 300}) {
    return 'https://via.placeholder.com/${width}x$height/f0f0f0/999999?text=Car+Image';
  }
}