import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/car.dart';
import '../services/simple_cloudinary_service.dart';

class CarImageWidget extends StatelessWidget {
  final Car car;
  final double width;
  final double height;
  final String size; // 'thumbnail', 'medium', 'large', or 'full'
  final BorderRadius? borderRadius;

  const CarImageWidget({
    Key? key,
    required this.car,
    this.width = 400,
    this.height = 300,
    this.size = 'medium',
    this.borderRadius,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!CloudinaryImageService.isConfigured) {
      return _buildErrorWidget('Cloudinary not configured');
    }

    String imageUrl;
    try {
      final urls = CloudinaryImageService.getCarImageUrls(car);
      imageUrl = urls[size] ?? urls['medium']!;
    } catch (e) {
      return _buildErrorWidget('Error generating image URL');
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? BorderRadius.circular(8),
        color: Colors.grey[200],
      ),
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          width: width,
          height: height,
          fit: BoxFit.cover,
          placeholder: (context, url) => _buildLoadingWidget(),
          errorWidget: (context, url, error) => _buildFallbackWidget(),
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(height: 8),
            Text(
              'Loading...',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackWidget() {
    return Container(
      color: Colors.grey[100],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.car_rental,
              size: width > 200 ? 48 : 32,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '${car.brand}\n${car.model}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: width > 200 ? 14 : 10,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget(String message) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? BorderRadius.circular(8),
        color: Colors.red[50],
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, color: Colors.red[400], size: 32),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(fontSize: 12, color: Colors.red[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}