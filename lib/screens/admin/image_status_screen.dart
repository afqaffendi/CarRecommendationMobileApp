import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/car.dart';
import '../../services/firestore_service.dart';
import '../../services/simple_cloudinary_service.dart';

class ImageStatusScreen extends StatefulWidget {
  const ImageStatusScreen({super.key});

  @override
  State<ImageStatusScreen> createState() => _ImageStatusScreenState();
}

class _ImageStatusScreenState extends State<ImageStatusScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final FirestoreService _firestore = FirestoreService();

  bool _isLoading = true;
  List<Car> _missing = [];
  List<Car> _covered = [];
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final cars = await _firestore.getCars();

    final missing = <Car>[];
    final covered = <Car>[];

    for (final car in cars) {
      if (CloudinaryImageService.hasImage(car)) {
        covered.add(car);
      } else {
        missing.add(car);
      }
    }

    missing.sort((a, b) => a.brand.compareTo(b.brand));
    covered.sort((a, b) => a.brand.compareTo(b.brand));

    setState(() {
      _missing = missing;
      _covered = covered;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Image Status', style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.black38,
          indicatorColor: Colors.black,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.image_not_supported_rounded, size: 16),
                  const SizedBox(width: 6),
                  Text('Missing (${_missing.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_rounded, size: 16),
                  const SizedBox(width: 6),
                  Text('Done (${_covered.length})'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : Column(
              children: [
                _buildSearchBar(),
                _buildSummaryBanner(),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _buildMissingList(),
                      _buildCoveredList(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: TextField(
        onChanged: (v) => setState(() => _filter = v.toLowerCase()),
        decoration: InputDecoration(
          hintText: 'Search brand or model...',
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.black),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryBanner() {
    final total = _missing.length + _covered.length;
    final pct = total == 0 ? 0.0 : _covered.length / total;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${_covered.length} / $total cars have images',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const Spacer(),
              Text(
                '${(pct * 100).toStringAsFixed(0)}%',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: Colors.black.withValues(alpha: 0.08),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMissingList() {
    final filtered = _missing
        .where((c) =>
            _filter.isEmpty ||
            c.brand.toLowerCase().contains(_filter) ||
            c.model.toLowerCase().contains(_filter))
        .toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_rounded, size: 56, color: Colors.black26),
            const SizedBox(height: 12),
            Text(
              _filter.isEmpty ? 'All cars have images!' : 'No results',
              style: const TextStyle(fontSize: 16, color: Colors.black45),
            ),
          ],
        ),
      );
    }

    // Group by brand
    final byBrand = <String, List<Car>>{};
    for (final car in filtered) {
      byBrand.putIfAbsent(car.brand, () => []).add(car);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: Colors.orange),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tap any row to copy the public ID. Use it as the filename when uploading to Cloudinary.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
            ],
          ),
        ),
        ...byBrand.entries.map((entry) => _buildBrandGroup(
              brand: entry.key,
              cars: entry.value,
              missing: true,
            )),
      ],
    );
  }

  Widget _buildCoveredList() {
    final filtered = _covered
        .where((c) =>
            _filter.isEmpty ||
            c.brand.toLowerCase().contains(_filter) ||
            c.model.toLowerCase().contains(_filter))
        .toList();

    if (filtered.isEmpty) {
      return const Center(
        child: Text('No results', style: TextStyle(color: Colors.black45)),
      );
    }

    final byBrand = <String, List<Car>>{};
    for (final car in filtered) {
      byBrand.putIfAbsent(car.brand, () => []).add(car);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: byBrand.entries
          .map((e) => _buildBrandGroup(brand: e.key, cars: e.value, missing: false))
          .toList(),
    );
  }

  Widget _buildBrandGroup({
    required String brand,
    required List<Car> cars,
    required bool missing,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            brand,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.black45,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          ),
          child: Column(
            children: cars.asMap().entries.map((entry) {
              final i = entry.key;
              final car = entry.value;
              final isLast = i == cars.length - 1;
              return _buildCarRow(car, missing: missing, isLast: isLast);
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildCarRow(Car car, {required bool missing, required bool isLast}) {
    final publicId = _publicIdFor(car);

    return InkWell(
      onTap: missing ? () => _copyPublicId(publicId, car) : null,
      borderRadius: isLast
          ? const BorderRadius.vertical(bottom: Radius.circular(14))
          : BorderRadius.zero,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(
                  bottom: BorderSide(
                    color: Colors.black.withValues(alpha: 0.05),
                  ),
                ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: missing
                    ? Colors.orange.withValues(alpha: 0.1)
                    : Colors.green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                missing
                    ? Icons.image_not_supported_rounded
                    : Icons.check_rounded,
                size: 16,
                color: missing ? Colors.orange : Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    car.model,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  if (missing)
                    Text(
                      publicId,
                      style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black38,
                          fontFamily: 'monospace'),
                    ),
                ],
              ),
            ),
            if (missing)
              const Icon(Icons.copy_rounded, size: 16, color: Colors.black26),
          ],
        ),
      ),
    );
  }

  String _publicIdFor(Car car) {
    return CloudinaryImageService.conventionPublicIdFor(car.brand, car.model);
  }

  void _copyPublicId(String publicId, Car car) {
    Clipboard.setData(ClipboardData(text: publicId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied: $publicId'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
