import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/car.dart';
import 'cloudinary_image_map.dart';

class CloudinaryImageService {
  static const String baseUrl = 'https://res.cloudinary.com';
  
  // Generate Cloudinary URL for a car image using actual uploaded public IDs
  static String? getCarImageUrl(Car car, {int width = 400, int height = 300, String quality = 'auto'}) {
    final cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'];
    
    if (cloudName == null) {
      throw Exception('CLOUDINARY_CLOUD_NAME not found in environment variables');
    }
    
    // Get actual public ID from the mapping
    final publicId = CloudinaryImageMap.getPublicId(car.brand, car.model, car.variant);
    
    if (publicId == null) {
      return null; // No image available for this car
    }
    
    // Get the correct image format
    final format = CloudinaryImageMap.getImageFormat(publicId);
    
    // Generate Cloudinary URL with transformations
    final transformations = 'w_$width,h_$height,c_fill,q_$quality,f_auto';
    
    return '$baseUrl/$cloudName/image/upload/$transformations/$publicId.$format';
  }
  
  // Generate different sizes for different use cases
  static Map<String, String?> getCarImageUrls(Car car) {
    final baseUrl = getCarImageUrl(car);
    
    if (baseUrl == null) {
      return {
        'thumbnail': null,
        'medium': null,
        'large': null,
        'full': null,
      };
    }
    
    return {
      'thumbnail': getCarImageUrl(car, width: 200, height: 150),
      'medium': getCarImageUrl(car, width: 400, height: 300),
      'large': getCarImageUrl(car, width: 800, height: 600),
      'full': getCarImageUrl(car, width: 1200, height: 800),
    };
  }
  
  // Check if car has an image available
  static bool hasImage(Car car) {
    return CloudinaryImageMap.hasImage(car.brand, car.model, car.variant);
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

  // Alternative naming patterns you might have used in Cloudinary
  static List<String> generateAlternativePublicIds(Car car) {
    final brand = car.brand.toLowerCase();
    final model = car.model.toLowerCase();
    final variant = car.variant?.toLowerCase() ?? '';
    
    List<String> alternatives = [];
    
    // Pattern 1: Remove all non-alphanumeric (current)
    alternatives.add(generatePublicId(car));
    
    // Pattern 2: Replace spaces with underscores, keep periods as underscores
    String brandClean = brand.replaceAll(RegExp(r'[^a-z0-9.]'), '_').replaceAll('.', '_');
    String modelClean = model.replaceAll(RegExp(r'[^a-z0-9.]'), '_').replaceAll('.', '_');
    String variantClean = variant.replaceAll(RegExp(r'[^a-z0-9.]'), '_').replaceAll('.', '_');
    
    if (variantClean.isNotEmpty) {
      alternatives.add('${brandClean}_${modelClean}_$variantClean');
    } else {
      alternatives.add('${brandClean}_$modelClean');
    }
    
    // Pattern 3: Simple brand_model only (ignoring variant)
    alternatives.add('${brand.replaceAll(RegExp(r'[^a-z0-9]'), '')}_${model.replaceAll(RegExp(r'[^a-z0-9]'), '')}');
    
    // Pattern 4: Just the brand and first word of model
    String firstModelWord = model.split(' ').first.replaceAll(RegExp(r'[^a-z0-9]'), '');
    alternatives.add('${brand.replaceAll(RegExp(r'[^a-z0-9]'), '')}_$firstModelWord');
    
    // Remove duplicates
    return alternatives.toSet().toList();
  }

  // Try multiple URL patterns to find working images
  static List<String> getCarImageUrlAlternatives(Car car, {int width = 400, int height = 300, String quality = 'auto'}) {
    final cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'];
    if (cloudName == null) return [];
    
    final transformations = 'w_$width,h_$height,c_fill,q_$quality,f_auto';
    final alternatives = generateAlternativePublicIds(car);
    
    return alternatives.map((publicId) => 
      '$baseUrl/$cloudName/image/upload/$transformations/$publicId.jpg'
    ).toList();
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
