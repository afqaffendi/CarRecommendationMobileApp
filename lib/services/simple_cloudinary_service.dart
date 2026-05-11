import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/car.dart';
import 'cloudinary_image_map.dart';

/// Builds Cloudinary image URLs for car images.
///
/// Primary strategy — convention-based public ID derived from brand + model.
/// Naming rule: lowercase the brand and model, strip all non-alphanumeric chars,
/// join with underscore, prefix with the folder name.
///
///   Perodua Myvi 1.5 X  →  car-images/perodua_myvi15x
///   Honda Civic 1.5 V   →  car-images/honda_civic15v
///
/// To add a new car image: upload to Cloudinary with that public ID — no code change needed.
///
/// Fallback strategy — the legacy CloudinaryImageMap, which covers images that were
/// already uploaded with arbitrary public IDs (with random suffixes).
class CloudinaryImageService {
  static const String _baseUrl = 'https://res.cloudinary.com';
  static const String _folder = 'car-images';

  static String get _cloudName =>
      dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';

  static bool get isConfigured => _cloudName.isNotEmpty;

  /// Returns the best available image URL for [car] at the given [size].
  static String? getCarImageUrl(
    Car car, {
    int width = 400,
    int height = 300,
    String quality = 'auto',
  }) {
    if (!isConfigured) return null;

    // Strategy 1: convention-based public ID (new uploads should use this)
    final conventionId = _conventionPublicId(car);
    final conventionUrl = _buildUrl(conventionId, width, height, quality);

    // Strategy 2: legacy map (covers existing uploads with random suffixes)
    final legacyId = CloudinaryImageMap.getPublicId(car.brand, car.model, car.variant);
    if (legacyId != null) {
      final format = CloudinaryImageMap.getImageFormat(legacyId);
      final legacyUrl = '$_baseUrl/$_cloudName/image/upload/'
          'w_$width,h_$height,c_fill,q_$quality,f_auto/$legacyId.$format';
      // Return legacy URL — it is known to exist since it came from the map.
      return legacyUrl;
    }

    // Return convention URL — the widget will show the car icon if it 404s.
    return conventionUrl;
  }

  /// Returns thumbnail / medium / large / full size URLs.
  static Map<String, String?> getCarImageUrls(Car car) {
    return {
      'thumbnail': getCarImageUrl(car, width: 200, height: 150),
      'medium':    getCarImageUrl(car, width: 400, height: 300),
      'large':     getCarImageUrl(car, width: 800, height: 600),
      'full':      getCarImageUrl(car, width: 1200, height: 800),
    };
  }

  static bool hasImage(Car car) {
    return CloudinaryImageMap.hasImage(car.brand, car.model, car.variant);
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  /// Builds a Cloudinary URL for [publicId] with transformation params.
  static String _buildUrl(String publicId, int w, int h, String q) {
    return '$_baseUrl/$_cloudName/image/upload/w_$w,h_$h,c_fill,q_$q,f_auto/$publicId';
  }

  /// Derives a predictable public ID from the car's brand + full model string.
  /// Upload your images to Cloudinary using this exact ID to avoid map maintenance.
  static String _conventionPublicId(Car car) {
    final brand = _clean(car.brand);
    final model = _clean(car.model);
    return '$_folder/${brand}_$model';
  }

  static String _clean(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// Helper — call this to find out what public ID to use when uploading a car image.
  static String conventionPublicIdFor(String brand, String model) {
    final b = brand.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final m = model.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return '$_folder/${b}_$m';
  }
}
