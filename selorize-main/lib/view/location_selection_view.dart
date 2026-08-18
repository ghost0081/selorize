import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../repository/auth_repository.dart';
import '../view_model/auth_viewmodel.dart';
import '../res/api_constants.dart';

class LocationSelectionView extends StatefulWidget {
  final String stateId;
  final String stateName;
  final bool isFromHome;

  const LocationSelectionView({
    super.key,
    required this.stateId,
    required this.stateName,
    this.isFromHome = false,
  });

  @override
  State<LocationSelectionView> createState() => _LocationSelectionViewState();
}

class _LocationSelectionViewState extends State<LocationSelectionView> {
  final AuthRepository _repo = AuthRepository();
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _locations = [];
  List<Map<String, dynamic>> _filteredLocations = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchLocations();
    _searchController.addListener(_filterLocations);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchLocations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final responseData = await _repo.getData(
        tableName: 'locations',
        filter: {'stateId': widget.stateId},
      );
      
      final data = responseData.cast<Map<String, dynamic>>();

      if (!mounted) return;

      setState(() {
        _locations = data;
        _filteredLocations = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load locations: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _filterLocations() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredLocations = _locations.where((location) {
        final locationName = _getLocationName(location).toLowerCase();
        return locationName.contains(query);
      }).toList();
    });
  }

  String _getLocationName(Map<String, dynamic> locationData) {
    return (locationData['locationName'] ?? 'Unknown Location').toString();
  }

  void _selectLocation(String locationName) {
    final authVm = context.read<AuthViewModel>();
    authVm.setLocation(locationName, widget.stateName);

    if (widget.isFromHome) {
      // Pop both LocationSelection and StateSelection to get back to home
      Navigator.of(context).pop(); 
      Navigator.of(context).pop(); 
    } else {
      // If not from home, AuthGate will automatically rebuild and show Home because selectedCity is now set.
      // But we still need to pop off the location view if it was pushed on top of state view.
      // AuthGate replaces the entire navigation stack when city is set, but just in case:
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Select Location in ${widget.stateName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search location...',
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
                    : _buildLocationsGrid(),
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
              onPressed: _fetchLocations,
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

  Widget _buildLocationsGrid() {
    if (_filteredLocations.isEmpty) {
      return const Center(
        child: Text('No locations found.', style: TextStyle(color: Colors.grey, fontSize: 16)),
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
      itemCount: _filteredLocations.length,
      itemBuilder: (context, index) {
        final locationData = _filteredLocations[index];
        final locationName = _getLocationName(locationData);
        final iconPath = locationData['locationIcon']?.toString() ?? '';
        final imageUrl = iconPath.isNotEmpty ? '${ApiConstants.MEDIA_BASE_URL}$iconPath' : '';

        return InkWell(
          onTap: () => _selectLocation(locationName),
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
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      width: 40,
                      height: 40,
                      fit: BoxFit.contain,
                      errorWidget: (context, url, error) =>
                          const Icon(Icons.location_on_outlined, size: 40, color: Colors.grey),
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8.0),
                    child: Icon(Icons.location_on_outlined, size: 40, color: Color(0xFF4A78A8)),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Text(
                    locationName,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF333333),
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
