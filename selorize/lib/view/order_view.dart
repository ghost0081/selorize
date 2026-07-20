import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../repository/auth_repository.dart';
import '../view_model/auth_viewmodel.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class OrdersScreen extends StatefulWidget {
  final List<Map<String, dynamic>> orders;
  final Function(String id, String reason)? onCancelOrder;
  final VoidCallback? onNavigateToCancelledOrders;
  final VoidCallback? onNavigateToAllOrders;
  final String? initialTab;
  const OrdersScreen({
    super.key,
    required this.orders,
    this.onCancelOrder,
    this.onNavigateToCancelledOrders,
    this.onNavigateToAllOrders,
    this.initialTab,
  });

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final AuthRepository _repo = AuthRepository();
  String _selectedTab = 'All Orders';
  Map<String, dynamic>? _selectedOrder;

  // Rescheduling Flow States
  bool _showAddressSelection = false;
  bool _showAddAddress = false;
  bool _showPickupType = false;
  bool _showSuccess = false;
  bool _showCancelScreen = false;
  String? _selectedCancelReason;
  bool _showCancelSuccess = false;
  String _confirmedCancelReason = '';
  final TextEditingController _feedbackController = TextEditingController();
  final TextEditingController _otherCancelReasonController =
      TextEditingController();
  final TextEditingController _addressNameController = TextEditingController();
  final TextEditingController _addressMobileController =
      TextEditingController();
  final TextEditingController _addressHouseController = TextEditingController();
  final TextEditingController _addressStreetController =
      TextEditingController();
  final TextEditingController _addressCityController = TextEditingController();
  final TextEditingController _addressStateController = TextEditingController();
  final TextEditingController _addressPincodeController =
      TextEditingController();
  List<Map<String, dynamic>> _savedAddresses = [];
  Map<String, dynamic>? _selectedPickupAddress;
  bool _isLoadingAddresses = false;
  bool _isSavingAddress = false;
  String _addressType = 'Home';
  // State variables add karo
  final MapController _mapController = MapController();
  Timer? _mapMoveDebounce;
  String _pickupLatitude = '';
  String _pickupLongitude = '';
  bool _isFetchingLocation = false;
  bool _isFetchingAddress = false;
  bool _isFetchingManualLocation = false;
  String _fetchedAddress = '';
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  Map<String, String>? _supportContact;

  Map<String, String> _agentInfoFromRawItem(Map<String, dynamic> item) {
    final raw = item['rawEnquiry'];
    if (raw is! Map) return {'name': '', 'mobile': ''};
    final source = Map<String, dynamic>.from(raw);

    String valueFrom(List<String> keys) {
      for (final key in keys) {
        final value = source[key]?.toString().trim() ?? '';
        if (value.isNotEmpty) return value;
      }
      return '';
    }

    Map<String, dynamic>? parsePayload(dynamic value) {
      if (value is Map) return Map<String, dynamic>.from(value);
      if (value is! String || value.trim().isEmpty) return null;

      var text = value
          .trim()
          .replaceAll('&quot;', '"')
          .replaceAll('&#34;', '"')
          .replaceAll(r'\"', '"');
      final start = text.indexOf('{');
      final end = text.lastIndexOf('}');
      if (start == -1 || end <= start) return null;
      text = text.substring(start, end + 1);

      try {
        final decoded = jsonDecode(text);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        final name = RegExp(
          r'''["']name["']\s*:\s*["']([^"']+)["']''',
        ).firstMatch(text)?.group(1);
        final mobile = RegExp(
          r'''["'](?:mobile|contact|phone|number)["']\s*:\s*["']?([0-9+\-\s]+)["']?''',
        ).firstMatch(text)?.group(1);
        if (name != null || mobile != null) {
          final parsed = <String, dynamic>{};
          if (name != null) parsed['name'] = name;
          if (mobile != null) parsed['mobile'] = mobile;
          return parsed;
        }
      }
      return null;
    }

    const nameKeys = [
      'agentName',
      'agent_name',
      'assignedAgentName',
      'assigned_agent_name',
      'pickupAgentName',
      'pickup_agent_name',
    ];
    const mobileKeys = [
      'agentMobile',
      'agent_mobile',
      'agentContact',
      'agent_contact',
      'agentPhone',
      'agent_phone',
      'pickupAgentMobile',
      'pickup_agent_mobile',
      'agentNumber',
      'agent_number',
      'contactNumber',
      'contact_number',
      'mobileNumber',
      'mobile_number',
    ];

    final directName = valueFrom(nameKeys);
    final directMobile = valueFrom(mobileKeys);
    if (directName.isNotEmpty || directMobile.isNotEmpty) {
      return {'name': directName, 'mobile': directMobile};
    }

    for (final value in source.values) {
      final parsed = parsePayload(value);
      final name = parsed?['name']?.toString().trim() ?? '';
      final mobile =
          parsed?['mobile']?.toString().trim() ??
          parsed?['contact']?.toString().trim() ??
          parsed?['phone']?.toString().trim() ??
          '';
      if (name.isNotEmpty || mobile.isNotEmpty) {
        return {'name': name, 'mobile': mobile};
      }
    }

    return {'name': '', 'mobile': ''};
  }

  // Local State for Rescheduling UI
  bool isInstantPickup = false;
  String currentOrderID = "";
  DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
  DateTime _displayMonth = DateTime.now();
  bool _showCalendarGrid = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialTab != null) {
      _selectedTab = widget.initialTab!;
    }
    final user = context.read<AuthViewModel>().loggedInUser;
    _addressNameController.text = user?.name ?? '';
    _addressMobileController.text = user?.mobile ?? '';
    _loadSavedAddresses();
    _fetchCurrentLocation();
  }

  @override
  void dispose() {
    _mapMoveDebounce?.cancel();
    _feedbackController.dispose();
    _otherCancelReasonController.dispose();
    _addressNameController.dispose();
    _addressMobileController.dispose();
    _addressHouseController.dispose();
    _addressStreetController.dispose();
    _addressCityController.dispose();
    _addressStateController.dispose();
    _addressPincodeController.dispose();
    _searchController.dispose();

    super.dispose();
  }

  String _formatAddress(Map<String, dynamic>? address) {
    if (address == null) return 'Select pickup address';
    final fullAddress =
        address['fullAddress']?.toString().trim() ??
        address['address']?.toString().trim() ??
        '';
    if (fullAddress.isNotEmpty) return fullAddress;
    final parts =
        [
              address['houseNo'] ?? address['house'],
              address['street'] ?? address['area'],
              address['city'],
              address['state'],
            ]
            .map((value) => value?.toString().trim() ?? '')
            .where((value) => value.isNotEmpty)
            .toList();
    final pincode = address['pincode']?.toString().trim() ?? '';
    return [
      parts.join(', '),
      if (pincode.isNotEmpty) pincode,
    ].where((value) => value.trim().isNotEmpty).join(' - ');
  }

  String _addressTypeLabel(Map<String, dynamic>? address) {
    return address?['addressType']?.toString().trim().isNotEmpty == true
        ? address!['addressType'].toString()
        : address?['type']?.toString().trim().isNotEmpty == true
        ? address!['type'].toString()
        : 'Saved Address';
  }

  bool _isCurrentLocationAddress(Map<String, dynamic>? address) {
    final addressType =
        address?['addressType']?.toString().trim().toUpperCase() ??
        address?['type']?.toString().trim().toUpperCase() ??
        '';
    return addressType == 'GPS';
  }

  Widget _buildModernAddressSelector() {
    final hasMultipleAddresses = _savedAddresses.length > 1;

    final isGpsSelected =
        _selectedPickupAddress != null &&
        (_selectedPickupAddress!['id']?.toString() ?? '').isEmpty;
    final dropdownValue = isGpsSelected ? null : _selectedPickupAddress;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            height: 42,
            width: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF4267B2).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.location_on_rounded,
              color: Color(0xFF4267B2),
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _isLoadingAddresses
                ? const Text(
                    "Loading saved addresses...",
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF475569),
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : hasMultipleAddresses
                ? DropdownButtonHideUnderline(
                    child: DropdownButton<Map<String, dynamic>>(
                      value: dropdownValue,
                      hint: const Text(
                        'Select saved address',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      isExpanded: true,
                      borderRadius: BorderRadius.circular(18),
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Color(0xFF4267B2),
                      ),
                      dropdownColor: Colors.white,
                      itemHeight: 60,
                      menuMaxHeight: 320,
                      selectedItemBuilder: (context) => _savedAddresses
                          .map((address) => _buildAddressSelectionText(address))
                          .toList(),
                      items: _savedAddresses.map((address) {
                        return DropdownMenuItem<Map<String, dynamic>>(
                          value: address,
                          child: _buildAddressSelectionText(address),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedPickupAddress = value);
                      },
                    ),
                  )
                : _buildAddressSelectionText(
                    isGpsSelected ? null : _selectedPickupAddress,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressSelectionText(Map<String, dynamic>? address) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _addressTypeLabel(address),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _formatAddress(address),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            height: 1.15,
          ),
        ),
      ],
    );
  }

  Future<void> _loadSavedAddresses() async {
    final userId = context.read<AuthViewModel>().loggedInUser?.id ?? '';
    if (userId.isEmpty) return;

    setState(() => _isLoadingAddresses = true);
    try {
      final addresses = await _repo.getData(
        tableName: 'address',
        filter: {'userId': userId},
      );
      if (!mounted) return;
      setState(() {
        _savedAddresses = addresses;
        if (addresses.isNotEmpty) {
          _selectedPickupAddress ??= addresses.first;
        }
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingAddresses = false);
      }
    }
  }

  Future<void> _savePickupAddress() async {
    if (_isSavingAddress) return;

    final userId = context.read<AuthViewModel>().loggedInUser?.id ?? '';
    final name = _addressNameController.text.trim();
    final mobile = _addressMobileController.text.trim();
    final houseNo = _addressHouseController.text.trim();
    final street = _addressStreetController.text.trim();
    final city = _addressCityController.text.trim();
    final state = _addressStateController.text.trim();
    final pincode = _addressPincodeController.text.trim();

    if (userId.isEmpty ||
        name.isEmpty ||
        mobile.isEmpty ||
        houseNo.isEmpty ||
        street.isEmpty ||
        city.isEmpty ||
        state.isEmpty ||
        pincode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all address details.')),
      );
      return;
    }

    setState(() => _isSavingAddress = true);
    try {
      final success = await context.read<AuthViewModel>().saveAddress(
        userId: userId,
        name: name,
        mobile: mobile,
        pincode: pincode,
        city: city,
        state: state,
        houseNo: houseNo,
        street: street,
        addressType: _addressType,
      );

      if (!mounted) return;
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save address.')),
        );
        return;
      }

      final address = <String, dynamic>{
        'userId': userId,
        'name': name,
        'mobile': mobile,
        'houseNo': houseNo,
        'street': street,
        'city': city,
        'state': state,
        'pincode': pincode,
        'addressType': _addressType,
      };

      setState(() {
        _savedAddresses.add(address);
        _selectedPickupAddress = address;
        _showAddAddress = false;
        _showAddressSelection = true;
      });
    } finally {
      if (mounted) {
        setState(() => _isSavingAddress = false);
      }
    }
  }

  void _confirmPickupAddress() {
    if (_selectedPickupAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add or select pickup address.')),
      );
      return;
    }
    if (_isCurrentLocationAddress(_selectedPickupAddress) &&
        (_pickupLatitude.isEmpty || _pickupLongitude.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location not fetched yet. Please wait or tap Retry.'),
          backgroundColor: Colors.orange,
        ),
      );
      _fetchCurrentLocation();
      return;
    }
    setState(() => _showPickupType = true);
  }

  // Helper to format date
  String _getFormattedDate(String? rawDate) {
    if (rawDate == null || rawDate.toLowerCase() == 'now' || rawDate.isEmpty) {
      return DateFormat('dd / MMMM / yyyy').format(DateTime.now());
    }
    final parsed = DateTime.tryParse(rawDate);
    if (parsed != null) {
      return DateFormat('dd / MMMM / yyyy hh:mm a').format(parsed);
    }
    return rawDate;
  }

  String _pickupDateText(Map<String, dynamic> item) {
    final pickupDate = item['pickupDateTime']?.toString() ?? '';
    return _getFormattedDate(pickupDate.isNotEmpty ? pickupDate : item['date']);
  }

  String _formatPriceValue(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return '0';
    return raw.replaceFirst(RegExp(r'\.00$'), '');
  }

  void _finalizeReschedule() {
    setState(() {
      if (_selectedOrder != null) {
        int index = widget.orders.indexWhere(
          (o) => o['id'] == _selectedOrder!['id'],
        );
        if (index != -1) {
          widget.orders[index]['date'] = isInstantPickup
              ? "Today"
              : DateFormat('dd / MMMM / yyyy').format(selectedDate);
          widget.orders[index]['pickupDateTime'] = isInstantPickup
              ? DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())
              : DateFormat('yyyy-MM-dd HH:mm:ss').format(selectedDate);
          widget.orders[index]['address'] = _formatAddress(
            _selectedPickupAddress,
          );
          if (_isCurrentLocationAddress(_selectedPickupAddress)) {
            widget.orders[index]['latitude'] = _pickupLatitude;
            widget.orders[index]['longitude'] = _pickupLongitude;
          } else {
            widget.orders[index]['latitude'] = '';
            widget.orders[index]['longitude'] = '';
          }
        }
      }
      _showPickupType = false;
      _showSuccess = true;
    });
  }

  // Function to reset all rescheduling states
  void _resetRescheduleFlow() {
    setState(() {
      _showAddressSelection = false;
      _showAddAddress = false;
      _showPickupType = false;
      _showSuccess = false;
      _showCancelScreen = false;
      _showCancelSuccess = false;
      _selectedOrder = null;
      _showCalendarGrid = true;
      _selectedCancelReason = null;
      _feedbackController.clear();
      _otherCancelReasonController.clear();
    });
  }

  bool _canCancelOrReschedule(Map<String, dynamic>? item) {
    final status = item?['status']?.toString().trim().toLowerCase() ?? '';
    return status == 'pending' || status.isEmpty;
  }

  bool get _hasInternalBackState =>
      _showCalendarGrid ||
      _showCancelSuccess ||
      _showSuccess ||
      _showCancelScreen ||
      _showPickupType ||
      _showAddAddress ||
      _showAddressSelection ||
      _selectedOrder != null;

  void _handleBack() {
    setState(() {
      if (_showCalendarGrid) {
        _showCalendarGrid = false;
      } else if (_showCancelSuccess) {
        _showCancelSuccess = false;
        _selectedOrder = null;
      } else if (_showSuccess) {
        _showSuccess = false;
        _selectedOrder = null;
      } else if (_showCancelScreen) {
        _showCancelScreen = false;
      } else if (_showPickupType) {
        _showPickupType = false;
      } else if (_showAddAddress) {
        _showAddAddress = false;
      } else if (_showAddressSelection) {
        _showAddressSelection = false;
      } else if (_selectedOrder != null) {
        _selectedOrder = null;
      }
    });
  }

  String get _supportOrderId {
    final selectedId = _selectedOrder?['id']?.toString() ?? '';
    if (selectedId.isNotEmpty) return selectedId;
    return currentOrderID.isNotEmpty ? currentOrderID : 'N/A';
  }

  Future<Map<String, String>> _loadSupportContact() async {
    final cached = _supportContact;
    if (cached != null) return cached;

    final contact = await _repo.getSupportContact();
    if (mounted) setState(() => _supportContact = contact);
    return contact;
  }

  String _dialNumber(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) return '+91$digits';
    return digits.isNotEmpty ? '+$digits' : '';
  }

  Future<void> _launchContact(String type) async {
    Uri uri;
    final orderId = _supportOrderId;
    final contact = await _loadSupportContact();

    if (type == 'call') {
      final mobile = _dialNumber(contact['mobile'] ?? '');
      if (mobile.isEmpty) {
        _showSupportUnavailable();
        return;
      }
      uri = Uri.parse('tel:$mobile');
    } else if (type == 'whatsapp') {
      final whatsapp = _dialNumber(contact['whatsapp'] ?? '');
      if (whatsapp.isEmpty) {
        _showSupportUnavailable();
        return;
      }
      String message = "Hello SeloRize, I need help with my Order #$orderId";
      String url =
          "https://wa.me/${whatsapp.replaceAll('+', '')}?text=${Uri.encodeComponent(message)}";
      uri = Uri.parse(url);
    } else {
      final email = contact['email'] ?? '';
      if (email.isEmpty || email.toLowerCase() == 'null') {
        _showSupportUnavailable();
        return;
      }
      uri = Uri.parse("mailto:$email?subject=Support for Order $orderId");
    }

    try {
      bool launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        debugPrint("Could not launch $uri");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Required app is not installed.")),
          );
        }
      }
    } catch (e) {
      debugPrint("Error triggering support: $e");
    }
  }

  void _showSupportUnavailable() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Support contact is not available.")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasInternalBackState,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBack();
      },
      child: _buildCurrentScreen(),
    );
  }

  Widget _buildCurrentScreen() {
    //  RESCHEDULE & CANCEL FLOW

    if (_showCancelSuccess) {
      return _buildCancelSuccessScreen();
    }

    if (_showSuccess) {
      return _buildSuccessScreen();
    }

    if (_showCancelScreen) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: _buildCancelScreen(),
      );
    }

    if (_showPickupType) {
      return _buildPickupTypeScreen();
    }

    if (_showAddAddress) {
      return _buildAddAddressScreen();
    }

    if (_showAddressSelection) {
      return _buildAddressSelectionScreen();
    }

    // NORMAL VIEW LOGIC

    if (_selectedOrder != null && !_showAddressSelection) {
      return _buildOrderDetailsScreen(_selectedOrder!);
    }

    List<Map<String, dynamic>> displayedOrders = widget.orders;
    if (_selectedTab != 'All Orders') {
      displayedOrders = widget.orders
          .where((o) => o['status'] == _selectedTab.replaceFirst(' Orders', ''))
          .toList();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          const SizedBox(height: 16),
          _buildTabSection(),
          const SizedBox(height: 12),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: displayedOrders.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      key: ValueKey(_selectedTab),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: displayedOrders.length,
                      itemBuilder: (context, index) =>
                          _buildOrderCard(displayedOrders[index]),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  //  1. ADDRESS & PICKUP (MAP SCREEN)
  Widget _buildAddressSelectionScreen() {
    final bool locationReady =
        _pickupLatitude.isNotEmpty && _pickupLongitude.isNotEmpty;
    final double lat = locationReady
        ? double.tryParse(_pickupLatitude) ?? 20.5937
        : 20.5937;
    final double lng = locationReady
        ? double.tryParse(_pickupLongitude) ?? 78.9629
        : 78.9629;

    final bool gpsAddressSelected =
        _selectedPickupAddress != null &&
        (_selectedPickupAddress!['id']?.toString() ?? '').isEmpty;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Real Map
          if (_isFetchingLocation || !locationReady)
            Container(
              color: const Color(0xFFF1F5F9),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _isFetchingLocation
                          ? const SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Color(0xFF4267B2),
                              ),
                            )
                          : const Icon(
                              Icons.my_location_rounded,
                              color: Color(0xFF4267B2),
                              size: 30,
                            ),
                      const SizedBox(height: 10),
                      Text(
                        _isFetchingLocation
                            ? 'Fetching location...'
                            : 'Tap location icon to fetch address',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(lat, lng),
                initialZoom: 17.0,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
                onPositionChanged: (position, hasGesture) {
                  if (!hasGesture || position.center == null) return;
                  _mapMoveDebounce?.cancel();
                  _mapMoveDebounce = Timer(
                    const Duration(milliseconds: 650),
                    () {
                      final center = position.center;
                      if (center == null || !mounted) return;
                      setState(() {
                        _pickupLatitude = center.latitude.toString();
                        _pickupLongitude = center.longitude.toString();
                        _selectedPickupAddress = null;
                      });
                      _reverseGeocode(center.latitude, center.longitude);
                    },
                  );
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.selorize.app',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(lat, lng),
                      width: 60,
                      height: 60,
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.location_pin,
                            color: Color(0xFF4267B2),
                            size: 44,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

          // 2. Header
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _handleBack,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black12, blurRadius: 8),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      "Address & Pickup",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
          ),

          // 3. Search Bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 56,
            left: 20,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.10),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => _searchLocation(val),
                    decoration: InputDecoration(
                      hintText: "Search for pickup area...",
                      hintStyle: TextStyle(
                        color: Colors.blueGrey.shade300,
                        fontSize: 13,
                      ),
                      prefixIcon: _isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: Bone.circle(size: 20),
                            )
                          : const Icon(
                              Icons.search_rounded,
                              color: Color(0xFF4267B2),
                              size: 20,
                            ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.close,
                                size: 18,
                                color: Colors.grey,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchResults = []);
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.10),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _searchResults.length > 6
                          ? 6
                          : _searchResults.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: Colors.grey.shade100),
                      itemBuilder: (context, i) {
                        final r = _searchResults[i];
                        return ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.location_on_outlined,
                            color: Color(0xFF4267B2),
                            size: 20,
                          ),
                          title: Text(
                            r['display_name']?.toString() ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onTap: () => _selectSearchResult(r),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // 4. GPS FAB
          Positioned(
            right: 16,
            top: MediaQuery.of(context).padding.top + 116,
            child: GestureDetector(
              onTap: () async {
                setState(() => _searchResults = []);
                _searchController.clear();
                await _fetchCurrentLocation();
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: _isFetchingLocation
                    ? const Padding(
                        padding: EdgeInsets.all(13),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Color(0xFF4267B2),
                        ),
                      )
                    : const Icon(
                        Icons.my_location_rounded,
                        color: Color(0xFF4267B2),
                        size: 24,
                      ),
              ),
            ),
          ),

          // 5. Bottom Sheet
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(25),
                  topRight: Radius.circular(25),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 15,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 35,
                      height: 3,
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const Text(
                    "Select Pickup Address",
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 9),

                  // GPS address card
                  if (_fetchedAddress.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedPickupAddress = {
                            'name': _addressNameController.text.trim(),
                            'mobile': _addressMobileController.text.trim(),
                            'houseNo': '',
                            'street': _fetchedAddress.trim(),
                            'city': '',
                            'state': '',
                            'pincode': '',
                            'address': _fetchedAddress.trim(),
                            'fullAddress': _fetchedAddress.trim(),
                            'addressType': 'GPS',
                            'id': '',
                          };
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(11),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: gpsAddressSelected
                              ? const Color(0xFFECFDF5)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: gpsAddressSelected
                                ? const Color(0xFF10B981)
                                : const Color(0xFFE2E8F0),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: gpsAddressSelected
                                    ? const Color(0xFFDCFCE7)
                                    : const Color(0xFFEFF6FF),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.my_location_rounded,
                                color: gpsAddressSelected
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFF4267B2),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        'Current Location',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 12,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFF6366F1,
                                          ).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: const Text(
                                          'GPS',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF6366F1),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  _isFetchingAddress
                                      ? const Text(
                                          'Detecting address...',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF94A3B8),
                                          ),
                                        )
                                      : Text(
                                          _fetchedAddress,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF64748B),
                                            fontWeight: FontWeight.w500,
                                            height: 1.2,
                                          ),
                                        ),
                                ],
                              ),
                            ),
                            if (gpsAddressSelected)
                              const Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFF10B981),
                                size: 22,
                              )
                            else
                              const Icon(
                                Icons.radio_button_unchecked_rounded,
                                color: Color(0xFFCBD5E1),
                                size: 22,
                              ),
                          ],
                        ),
                      ),
                    ),

                  // Saved addresses
                  if (_savedAddresses.isNotEmpty) ...[
                    const Text(
                      'Saved Addresses',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildModernAddressSelector(),
                    const SizedBox(height: 6),
                  ],

                  const SizedBox(height: 4),
                  ElevatedButton(
                    onPressed: _isFetchingLocation
                        ? null
                        : _confirmPickupAddress,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4267B2),
                      disabledBackgroundColor: Colors.grey.shade300,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isFetchingLocation
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  'Fetching Location...',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : const Text(
                            "Confirm & Proceed",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: TextButton(
                      onPressed: () => setState(() {
                        _showAddAddress = true;
                        // Fresh form — sab clear karo taaki pehle se kuch na dikhe
                        _addressHouseController.clear();
                        _addressStreetController.clear();
                        _addressCityController.clear();
                        _addressStateController.clear();
                        _addressPincodeController.clear();
                        _addressType = 'Home';
                      }),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      child: const Text(
                        "Add Address Manually",
                        style: TextStyle(
                          color: Color(0xFF4267B2),
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 2. ADD ADDRESS SCREEN
  Widget _buildAddAddressScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: _handleBack,
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Color(0xFF0F172A),
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  const Text(
                    'New Address',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              const Padding(
                padding: EdgeInsets.only(left: 12),
                child: Text(
                  'NEW ADDRESS',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildModernTextField(
                      "Full Name",
                      Icons.person_outline_rounded,
                      controller: _addressNameController,
                    ),
                    const SizedBox(height: 16),
                    _buildModernTextField(
                      "Mobile Number",
                      Icons.phone_android_rounded,
                      controller: _addressMobileController,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildModernTextField(
                            "Pincode",
                            Icons.pin_drop_outlined,
                            controller: _addressPincodeController,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        _buildDetectPickupLocationButton(),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildModernTextField(
                            "City",
                            Icons.location_city_rounded,
                            controller: _addressCityController,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildModernTextField(
                            "State",
                            Icons.map_rounded,
                            controller: _addressStateController,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildModernTextField(
                      "House No. / Flat No.",
                      Icons.home_work_outlined,
                      controller: _addressHouseController,
                    ),
                    const SizedBox(height: 16),
                    _buildModernTextField(
                      "Area / Colony / Street",
                      Icons.streetview_rounded,
                      controller: _addressStreetController,
                    ),
                    const SizedBox(height: 16),
                    _buildPickupAddressTypeSelector(),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _isSavingAddress ? null : _savePickupAddress,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4267B2),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 56),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        _isSavingAddress ? "Saving..." : "Save Address",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper for Input Fields
  Widget _buildModernTextField(
    String hint,
    IconData? icon, {
    TextEditingController? controller,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        color: Color(0xFF0F172A),
        fontSize: 15,
      ),
      decoration: InputDecoration(
        labelText: hint,
        labelStyle: const TextStyle(
          color: Color(0xFF94A3B8),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: icon != null
            ? Icon(icon, size: 20, color: const Color(0xFF6366F1))
            : null,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
      ),
    );
  }

  Widget _buildDetectPickupLocationButton() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: IconButton(
        onPressed: _isFetchingManualLocation
            ? null
            : _detectLocationForManualForm,
        icon: _isFetchingManualLocation
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Color(0xFF6366F1),
                ),
              )
            : const Icon(Icons.my_location_rounded, color: Color(0xFF6366F1)),
        tooltip: 'Detect Location',
      ),
    );
  }

  Future<void> _detectLocationForManualForm() async {
    if (_isFetchingManualLocation) return;

    setState(() => _isFetchingManualLocation = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Please enable GPS/location service and try again.',
              ),
            ),
          );
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied.')),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 12),
      );
      final details = await _reverseGeocodeDetails(
        position.latitude,
        position.longitude,
      );

      if (details.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not find address for your current location.',
              ),
            ),
          );
        }
        return;
      }

      if (!mounted) return;
      setState(() {
        _addressCityController.text = details['city'] ?? '';
        _addressStateController.text = details['state'] ?? '';
        _addressPincodeController.text = details['postcode'] ?? '';
        if ((details['house'] ?? '').isNotEmpty) {
          _addressHouseController.text = details['house']!;
        }
        if ((details['area'] ?? '').isNotEmpty) {
          _addressStreetController.text = details['area']!;
        }
      });
    } catch (e) {
      debugPrint('Manual location detect error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not fetch current location. Please try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isFetchingManualLocation = false);
    }
  }

  Widget _buildPickupAddressTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'ADDRESS TYPE',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Row(
          children: [
            _buildPickupTypeChip('Home', Icons.home_rounded),
            const SizedBox(width: 12),
            _buildPickupTypeChip('Work', Icons.work_rounded),
            const SizedBox(width: 12),
            _buildPickupTypeChip('Other', Icons.more_horiz_rounded),
          ],
        ),
      ],
    );
  }

  Widget _buildPickupTypeChip(String label, IconData icon) {
    final isSelected = _addressType == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _addressType = label),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF6366F1)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF6366F1)
                  : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 3. PICKUP RESCHEDULING
  Widget _buildPickupTypeScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.black,
            size: 20,
          ),
          onPressed: _handleBack,
        ),
        title: const Text(
          "Pickup Rescheduling",
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // PICKUP MODE TABS
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() {
                              isInstantPickup = false;
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: !isInstantPickup
                                    ? Colors.white
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: !isInstantPickup
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.05,
                                          ),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ]
                                    : [],
                              ),
                              child: Text(
                                "Schedule",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: !isInstantPickup
                                      ? const Color(0xFF4267B2)
                                      : Colors.blueGrey,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() {
                              isInstantPickup = true;
                              _showCalendarGrid = false;
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isInstantPickup
                                    ? Colors.white
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: isInstantPickup
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.05,
                                          ),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ]
                                    : [],
                              ),
                              child: Text(
                                "Instant (FREE)",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isInstantPickup
                                      ? const Color(0xFF4267B2)
                                      : Colors.blueGrey,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  Text(
                    isInstantPickup
                        ? "Pickup Scheduled for Today"
                        : "Select Pickup Date",
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // DATE SELECTION LOGIC
                  if (!isInstantPickup && _showCalendarGrid)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.chevron_left_rounded,
                                  color: Colors.blueGrey,
                                ),
                                onPressed: () => setState(() {
                                  _displayMonth = DateTime(
                                    _displayMonth.year,
                                    _displayMonth.month - 1,
                                    1,
                                  );
                                }),
                              ),
                              Text(
                                DateFormat('MMMM yyyy').format(_displayMonth),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.chevron_right_rounded,
                                  color: Colors.blueGrey,
                                ),
                                onPressed: () => setState(() {
                                  _displayMonth = DateTime(
                                    _displayMonth.year,
                                    _displayMonth.month + 1,
                                    1,
                                  );
                                }),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children:
                                [
                                      "Mon",
                                      "Tue",
                                      "Wed",
                                      "Thu",
                                      "Fri",
                                      "Sat",
                                      "Sun",
                                    ]
                                    .map(
                                      (d) => Text(
                                        d,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blueGrey,
                                          fontSize: 12,
                                        ),
                                      ),
                                    )
                                    .toList(),
                          ),
                          const SizedBox(height: 15),
                          _buildCalendarGrid(),
                        ],
                      ),
                    )
                  else if (!isInstantPickup && !_showCalendarGrid)
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F7FF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_month_rounded,
                            color: Color(0xFF4267B2),
                            size: 28,
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Selected Date",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blueGrey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  DateFormat(
                                    'EEEE, d MMMM yyyy',
                                  ).format(selectedDate),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF1E293B),
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => setState(() {
                              _displayMonth = selectedDate;
                              _showCalendarGrid = true;
                            }),
                            child: const Text(
                              "Change",
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF4267B2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.bolt_rounded,
                            color: Colors.amber,
                            size: 30,
                          ),
                          const SizedBox(width: 15),
                          const Expanded(
                            child: Text(
                              "Instant Pickup: Our agent will arrive within 90 minutes.",
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF92400E),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 25),

                  // Detail Box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Pickup Details",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 15),
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time_filled_rounded,
                              size: 18,
                              color: Colors.blueGrey,
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              "Estimated Arrival",
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.blueGrey,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              isInstantPickup
                                  ? "Within 60 Mins"
                                  : "11:00 AM - 1:00 PM",
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(
                              Icons.payments_rounded,
                              size: 18,
                              color: Colors.blueGrey,
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              "Pickup Charges",
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.blueGrey,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              "FREE",
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Action Button
          Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _finalizeReschedule,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4267B2),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 60),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                "Confirm & Reschedule",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid() {
    DateTime now = DateTime.now();
    DateTime todayMidnight = DateTime(now.year, now.month, now.day);

    DateTime currentMonthView = _displayMonth;
    int daysInMonth = DateTime(
      currentMonthView.year,
      currentMonthView.month + 1,
      0,
    ).day;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 5,
        crossAxisSpacing: 5,
      ),
      itemCount: daysInMonth,
      itemBuilder: (context, index) {
        int day = index + 1;
        DateTime cellDate = DateTime(
          currentMonthView.year,
          currentMonthView.month,
          day,
        );

        bool isPastOrToday = cellDate.isBefore(
          todayMidnight.add(const Duration(days: 1)),
        );

        bool isSelected =
            selectedDate.day == day &&
            selectedDate.month == currentMonthView.month &&
            selectedDate.year == currentMonthView.year;

        return GestureDetector(
          onTap: isPastOrToday
              ? null
              : () {
                  setState(() {
                    selectedDate = cellDate;
                    _showCalendarGrid = false;
                  });
                },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF4267B2) : Colors.transparent,
              shape: BoxShape.circle,
              border: isSelected
                  ? null
                  : Border.all(
                      color: isPastOrToday
                          ? Colors.transparent
                          : Colors.grey.shade100,
                      width: 1,
                    ),
            ),
            alignment: Alignment.center,
            child: Text(
              "$day",
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                color: isSelected
                    ? Colors.white
                    : (isPastOrToday
                          ? Colors.grey.shade300
                          : const Color(0xFF1E293B)),
              ),
            ),
          ),
        );
      },
    );
  }

  // 4. CANCEL SCREEN
  Widget _buildCancelScreen() {
    List<String> reasons = [
      "Changed my mind",
      "Price is too low",
      "Better deal elsewhere",
      "Device Unavailable",
      "Incorrect Info",
      "Other",
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildStepHeader("Cancel Pickup", _handleBack),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon and Title Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.cancel_outlined,
                          color: Colors.red.shade600,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 15),
                      const Expanded(
                        child: Text(
                          "Why do you want to cancel?",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "We're sorry to see you go. Please let us know the reason so we can improve our services.",
                    style: TextStyle(
                      color: Colors.blueGrey.shade400,
                      fontSize: 14,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 30),

                  const Text(
                    "Select a reason",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: reasons.map((reason) {
                      bool isSelected = _selectedCancelReason == reason;
                      return InkWell(
                        onTap: () =>
                            setState(() => _selectedCancelReason = reason),
                        borderRadius: BorderRadius.circular(16),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF4A78A8)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF4A78A8)
                                  : const Color(0xFFE2E8F0),
                              width: 1.5,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF4A78A8,
                                      ).withValues(alpha: 0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Text(
                            reason,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF475569),
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  if (_selectedCancelReason == 'Other') ...[
                    const SizedBox(height: 18),
                    TextField(
                      controller: _otherCancelReasonController,
                      maxLines: 3,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: "Please enter your reason",
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFF4A78A8),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 35),

                  // Feedback Section
                  const SizedBox(height: 12),

                  // Action Button
                  ElevatedButton(
                    onPressed:
                        _selectedCancelReason == null ||
                            (_selectedCancelReason == 'Other' &&
                                _otherCancelReasonController.text
                                    .trim()
                                    .isEmpty)
                        ? null
                        : () {
                            if (DateTime.now().hour >= 13) {
                              _showCancellationNotAvailableDialog(context);
                            } else {
                              _showModernConfirmationDialog(context);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E293B),
                      disabledBackgroundColor: Colors.grey.shade200,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 64),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      "Continue to Cancel",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),

                  const SizedBox(height: 15),
                  Center(
                    child: TextButton(
                      onPressed: _resetRescheduleFlow,
                      child: const Text(
                        "Keep My Order",
                        style: TextStyle(
                          color: Color(0xFF4A78A8),
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showModernConfirmationDialog(BuildContext context) {
    final orderId = _selectedOrder?['id']?.toString() ?? currentOrderID;
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final basePrice = _formatPriceValue(
      _selectedOrder?['basePrice'] ?? _selectedOrder?['price'],
    );
    final finalPrice = _formatPriceValue(
      _selectedOrder?['finalPrice'] ?? _selectedOrder?['price'],
    );

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        bool isCancelling = false;

        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 30,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Info Icon Header
                    Align(
                      alignment: Alignment.topRight,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.info_outline,
                          size: 22,
                          color: Color(0xFF4A78A8),
                        ),
                      ),
                    ),
                    const Text(
                      "Confirm Cancellation",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Are you sure you want to cancel?\nThis action cannot be undone.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),

                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          _dialogRow("Order ID", "#$orderId"),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                          ),
                          _dialogRow(
                            "Estimated Price",
                            "\u20b9 $basePrice",
                            valueColor: Colors.green.shade600,
                          ),
                          const SizedBox(height: 12),
                          _dialogRow(
                            "Final Offer Price",
                            "\u20b9 $finalPrice",
                            isBold: true,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // No, Keep My Order
                    ElevatedButton(
                      onPressed: isCancelling
                          ? null
                          : () {
                              Navigator.pop(dialogContext);
                              _resetRescheduleFlow();
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4A78A8),
                        minimumSize: const Size(double.infinity, 58),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        "No, Keep My Order",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextButton(
                      onPressed: isCancelling
                          ? null
                          : () async {
                              setDialogState(() => isCancelling = true);

                              final reason = _selectedCancelReason == 'Other'
                                  ? _otherCancelReasonController.text.trim()
                                  : (_selectedCancelReason ?? 'Other');

                              try {
                                await _repo.cancelEnquiry(
                                  id: orderId,
                                  cancelReason: reason,
                                );
                              } catch (e) {
                                debugPrint('cancelEnquiry error: $e');
                              }

                              if (rootNavigator.canPop()) {
                                rootNavigator.pop();
                              }

                              widget.onCancelOrder?.call(orderId, reason);

                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!mounted) return;
                                setState(() {
                                  final idx = widget.orders.indexWhere(
                                    (o) => o['id']?.toString() == orderId,
                                  );
                                  if (idx != -1) {
                                    widget.orders[idx]['status'] = 'Cancelled';
                                    widget.orders[idx]['cancelReason'] = reason;
                                    widget.orders[idx]['statusColor'] =
                                        const Color(0xFFFEE2E2);
                                    widget.orders[idx]['statusTextColor'] =
                                        const Color(0xFFDC2626);
                                  }
                                  _confirmedCancelReason = reason;
                                  _showCancelScreen = false;
                                  _showSuccess = false;
                                  _showAddressSelection = false;
                                  _showPickupType = false;
                                  _showAddAddress = false;
                                  _selectedOrder = null;
                                  _showCancelSuccess = true;
                                  _selectedCancelReason = null;
                                  _otherCancelReasonController.clear();
                                });
                              });
                            },
                      style: TextButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: isCancelling
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.redAccent,
                              ),
                            )
                          : const Text(
                              "Yes, Cancel Order",
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showCancellationNotAvailableDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 100,
                  width: 100,
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning_rounded,
                    size: 80,
                    color: Colors.amber,
                  ),
                ),
                const SizedBox(height: 24),

                const Text(
                  "Cancellation not available",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 12),

                const Text(
                  "You can no longer cancel this order\nCancellation was allowed only before",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
                const Text(
                  "01:00PM",
                  style: TextStyle(
                    color: Color(0xFF4A78A8),
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 32),
                // Blue Primary Button
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A78A8),
                    minimumSize: const Size(double.infinity, 58),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "OK Got it",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _showContactSupportSheet(context);
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 58),
                    side: const BorderSide(
                      color: Color(0xFF4A78A8),
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    "Contact Support",
                    style: TextStyle(
                      color: Color(0xFF4A78A8),
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
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

  void _showContactSupportSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 35),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 25),
              const Text(
                "Contact Support",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "How would you like to connect with us?",
                style: TextStyle(
                  color: Colors.blueGrey,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 30),

              // WhatsApp Option
              _buildSupportOption(
                icon: Icons.chat_bubble_rounded,
                title: "WhatsApp Us",
                subtitle: "Fastest response (ID: $_supportOrderId)",
                color: Colors.green,
                onTap: () => _launchContact('whatsapp'),
              ),
              const SizedBox(height: 12),

              // Call Option
              _buildSupportOption(
                icon: Icons.phone_in_talk_rounded,
                title: "Call Support",
                subtitle: "Mon - Sat (10 AM to 7 PM)",
                color: const Color(0xFF4267B2),
                onTap: () => _launchContact('call'),
              ),
              const SizedBox(height: 12),
              _buildSupportOption(
                icon: Icons.email_rounded,
                title: "Email Support",
                subtitle: "Send details by email",
                color: const Color(0xFFEF4444),
                onTap: () => _launchContact('email'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSupportOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.1),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
            const Spacer(),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogRow(
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.blueGrey,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            softWrap: true,
            overflow: TextOverflow.visible,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
              fontSize: isBold ? 16 : 14,
              color: valueColor ?? const Color(0xFF1E293B),
            ),
          ),
        ),
      ],
    );
  }

  // 5. SUCCESS SCREEN
  Widget _buildCancelSuccessScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 36),
          child: Column(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [Colors.red.shade50, Colors.red.shade100],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Icon(
                      Icons.cancel_rounded,
                      color: Colors.red.shade500,
                      size: 56,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "Order Cancelled",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E293B),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Your pickup has been cancelled successfully.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.blueGrey.shade400,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),

              Align(
                alignment: Alignment.center,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 320),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.receipt_long_rounded,
                        size: 16,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          "Order ID: #$currentOrderID",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Reason card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red.shade50, const Color(0xFFFFF1F2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.red.shade100, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.info_outline_rounded,
                            color: Colors.red.shade600,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          "Reason for Cancellation",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF64748B),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.red.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.shade100.withValues(alpha: 0.5),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            color: Colors.red.shade400,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _confirmedCancelReason,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Info note
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 18,
                      color: Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        "This order has been moved to your Cancelled Orders tab. You can relist your device anytime from the Sell section.",
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  if (widget.onNavigateToCancelledOrders != null) {
                    widget.onNavigateToCancelledOrders!();
                  } else {
                    setState(() {
                      _showCancelSuccess = false;
                      _showAddressSelection = false;
                      _showPickupType = false;
                      _showAddAddress = false;
                      _showCancelScreen = false;
                      _showSuccess = false;
                      _selectedOrder = null;
                      _selectedTab = 'Cancelled';
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 58),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  "View Cancelled Orders",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: () {
                  if (widget.onNavigateToAllOrders != null) {
                    widget.onNavigateToAllOrders!();
                  } else {
                    setState(() {
                      _showCancelSuccess = false;
                      _showAddressSelection = false;
                      _showPickupType = false;
                      _showAddAddress = false;
                      _showCancelScreen = false;
                      _showSuccess = false;
                      _selectedOrder = null;
                      _selectedTab = 'All Orders';
                    });
                  }
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF4A78A8),
                  side: const BorderSide(color: Color(0xFF4A78A8), width: 1.5),
                  minimumSize: const Size(double.infinity, 58),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Text(
                  "Back to All Orders",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          const Spacer(),
          const SizedBox(height: 20),
          // Logo Success
          Container(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.grey.shade100,
            ),
            child: Center(
              child: Image.asset(
                'assets/pickup.png',
                fit: BoxFit.contain,
                errorBuilder: (c, e, s) => const Icon(
                  Icons.check_circle,
                  size: 100,
                  color: Colors.green,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "Pickup Confirmed!",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            "Order ID: #$currentOrderID",
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: _resetRescheduleFlow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4267B2),
                    minimumSize: const Size(double.infinity, 60),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    "Track Order",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                OutlinedButton(
                  onPressed: () => setState(() {
                    _showSuccess = false;
                    _showCancelScreen = true;
                  }),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    minimumSize: const Size(double.infinity, 60),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    "Cancel Pickup",
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // UI HELPERS
  Widget _buildStepHeader(String title, VoidCallback onBack) {
    final top = MediaQuery.of(context).padding.top;

    return Container(
      padding: EdgeInsets.only(top: top + 10, left: 10, right: 20, bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: onBack,
          ),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSection() {
    final tabs = [
      'All Orders',
      'Pending',
      'Agent Assigned',
      'Pickup Scheduled',
      'Payment Processed',
      'Cancelled',
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: tabs
            .map(
              (tab) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _buildTab(tab),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildTab(String title) {
    bool isSelected = _selectedTab == title;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = title),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4A78A8) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF4A78A8) : Colors.grey.shade400,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey.shade50,
                  ),
                  child: _buildItemImage(item, size: 80),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['title'],
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        "(${item['specs']})",
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Final Price",
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "\u20b9 ${_formatPriceValue(item['finalPrice'] ?? item['price'])}",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: item['statusColor'] ?? Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item['status'],
                        style: TextStyle(
                          color: item['statusTextColor'] ?? Colors.orange,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_canCancelOrReschedule(item))
                      GestureDetector(
                        onTap: () => setState(() {
                          _selectedOrder = item;
                          currentOrderID = item['id'];
                          _showAddressSelection = true;
                        }),
                        child: const Text(
                          "Reschedule",
                          style: TextStyle(
                            color: Color(0xFF4A78A8),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(
                  Icons.access_time_rounded,
                  size: 18,
                  color: Colors.grey,
                ),
                const SizedBox(width: 8),
                const Text(
                  "Pickup Scheduled",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                Text(
                  _pickupDateText(item),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: ElevatedButton(
              onPressed: () => setState(() => _selectedOrder = item),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A78A8),
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: const Text(
                "View Details",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_bag_outlined,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            "No $_selectedTab Yet",
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemImage(Map<String, dynamic> item, {double size = 80}) {
    final networkUrl = item['imageUrl']?.toString() ?? '';
    final fallbackImage = item['image']?.toString() ?? '';
    final fallbackAsset =
        fallbackImage.isNotEmpty &&
            !fallbackImage.startsWith('http://') &&
            !fallbackImage.startsWith('https://')
        ? fallbackImage
        : 'assets/iphone_normal.png';

    Widget assetFallback() => Image.asset(
      fallbackAsset,
      width: size,
      height: size,
      fit: BoxFit.contain,
    );

    Widget networkImage(String url) => Image.network(
      url,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => assetFallback(),
      loadingBuilder: (_, child, progress) => progress == null
          ? child
          : Bone.square(size: size, borderRadius: BorderRadius.circular(8)),
    );

    if (networkUrl.isNotEmpty) {
      return networkImage(networkUrl);
    }

    if (fallbackImage.startsWith('http://') ||
        fallbackImage.startsWith('https://')) {
      return networkImage(fallbackImage);
    }

    return assetFallback();
  }

  Widget _buildOrderDetailsScreen(Map<String, dynamic> item) {
    final String status = item['status']?.toString() ?? 'Pending';
    final bool isCancelled = status == 'Cancelled';
    final bool isCompleted =
        status == 'Completed' || status == 'Payment Processed';
    final bool isAgentAssigned = status == 'Agent Assigned';
    final bool isPickupScheduled = status == 'Pickup Scheduled';
    final bool showAgentDetails =
        isAgentAssigned || isPickupScheduled || isCompleted;
    final fallbackAgentInfo = _agentInfoFromRawItem(item);
    final agentName = item["agentName"]?.toString().trim().isNotEmpty == true
        ? item["agentName"].toString().trim()
        : fallbackAgentInfo['name'] ?? '';
    final agentMobile =
        item["agentMobile"]?.toString().trim().isNotEmpty == true
        ? item["agentMobile"].toString().trim()
        : fallbackAgentInfo['mobile'] ?? '';
    final String? cancelReason = item['cancelReason'];

    Color bgColor = isCancelled
        ? const Color(0xFFFFF5F5)
        : isCompleted
        ? const Color(0xFFF0FDF4)
        : const Color(0xFFF8FAFC);

    String appBarTitle = isCancelled
        ? "Cancelled Order"
        : isCompleted
        ? "Payment Processed"
        : "Order Summary";

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          appBarTitle,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: Color(0xFF1E293B),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF1E293B),
            size: 20,
          ),
          onPressed: _handleBack,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          children: [
            // IDENTITY CARD
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: isCancelled
                    ? Border.all(color: Colors.red.shade100, width: 1.5)
                    : isCompleted
                    ? Border.all(color: Colors.green.shade100, width: 1.5)
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: isCancelled
                              ? Colors.red.shade50
                              : isCompleted
                              ? Colors.green.shade50
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ColorFiltered(
                          colorFilter: isCancelled
                              ? const ColorFilter.matrix([
                                  0.2126,
                                  0.7152,
                                  0.0722,
                                  0,
                                  0,
                                  0.2126,
                                  0.7152,
                                  0.0722,
                                  0,
                                  0,
                                  0.2126,
                                  0.7152,
                                  0.0722,
                                  0,
                                  0,
                                  0,
                                  0,
                                  0,
                                  1,
                                  0,
                                ])
                              : const ColorFilter.matrix([
                                  1,
                                  0,
                                  0,
                                  0,
                                  0,
                                  0,
                                  1,
                                  0,
                                  0,
                                  0,
                                  0,
                                  0,
                                  1,
                                  0,
                                  0,
                                  0,
                                  0,
                                  0,
                                  1,
                                  0,
                                ]),
                          child: _buildItemImage(item, size: 80),
                        ),
                      ),
                      if (isCancelled)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.red.shade500,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 12,
                            ),
                          ),
                        ),
                      if (isCompleted)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.green.shade500,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['title'],
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: isCancelled
                                ? Colors.red.shade800
                                : isCompleted
                                ? Colors.green.shade800
                                : const Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          "Order ID: ${item['id']}",
                          style: TextStyle(
                            color: Colors.blueGrey.shade300,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildStatusPill(item['status']),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            if (isCancelled) ...[
              // CANCELLED BANNER
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red.shade50, const Color(0xFFFFF1F2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.red.shade100, width: 1.5),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.cancel_rounded,
                        color: Colors.red.shade500,
                        size: 44,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Order Cancelled",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.red.shade800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "This pickup order has been cancelled and is no longer active.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.red.shade400,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // REASON CARD
              if (cancelReason != null && cancelReason.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.red.shade100),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.shade50,
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.info_outline_rounded,
                              color: Colors.red.shade500,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            "Reason for Cancellation",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              color: Colors.red.shade400,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                cancelReason,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.red.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 18,
                      color: Color(0xFF94A3B8),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "This order has been moved to your Cancelled Orders tab. You can relist your device anytime from the Sell section.",
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Offer Price (Cancelled)",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "\u20b9 ${_formatPriceValue(item['finalPrice'] ?? item['price'])}",
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.grey,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      Icons.remove_circle_outline_rounded,
                      color: Colors.grey.shade400,
                      size: 32,
                    ),
                  ],
                ),
              ),
            ] else if (isCompleted) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade50, const Color(0xFFF0FDF4)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.green.shade100, width: 1.5),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_circle_rounded,
                        color: Colors.green.shade600,
                        size: 44,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Pickup Completed!",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.green.shade800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Your device has been successfully picked up and the payment is being processed.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.green.shade600,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              _buildDetailCard(
                title: "Device Information",
                icon: Icons.phone_android_rounded,
                children: [
                  _buildModernRow("Model", item['title']),
                  _buildModernRow("Hardware", item['specs'] ?? ''),
                  _buildModernRow("Condition", "Good"),
                ],
              ),
              const SizedBox(height: 16),

              _buildDetailCard(
                title: "Payment Summary",
                icon: Icons.account_balance_wallet_rounded,
                children: [
                  _buildModernRow(
                    "Final Price Paid",
                    "\u20b9 ${_formatPriceValue(item['finalPrice'] ?? item['price'])}",
                    isHighlight: true,
                  ),
                  _buildModernRow("Pickup Date", _pickupDateText(item)),
                  if (item["bankDetail"]?.toString().isNotEmpty == true)
                    _buildModernRow(
                      "Bank Detail",
                      item["bankDetail"].toString(),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              _buildDetailCard(
                title: "Pickup Details",
                icon: Icons.local_shipping_rounded,
                children: [
                  _buildModernRow(
                    "Address",
                    item["address"]?.toString().isNotEmpty == true
                        ? item["address"].toString()
                        : "\u2014",
                  ),
                  if (showAgentDetails)
                    _buildModernRow(
                      "Agent Name",
                      agentName.isNotEmpty ? agentName : "—",
                    ),
                  if (showAgentDetails)
                    _buildModernRow(
                      "Contact",
                      agentMobile.isNotEmpty ? agentMobile : "—",
                    ),
                ],
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Pickup Status",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildProgressStep(
                      icon: Icons.check_circle_rounded,
                      label: "Order Placed",
                      sublabel: "We received your request",
                      isDone: true,
                    ),
                    _buildProgressConnector(isDone: true),
                    _buildProgressStep(
                      icon: Icons.support_agent_rounded,
                      label: "Agent Assigned",
                      sublabel: isAgentAssigned || isPickupScheduled
                          ? "Agent details are available"
                          : "Looking for nearby agent",
                      isDone: isAgentAssigned || isPickupScheduled,
                      isActive: status == 'Pending',
                    ),
                    _buildProgressConnector(
                      isDone: isAgentAssigned || isPickupScheduled,
                    ),
                    _buildProgressStep(
                      icon: Icons.local_shipping_rounded,
                      label: "Pickup Scheduled",
                      sublabel: isPickupScheduled
                          ? "Pickup: ${_pickupDateText(item)}"
                          : "Waiting for pickup schedule",
                      isDone: isPickupScheduled,
                      isActive: isAgentAssigned,
                    ),
                    _buildProgressConnector(isDone: isPickupScheduled),
                    _buildProgressStep(
                      icon: Icons.payments_rounded,
                      label: "Payment Processed",
                      sublabel: "Amount credited to your account",
                      isDone: false,
                      isActive: isPickupScheduled,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              _buildDetailCard(
                title: "Device Information",
                icon: Icons.phone_android_rounded,
                children: [
                  _buildModernRow("Model", item['title']),
                  _buildModernRow("Hardware", item['specs'] ?? ''),
                  _buildModernRow("Condition", "Good"),
                ],
              ),
              const SizedBox(height: 16),

              _buildDetailCard(
                title: "Price Summary",
                icon: Icons.account_balance_wallet_rounded,
                children: [
                  _buildModernRow(
                    "Offer Price",
                    "\u20b9 ${_formatPriceValue(item['finalPrice'] ?? item['price'])}",
                    isHighlight: true,
                  ),
                  _buildModernRow("Pickup Date", _pickupDateText(item)),
                ],
              ),
              const SizedBox(height: 16),

              _buildDetailCard(
                title: "Logistic Details",
                icon: Icons.local_shipping_rounded,
                children: [
                  _buildModernRow(
                    "Address",
                    item["address"]?.toString().isNotEmpty == true
                        ? item["address"].toString()
                        : "\u2014",
                  ),
                  if (item["bankDetail"]?.toString().isNotEmpty == true)
                    _buildModernRow(
                      "Bank Detail",
                      item["bankDetail"].toString(),
                    ),
                  if (showAgentDetails)
                    _buildModernRow(
                      "Agent Name",
                      agentName.isNotEmpty ? agentName : "—",
                    ),
                  if (showAgentDetails)
                    _buildModernRow(
                      "Contact",
                      agentMobile.isNotEmpty ? agentMobile : "—",
                    ),
                ],
              ),

              const SizedBox(height: 40),
              if (_canCancelOrReschedule(item))
                ElevatedButton(
                  onPressed: () => setState(() {
                    currentOrderID = item['id'];
                    _showAddressSelection = true;
                  }),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    minimumSize: const Size(double.infinity, 64),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
                    "Reschedule Pickup",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              if (isAgentAssigned) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _showContactSupportSheet(context),
                  icon: const Icon(Icons.support_agent_rounded, size: 20),
                  label: const Text(
                    "Contact Support",
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFF1F2),
                    foregroundColor: const Color(0xFFE11D48),
                    minimumSize: const Size(double.infinity, 58),
                    side: const BorderSide(
                      color: Color(0xFFFECDD3),
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildIdentityCard(Map<String, dynamic> item) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: _buildItemImage(item, size: 80),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['title'],
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  "Order ID: ${item['id']}",
                  style: TextStyle(
                    color: Colors.blueGrey.shade300,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                _buildStatusPill(item['status']),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF4A78A8)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildModernRow(
    String label,
    String value, {
    bool isHighlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.blueGrey.shade200,
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isHighlight ? Colors.green : const Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStep({
    required IconData icon,
    required String label,
    required String sublabel,
    required bool isDone,
    bool isActive = false,
  }) {
    final Color activeColor = const Color(0xFF4A78A8);
    final Color doneColor = Colors.green.shade600;
    final Color inactiveColor = const Color(0xFFCBD5E1);

    final Color iconColor = isDone
        ? doneColor
        : isActive
        ? activeColor
        : inactiveColor;

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isDone
                ? Colors.green.shade50
                : isActive
                ? const Color(0xFFEFF6FF)
                : const Color(0xFFF1F5F9),
            shape: BoxShape.circle,
            border: Border.all(
              color: isDone
                  ? Colors.green.shade200
                  : isActive
                  ? const Color(0xFFBFDBFE)
                  : const Color(0xFFE2E8F0),
              width: 1.5,
            ),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isDone
                      ? Colors.green.shade700
                      : isActive
                      ? const Color(0xFF1E293B)
                      : const Color(0xFF94A3B8),
                ),
              ),
              Text(
                sublabel,
                style: TextStyle(
                  fontSize: 12,
                  color: isDone
                      ? Colors.green.shade400
                      : isActive
                      ? const Color(0xFF64748B)
                      : const Color(0xFFCBD5E1),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (isDone)
          Icon(
            Icons.check_circle_rounded,
            color: Colors.green.shade400,
            size: 18,
          ),
        if (isActive && !isDone)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: const Text(
              "IN PROGRESS",
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: Color(0xFF3B82F6),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProgressConnector({required bool isDone}) {
    return Padding(
      padding: const EdgeInsets.only(left: 17, top: 4, bottom: 4),
      child: Container(
        width: 2,
        height: 28,
        decoration: BoxDecoration(
          color: isDone ? Colors.green.shade200 : const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildStatusPill(String status) {
    Color color = (status == "Completed" || status == "Payment Processed")
        ? Colors.green
        : (status == "Cancelled"
              ? Colors.red
              : (status == "Pending"
                    ? Colors.orange
                    : const Color(0xFF4A78A8)));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Future<void> _fetchCurrentLocation() async {
    if (_isFetchingLocation) return;
    setState(() {
      _isFetchingLocation = true;
    });
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _isFetchingLocation = false);
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        if (mounted) setState(() => _isFetchingLocation = false);
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 12),
      );
      if (!mounted) return;
      setState(() {
        _pickupLatitude = position.latitude.toString();
        _pickupLongitude = position.longitude.toString();
      });
      try {
        _mapController.move(
          LatLng(position.latitude, position.longitude),
          17.0,
        );
      } catch (_) {}

      await _reverseGeocode(position.latitude, position.longitude);
      if (_fetchedAddress.trim().isEmpty) {
        await _reverseGeocodeForCard(position.latitude, position.longitude);
      }
    } catch (e) {
      debugPrint('Location fetch error: $e');
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  // Current Location card mein address dikhane ke liye — profile wala placemarkFromCoordinates logic
  Future<void> _reverseGeocodeForCard(double lat, double lng) async {
    if (!mounted) return;
    setState(() => _isFetchingAddress = true);
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) return;

      final place = placemarks.first;

      final city =
          [
            place.locality,
            place.subAdministrativeArea,
            place.administrativeArea,
          ].firstWhere(
            (v) => v != null && v.trim().isNotEmpty,
            orElse: () => '',
          ) ??
          '';
      final state = place.administrativeArea ?? '';
      final pincode = place.postalCode ?? '';
      final area = [
        place.name,
        place.subThoroughfare,
        place.street,
        place.subLocality,
        place.thoroughfare,
      ].where((v) => v != null && v.trim().isNotEmpty).toSet().join(', ');

      final parts = <String>[
        if (area.isNotEmpty) area,
        if (city.isNotEmpty) city,
        if (state.isNotEmpty) state,
        if (pincode.isNotEmpty) pincode,
      ];
      final address = parts.join(', ');

      if (mounted) {
        setState(() => _fetchedAddress = address.isNotEmpty ? address : '');
      }
    } catch (e) {
      debugPrint('Reverse geocode card error: $e');
    } finally {
      if (mounted) setState(() => _isFetchingAddress = false);
    }
  }

  Future<Map<String, String>> _reverseGeocodeDetails(
    double lat,
    double lng,
  ) async {
    var nativeHouse = '';
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        nativeHouse = [place.subThoroughfare, place.name]
            .where((value) => value != null && value.trim().isNotEmpty)
            .toSet()
            .join(', ');
      }
    } catch (_) {}

    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&addressdetails=1&zoom=18&extratags=1&namedetails=1',
      );
      final response = await http.get(
        uri,
        headers: {'User-Agent': 'SelorizeApp/1.0', 'Accept-Language': 'en'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final addr = data['address'] as Map<String, dynamic>? ?? {};
        final houseNumber = addr['house_number']?.toString() ?? '';
        final building =
            addr['house_name']?.toString() ??
            addr['building']?.toString() ??
            addr['amenity']?.toString() ??
            addr['shop']?.toString() ??
            addr['office']?.toString() ??
            addr['residential']?.toString() ??
            '';
        final road =
            addr['road']?.toString() ??
            addr['pedestrian']?.toString() ??
            addr['footway']?.toString() ??
            '';
        final suburb = addr['suburb']?.toString().isNotEmpty == true
            ? addr['suburb'].toString()
            : (addr['neighbourhood']?.toString() ??
                  addr['quarter']?.toString() ??
                  addr['locality']?.toString() ??
                  '');
        final city = addr['city']?.toString().isNotEmpty == true
            ? addr['city'].toString()
            : (addr['town']?.toString().isNotEmpty == true
                  ? addr['town'].toString()
                  : (addr['village']?.toString() ??
                        addr['county']?.toString() ??
                        ''));
        final district =
            addr['state_district']?.toString() ??
            addr['city_district']?.toString() ??
            '';
        final state = addr['state']?.toString() ?? '';
        final postcode = addr['postcode']?.toString() ?? '';
        final displayName = data['display_name']?.toString().trim() ?? '';
        final parts = <String>[];
        for (final value in [
          nativeHouse,
          building,
          houseNumber,
          road,
          suburb,
          city,
          district,
          state,
          postcode,
        ]) {
          if (value.isNotEmpty && !parts.contains(value)) parts.add(value);
        }
        final fullAddress =
            nativeHouse.isNotEmpty && !displayName.contains(nativeHouse)
            ? [
                nativeHouse,
                displayName,
              ].where((value) => value.isNotEmpty).join(', ')
            : (displayName.isNotEmpty ? displayName : parts.join(', '));
        return {
          'address': fullAddress,
          'house': [
            nativeHouse,
            building,
            houseNumber,
          ].where((value) => value.isNotEmpty).join(', '),
          'area': fullAddress.isNotEmpty
              ? fullAddress
              : [
                  road,
                  suburb,
                  district,
                ].where((value) => value.isNotEmpty).toSet().join(', '),
          'city': city,
          'state': state,
          'postcode': postcode,
        };
      }
    } catch (e) {
      debugPrint('Detailed reverse geocode error: $e');
    }

    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) return {};
      final place = placemarks.first;
      final city =
          [
            place.locality,
            place.subAdministrativeArea,
            place.administrativeArea,
          ].firstWhere(
            (value) => value != null && value.trim().isNotEmpty,
            orElse: () => '',
          ) ??
          '';
      final area =
          [
                place.name,
                place.subThoroughfare,
                place.street,
                place.subLocality,
                place.thoroughfare,
              ]
              .where((value) => value != null && value.trim().isNotEmpty)
              .toSet()
              .join(', ');
      return {
        'address': [
          area,
          city,
          place.administrativeArea ?? '',
          place.postalCode ?? '',
        ].where((value) => value.isNotEmpty).join(', '),
        'house': [place.name, place.subThoroughfare]
            .where((value) => value != null && value.trim().isNotEmpty)
            .toSet()
            .join(', '),
        'area': area,
        'city': city,
        'state': place.administrativeArea ?? '',
        'postcode': place.postalCode ?? '',
      };
    } catch (e) {
      debugPrint('Placemark reverse geocode fallback error: $e');
      return {};
    }
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    if (!mounted) return;
    setState(() => _isFetchingAddress = true);
    try {
      final details = await _reverseGeocodeDetails(lat, lng);
      if (mounted && (details['address'] ?? '').isNotEmpty) {
        setState(() => _fetchedAddress = details['address']!);
      }
    } finally {
      if (mounted) setState(() => _isFetchingAddress = false);
    }
  }

  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&addressdetails=1&limit=6&countrycodes=in',
      );
      final response = await http.get(
        uri,
        headers: {'User-Agent': 'SelorizeApp/1.0', 'Accept-Language': 'en'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        if (mounted) {
          setState(() {
            _searchResults = data
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
          });
        }
      }
    } catch (e) {
      debugPrint('Search error: $e');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _selectSearchResult(Map<String, dynamic> result) {
    final lat = double.tryParse(result['lat']?.toString() ?? '');
    final lng = double.tryParse(result['lon']?.toString() ?? '');
    if (lat == null || lng == null) return;
    setState(() {
      _pickupLatitude = lat.toString();
      _pickupLongitude = lng.toString();
      _searchResults = [];
      _searchController.clear();
      _fetchedAddress = result['display_name']?.toString() ?? '';
    });
    try {
      _mapController.move(LatLng(lat, lng), 15.0);
    } catch (_) {}
  }
}
