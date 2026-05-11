import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/car.dart';
import '../../services/image_management_service.dart';

class CarManagementScreen extends StatefulWidget {
  const CarManagementScreen({super.key});

  @override
  State<CarManagementScreen> createState() => _CarManagementScreenState();
}

class _CarManagementScreenState extends State<CarManagementScreen> {
  final _searchController = TextEditingController();
  String _selectedBrand = 'All';
  String _selectedType = 'All';
  List<String> _brands = ['All'];
  List<String> _types = ['All'];

  @override
  void initState() {
    super.initState();
    _fetchFilterOptions();
  }

  Future<void> _fetchFilterOptions() async {
    final carsSnapshot = await FirebaseFirestore.instance.collection('cars').get();
    final cars = carsSnapshot.docs.map((doc) => Car.fromFirestore(doc)).toList();
    setState(() {
      _brands = ['All', ...cars.map((c) => c.brand).toSet().toList()..sort()];
      _types = ['All', ...cars.map((c) => c.type).toSet().toList()..sort()];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Car Database Management'),
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: _buildCarList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Search by model',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
            onChanged: (value) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedBrand,
                  items: _brands.map((brand) {
                    return DropdownMenuItem(value: brand, child: Text(brand));
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedBrand = value);
                    }
                  },
                  decoration: const InputDecoration(
                    labelText: 'Brand',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedType,
                  items: _types.map((type) {
                    return DropdownMenuItem(value: type, child: Text(type));
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedType = value);
                    }
                  },
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCarList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('cars').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Error loading cars.'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final cars = snapshot.data!.docs
            .map((doc) => Car.fromFirestore(doc))
            .where(_filterCars)
            .toList();

        return ListView.builder(
          itemCount: cars.length,
          itemBuilder: (context, index) {
            final car = cars[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                leading: car.imageUrl != null
                    ? Image.network(car.imageUrl!, width: 50, height: 50, fit: BoxFit.cover)
                    : const Icon(Icons.directions_car, size: 40),
                title: Text(car.displayName),
                subtitle: Text('${car.type} - ${car.brand}'),
                trailing: IconButton(
                  icon: const Icon(Icons.upload_file),
                  onPressed: () => _uploadImage(car),
                ),
              ),
            );
          },
        );
      },
    );
  }

  bool _filterCars(Car car) {
    final search = _searchController.text.toLowerCase();
    final brandMatch = _selectedBrand == 'All' || car.brand == _selectedBrand;
    final typeMatch = _selectedType == 'All' || car.type == _selectedType;
    final searchMatch = search.isEmpty || car.model.toLowerCase().contains(search);
    return brandMatch && typeMatch && searchMatch;
  }

  Future<void> _uploadImage(Car car) async {
    final imageFile = await ImageManagementService.pickImageFromGallery();

    if (imageFile != null) {
      try {
        final success = await ImageManagementService.uploadCarImage(car: car, imageFile: imageFile);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Image uploaded successfully for ${car.displayName}')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image upload failed.')),
          );
        }
        // The stream will rebuild the list with the new image
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image upload failed: $e')),
        );
      }
    }
  }
}
