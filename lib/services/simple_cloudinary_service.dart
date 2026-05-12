import 'package:flutter/foundation.dart';
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
    debugPrint('🖼 [Cloudinary] trying: $conventionUrl');
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

  /// Returns all candidate URLs to try for a car, in order of most likely match.
  static List<String> candidateUrls(Car car, int w, int h) {
    if (!isConfigured) return [];
    const base = 'https://res.cloudinary.com';
    const t = 'c_fill,q_auto,f_auto';

    // Legacy map — known-good URLs with random suffix.
    final legacyId = CloudinaryImageMap.getPublicId(car.brand, car.model, car.variant);
    if (legacyId != null) {
      final fmt = CloudinaryImageMap.getImageFormat(legacyId);
      return ['$base/$_cloudName/image/upload/w_$w,h_$h,$t/$legacyId.$fmt'];
    }

    // Convention candidates — try every pattern without extension (f_auto handles format).
    return candidatePublicIds(car)
        .map((id) => '$base/$_cloudName/image/upload/w_$w,h_$h,$t/$id')
        .toList();
  }

  /// Returns all candidate public IDs to try for a car, from most to least specific.
  static List<String> candidatePublicIds(Car car) {
    final brand = _clean(car.brand);
    final model = _clean(car.model);

    // If the model starts with the brand name, also try a version without it.
    final modelWithoutBrand = model.startsWith(brand)
        ? model.substring(brand.length)
        : model;

    return [
      // e.g. audi_audia3sedan20tfsissline  (brand + full model)
      '${brand}_$model',
      // e.g. audi_a3sedan20tfsissline      (brand + model minus leading brand)
      if (modelWithoutBrand != model) '${brand}_$modelWithoutBrand',
      // e.g. audia3sedan20tfsissline        (full model only)
      model,
      // e.g. a3sedan20tfsissline            (model minus leading brand)
      if (modelWithoutBrand != model) modelWithoutBrand,
    ]; // ordered by most likely match
  }

  static String _conventionPublicId(Car car) => candidatePublicIds(car).first;

  static String _clean(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// Helper — call this to find out what public ID to use when uploading a car image.
  static String conventionPublicIdFor(String brand, String model) {
    final b = brand.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final m = model.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final mNoBrand = m.startsWith(b) ? m.substring(b.length) : m;
    return '${b}_$mNoBrand';
  }
}
