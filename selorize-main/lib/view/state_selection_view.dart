import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../repository/auth_repository.dart';
import '../res/api_constants.dart';
import 'location_selection_view.dart';

class StateSelectionView extends StatefulWidget {
  final bool isFromHome;

  const StateSelectionView({super.key, this.isFromHome = false});

  @override
  State<StateSelectionView> createState() => _StateSelectionViewState();
}

class _StateSelectionViewState extends State<StateSelectionView> {
  final AuthRepository _repo = AuthRepository();
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _states = [];
  List<Map<String, dynamic>> _filteredStates = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchStates();
    _searchController.addListener(_filterStates);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchStates() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final responseData = await _repo.getData(
        tableName: 'operationalState',
        filter: {},
      );
      
      final data = responseData.cast<Map<String, dynamic>>();

      if (!mounted) return;

      setState(() {
        _states = data;
        _filteredStates = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load states: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _filterStates() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredStates = _states.where((state) {
        final stateName = _getStateName(state).toLowerCase();
        return stateName.contains(query);
      }).toList();
    });
  }

  String _getStateName(Map<String, dynamic> stateData) {
    return (stateData['name'] ?? 'Unknown State').toString();
  }

  void _selectState(Map<String, dynamic> stateData) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LocationSelectionView(
          stateId: stateData['id'].toString(),
          stateName: _getStateName(stateData),
          isFromHome: widget.isFromHome,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Select Your State', style: TextStyle(fontWeight: FontWeight.bold)),
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
                hintText: 'Search state...',
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
                    : _buildStatesGrid(),
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
              onPressed: _fetchStates,
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

  Widget _buildStatesGrid() {
    if (_filteredStates.isEmpty) {
      return const Center(
        child: Text('No states found.', style: TextStyle(color: Colors.grey, fontSize: 16)),
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
      itemCount: _filteredStates.length,
      itemBuilder: (context, index) {
        final stateData = _filteredStates[index];
        final stateName = _getStateName(stateData);
        final iconPath = stateData['icon']?.toString() ?? '';
        final imageUrl = iconPath.isNotEmpty ? '${ApiConstants.MEDIA_BASE_URL}$iconPath' : '';

        return InkWell(
          onTap: () => _selectState(stateData),
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
                          const Icon(Icons.map_outlined, size: 40, color: Colors.grey),
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8.0),
                    child: Icon(Icons.map_outlined, size: 40, color: Color(0xFF4A78A8)),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Text(
                    stateName,
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
