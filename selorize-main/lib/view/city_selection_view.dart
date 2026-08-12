import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../repository/auth_repository.dart';
import '../view_model/auth_viewmodel.dart';

class CitySelectionView extends StatefulWidget {
  final bool isFromHome;

  const CitySelectionView({super.key, this.isFromHome = false});

  @override
  State<CitySelectionView> createState() => _CitySelectionViewState();
}

class _CitySelectionViewState extends State<CitySelectionView> {
  final AuthRepository _repo = AuthRepository();
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _cities = [];
  List<Map<String, dynamic>> _filteredCities = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchCities();
    _searchController.addListener(_filterCities);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchCities() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final responseData = await _repo.getData(
        tableName: 'website',
        filter: {},
      );

      List<Map<String, dynamic>> parsedCities = [];
      if (responseData.isNotEmpty) {
        final rawCitiesStr = responseData[0]['cities'];
        if (rawCitiesStr != null && rawCitiesStr.toString().isNotEmpty) {
          try {
            final decoded = jsonDecode(rawCitiesStr.toString());
            if (decoded is List) {
              parsedCities = decoded.map((e) => {'cityName': e.toString()}).toList();
            }
          } catch (e) {
            debugPrint("Error parsing cities JSON: $e");
          }
        }
      }
      
      final data = parsedCities;

      if (!mounted) return;

      setState(() {
        _cities = data;
        _filteredCities = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load cities: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _filterCities() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredCities = _cities.where((city) {
        final cityName = _getCityName(city).toLowerCase();
        return cityName.contains(query);
      }).toList();
    });
  }

  String _getCityName(Map<String, dynamic> cityData) {
    return (cityData['cityName'] ?? cityData['city_name'] ?? cityData['name'] ?? cityData['title'] ?? 'Unknown City').toString();
  }

  void _selectCity(String cityName) {
    final authVm = context.read<AuthViewModel>();
    authVm.setCity(cityName);

    if (widget.isFromHome) {
      Navigator.of(context).pop(); // Go back to Home
    }
    // If not from home, AuthGate will automatically rebuild and show Home because selectedCity is now set.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Select Your City', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: widget.isFromHome
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search city...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF4A78A8)),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? _buildErrorView()
                    : _buildCitiesGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'An error occurred.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _fetchCities,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A78A8),
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCitiesGrid() {
    if (_filteredCities.isEmpty) {
      return const Center(
        child: Text('No cities found.', style: TextStyle(color: Colors.grey, fontSize: 16)),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.0, // Square cells
      ),
      itemCount: _filteredCities.length,
      itemBuilder: (context, index) {
        final cityData = _filteredCities[index];
        final cityName = _getCityName(cityData);
        final imageUrl = cityData['image']?.toString() ?? cityData['icon']?.toString() ?? '';

        return InkWell(
          onTap: () => _selectCity(cityName),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (imageUrl.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Image.network(
                      imageUrl,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.location_city, size: 40, color: Colors.grey),
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8.0),
                    child: Icon(Icons.location_city, size: 40, color: Color(0xFF4A78A8)),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Text(
                    cityName,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
