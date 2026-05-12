import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/car.dart';
import '../services/simple_cloudinary_service.dart';

class CarImageWidget extends StatefulWidget {
  final Car car;
  final double width;
  final double height;
  final String size;
  final BorderRadius? borderRadius;

  const CarImageWidget({
    super.key,
    required this.car,
    this.width = 400,
    this.height = 300,
    this.size = 'medium',
    this.borderRadius,
  });

  @override
  State<CarImageWidget> createState() => _CarImageWidgetState();
}

class _CarImageWidgetState extends State<CarImageWidget> {
  late List<String> _candidates;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _buildCandidates();
  }

  @override
  void didUpdateWidget(CarImageWidget old) {
    super.didUpdateWidget(old);
    if (old.car.displayName != widget.car.displayName) {
      _buildCandidates();
    }
  }

  void _buildCandidates() {
    if (!CloudinaryImageService.isConfigured) {
      _candidates = [];
      _currentIndex = 0;
      return;
    }

    final (w, h) = switch (widget.size) {
      'thumbnail' => (200, 150),
      'large'     => (800, 600),
      'full'      => (1200, 800),
      _           => (400, 300),
    };

    _candidates = CloudinaryImageService.candidateUrls(widget.car, w, h);
    _currentIndex = 0;

    for (final url in _candidates) {
      debugPrint('🖼 [CarImage] candidate: $url');
    }
  }

  void _tryNext() {
    if (_currentIndex < _candidates.length - 1) {
      setState(() => _currentIndex++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(8);

    if (_candidates.isEmpty) return _fallback(radius);

    final url = _candidates[_currentIndex];
    final isLastCandidate = _currentIndex == _candidates.length - 1;

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: CachedNetworkImage(
          key: ValueKey(url),
          imageUrl: url,
          width: widget.width,
          height: widget.height,
          fit: BoxFit.cover,
          placeholder: (_, __) => _loading(),
          errorWidget: (_, __, ___) {
            if (!isLastCandidate) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _tryNext();
              });
              return _loading();
            }
            return _fallback(BorderRadius.zero);
          },
        ),
      ),
    );
  }

  Widget _loading() => Container(
        color: const Color(0xFFF0F0F0),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.black26),
          ),
        ),
      );

  Widget _fallback(BorderRadius radius) => ClipRRect(
        borderRadius: radius,
        child: Container(
          width: widget.width,
          height: widget.height,
          color: const Color(0xFFF0F0F0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.directions_car_rounded,
                    size: widget.width > 200 ? 40 : 28,
                    color: Colors.black12),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    widget.car.displayName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: widget.width > 200 ? 12 : 9,
                      color: Colors.black26,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
