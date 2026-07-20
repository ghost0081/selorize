import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../repository/auth_repository.dart';

class ListingsScreen extends StatefulWidget {
  final List<Map<String, dynamic>> listings;
  final Function(int)? onTabChange;
  final Function(String id, String reason)? onCancelListing;
  final VoidCallback? onNavigateToCancelledListings;
  final String? initialTab;
  const ListingsScreen({
    super.key,
    required this.listings,
    this.onTabChange,
    this.onCancelListing,
    this.onNavigateToCancelledListings,
    this.initialTab,
  });

  @override
  State<ListingsScreen> createState() => _ListingsScreenState();
}

class _ListingsScreenState extends State<ListingsScreen> {
  final AuthRepository _repo = AuthRepository();
  String _selectedTab = 'All Listings';
  bool _showCancelScreen = false;
  bool _showCancelSuccess = false;
  String? _selectedCancelReason;
  String _confirmedCancelReason = '';
  final TextEditingController _otherCancelReasonController =
      TextEditingController();
  Map<String, String>? _supportContact;

  @override
  void dispose() {
    _otherCancelReasonController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialTab != null) {
      _selectedTab = widget.initialTab!;
    }
  }

  Map<String, dynamic>? _selectedListing;

  String _getFormattedDate(String? rawDate) {
    if (rawDate == null ||
        rawDate.toLowerCase() == 'just now' ||
        rawDate.toLowerCase() == 'now' ||
        rawDate.isEmpty) {
      return DateFormat('dd / MMM / yyyy  hh:mm a').format(DateTime.now());
    }
    final parsed = DateTime.tryParse(rawDate);
    if (parsed != null) {
      return DateFormat('dd / MMM / yyyy  hh:mm a').format(parsed);
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop:
          _selectedListing == null && !_showCancelScreen && !_showCancelSuccess,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          if (_showCancelSuccess) {
            setState(() {
              _showCancelSuccess = false;
              _selectedListing = null;
            });
          } else if (_showCancelScreen) {
            setState(() {
              _showCancelScreen = false;
              _selectedCancelReason = null;
            });
          } else if (_selectedListing != null) {
            setState(() => _selectedListing = null);
          }
        }
      },
      child: _buildCurrentScreen(),
    );
  }

  Widget _buildCurrentScreen() {
    if (_showCancelSuccess) {
      return _buildCancelSuccessScreen();
    }

    if (_showCancelScreen) {
      return _buildCancelScreen();
    }

    if (_selectedListing != null) {
      return _buildListingDetailsScreen(_selectedListing!);
    }

    List<Map<String, dynamic>> displayedListings = widget.listings;
    if (_selectedTab != 'All Listings') {
      displayedListings = widget.listings
          .where((l) => l['status'] == _selectedTab)
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
              child: displayedListings.isEmpty
                  ? _buildEmptyState() // Modern Empty State
                  : ListView.builder(
                      key: ValueKey(_selectedTab),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: displayedListings.length,
                      itemBuilder: (context, index) =>
                          _buildListingCard(displayedListings[index]),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFF4A78A8).withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _selectedTab == 'All Listings'
                    ? Icons.inventory_2_outlined
                    : Icons.filter_list_off_rounded,
                size: 80,
                color: const Color(0xFF4A78A8).withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              _selectedTab == 'All Listings'
                  ? "No Listings Yet"
                  : "No $_selectedTab Items",
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _selectedTab == 'All Listings'
                  ? "You haven't listed any devices for sale yet. Turn your old phone into instant cash today!"
                  : "You don't have any items currently marked as '$_selectedTab'.",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF64748B),
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 40),
            if (_selectedTab == 'All Listings')
              ElevatedButton(
                onPressed: () {
                  widget.onTabChange?.call(1);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 18,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Start Selling Now",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
              )
            else
              TextButton(
                onPressed: () => setState(() => _selectedTab = 'All Listings'),
                child: const Text(
                  "Show All Listings",
                  style: TextStyle(
                    color: Color(0xFF4A78A8),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // TAB SECTION
  Widget _buildTabSection() {
    final tabs = [
      'All Listings',
      'Pending',
      'Agent Assigned',
      'Pickup Scheduled',
      'Payment Processed',
      'Cancelled',
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
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

  Widget _buildListingCard(Map<String, dynamic> item) {
    final isPickupScheduled = item['status'] == 'Pickup Scheduled';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // MOBILE IMAGE
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 85,
                  height: 85,
                  color: const Color(0xFFF8FAFC),
                  child: _buildItemImage(item, size: 85),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['title'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      "(${item['specs']})",
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Listing ID: ${item['id']}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    Text(
                      isPickupScheduled
                          ? 'Pickup: ${_pickupDateText(item)}'
                          : _getFormattedDate(item['listingDate']),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _getStatusBgColor(item['status']),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item['status'],
                  style: TextStyle(
                    color: _getStatusTextColor(item['status']),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
              ElevatedButton(
                onPressed: () => setState(() => _selectedListing = item),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A78A8),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size(110, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'View Details',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStatusBgColor(String status) {
    switch (status) {
      case 'Completed':
      case 'Payment Processed':
        return const Color(0xFFDCFCE7);
      case 'Cancelled':
        return const Color(0xFFFEE2E2);
      case 'Agent Assigned':
        return const Color(0xFFEFF6FF);
      case 'Pickup Scheduled':
        return const Color(0xFFE0F2FE);
      case 'Pending':
        return const Color(0xFFFFF7ED);
      default:
        return const Color(0xFFF1F5F9);
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status) {
      case 'Completed':
      case 'Payment Processed':
        return Colors.green.shade800;
      case 'Cancelled':
        return Colors.red.shade800;
      case 'Agent Assigned':
        return const Color(0xFF2563EB);
      case 'Pickup Scheduled':
        return const Color(0xFF0369A1);
      case 'Pending':
        return Colors.orange.shade800;
      default:
        return const Color(0xFF475569);
    }
  }

  //  VIEW DETAILS SCREEN
  Widget _buildItemImage(Map<String, dynamic> item, {double size = 85}) {
    final networkUrl = item['imageUrl']?.toString() ?? '';
    if (networkUrl.isNotEmpty) {
      return Image.network(
        networkUrl,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Image.asset(
          'assets/iphone_normal.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
        ),
        loadingBuilder: (_, child, progress) => progress == null
            ? child
            : Bone.square(size: size, borderRadius: BorderRadius.circular(8)),
      );
    }
    return Image.asset(
      item['image'] ?? 'assets/iphone_normal.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }

  Widget _buildListingDetailsScreen(Map<String, dynamic> item) {
    final String status = item['status']?.toString() ?? 'Pending';
    final bool isCancelled = status == 'Cancelled';
    final bool isPaymentProcessed = status == 'Payment Processed';
    final bool isCompleted = status == 'Completed' || isPaymentProcessed;
    final bool isAgentAssigned = status == 'Agent Assigned';
    final bool isPickupScheduled = status == 'Pickup Scheduled';
    final bool agentDone = isAgentAssigned || isPickupScheduled || isCompleted;
    final bool pickupDone = isPickupScheduled || isCompleted;
    final String? cancelReason = item['cancelReason'];

    Color bgColor = isCancelled
        ? const Color(0xFFFFF5F5)
        : isCompleted
        ? const Color(0xFFF0FDF4)
        : const Color(0xFFF8FAFC);

    String appBarTitle = isCancelled
        ? "Cancelled Listing"
        : isCompleted
        ? "Payment Processed"
        : "View Details";

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          appBarTitle,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 20,
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
          onPressed: () => setState(() => _selectedListing = null),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // DEVICE CARD
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
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
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
                  const SizedBox(width: 20),
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
                          item['specs'],
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Listing ID: ${item['id']}",
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          isPickupScheduled
                              ? 'Pickup: ${_pickupDateText(item)}'
                              : _getFormattedDate(item['listingDate']),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isCancelled
                                ? Colors.red.shade50
                                : isCompleted
                                ? Colors.green.shade50
                                : const Color(0xFFFFF7ED),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item['status'].toString().toUpperCase(),
                            style: TextStyle(
                              color: isCancelled
                                  ? Colors.red.shade700
                                  : isCompleted
                                  ? Colors.green.shade700
                                  : Colors.orange.shade800,
                              fontSize: 10,
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

            const SizedBox(height: 20),

            // CANCELLED BLOCK
            if (isCancelled) ...[
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
                      "Listing Cancelled",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.red.shade800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "This listing has been cancelled and is no longer active.",
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

              // Cancellation Reason Card
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

              // Info note
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
                        "You can relist your device anytime from the Sell section.",
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

              // Price summary
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

              const SizedBox(height: 20),

              // Support card for cancelled listings
              _buildActionCard(isCancelled: true),
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
                      "Listing Completed!",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.green.shade800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Your device has been picked up and the deal is complete.",
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

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF166534), Color(0xFF15803D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Amount Received",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      "\u20b9 ${_formatPriceValue(item['finalPrice'] ?? item['price'])}",
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF4ADE80),
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Completed steps
              const Text(
                "Order Timeline",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 20),
              _buildStep(
                "Listing Created",
                "Device listed on marketplace",
                "Done",
                true,
                false,
              ),
              _buildStep(
                "Verification",
                "Details reviewed by experts",
                "Done",
                true,
                false,
              ),
              _buildStep(
                "Agent Assigned",
                "Pickup agent assigned",
                "Done",
                true,
                false,
              ),
              _buildStep(
                "Pickup Completed",
                "Agent picked up your device",
                "Done",
                true,
                false,
              ),
              _buildStep(
                "Payment Done",
                "Amount credited to your account",
                "Done",
                true,
                false,
                isLast: true,
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF334155)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1E293B).withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Final Valuation",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Text(
                              "Original: ",
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              "\u20b9 ${_formatPriceValue(item['basePrice'] ?? item['price'])}",
                              style: TextStyle(
                                fontSize: 11,
                                decoration: TextDecoration.lineThrough,
                                color: Colors.white.withOpacity(0.4),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Text(
                      "\u20b9 ${_formatPriceValue(item['finalPrice'] ?? item['price'])}",
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF4ADE80),
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                "Order Progress",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 20),
              _buildStep(
                "Listing Created",
                "Your device is live on marketplace",
                "Done",
                true,
                false,
              ),
              _buildStep(
                "Verification",
                "Details reviewed by experts",
                "Done",
                true,
                false,
              ),
              _buildStep(
                "Agent Assigned",
                agentDone
                    ? "Pickup agent assigned"
                    : "Waiting for pickup agent",
                agentDone ? "Done" : "In Progress",
                agentDone,
                !agentDone,
              ),
              _buildStep(
                "Pickup Scheduled",
                pickupDone
                    ? "Pickup: ${_pickupDateText(item)}"
                    : "Waiting for pickup schedule",
                pickupDone
                    ? "Done"
                    : (isAgentAssigned ? "In Progress" : "Pending"),
                pickupDone,
                isAgentAssigned,
              ),
              _buildStep(
                "Completion",
                "Instant cash after pickup",
                isPickupScheduled ? "In Progress" : "Pending",
                false,
                isPickupScheduled,
                isLast: true,
              ),
              const SizedBox(height: 30),
              _buildActionCard(
                isPickupScheduled: isPickupScheduled || isAgentAssigned,
              ),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(
    String title,
    String desc,
    String time,
    bool isDone,
    bool isCurrent, {
    bool isLast = false,
  }) {
    return IntrinsicHeight(
      child: Row(
        children: [
          Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isDone
                      ? const Color(0xFF10B981)
                      : (isCurrent ? const Color(0xFF4A78A8) : Colors.white),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDone
                        ? Colors.transparent
                        : (isCurrent
                              ? const Color(0xFF4A78A8)
                              : Colors.grey.shade300),
                    width: 2,
                  ),
                  boxShadow: isCurrent
                      ? [
                          BoxShadow(
                            color: const Color(0xFF4A78A8).withOpacity(0.3),
                            blurRadius: 10,
                          ),
                        ]
                      : [],
                ),
                child: isDone
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: isDone
                          ? const Color(0xFF10B981)
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(2),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: isCurrent
                            ? const Color(0xFF4A78A8)
                            : const Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.blueGrey.shade400,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelScreen() {
    final reasons = [
      "Changed my mind",
      "Price is too low",
      "Better deal elsewhere",
      "Device Unavailable",
      "Incorrect Info",
      "Other",
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Cancel Listing",
          style: TextStyle(
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
          onPressed: () {
            setState(() {
              _showCancelScreen = false;
              _selectedCancelReason = null;
              _otherCancelReasonController.clear();
            });
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                "Please select a reason before cancelling this listing request.",
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
                  final isSelected = _selectedCancelReason == reason;
                  return InkWell(
                    onTap: () => setState(() {
                      _selectedCancelReason = reason;
                      if (reason != 'Other') {
                        _otherCancelReasonController.clear();
                      }
                    }),
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
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
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
              ElevatedButton(
                onPressed:
                    _selectedCancelReason == null ||
                        (_selectedCancelReason == 'Other' &&
                            _otherCancelReasonController.text.trim().isEmpty)
                    ? null
                    : () {
                        if (DateTime.now().hour >= 21) {
                          _showCancellationNotAvailableDialog(context);
                        } else {
                          _showListingCancelConfirmationDialog(context);
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
                  onPressed: () {
                    setState(() {
                      _showCancelScreen = false;
                      _selectedCancelReason = null;
                      _otherCancelReasonController.clear();
                    });
                  },
                  child: const Text(
                    "Keep My Listing",
                    style: TextStyle(
                      color: Color(0xFF4A78A8),
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showListingCancelConfirmationDialog(BuildContext context) {
    final item = _selectedListing;
    if (item == null) return;

    final listingId = item['id']?.toString() ?? '';
    final price = _formatPriceValue(item['finalPrice'] ?? item['price']);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
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
                          _dialogRow("Listing ID", "#$listingId"),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                          ),
                          _dialogRow(
                            "Offer Price",
                            "\u20b9 $price",
                            valueColor: Colors.green.shade600,
                            isBold: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: isCancelling
                          ? null
                          : () {
                              Navigator.pop(dialogContext);
                              setState(() {
                                _showCancelScreen = false;
                                _selectedCancelReason = null;
                              });
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
                        "No, Keep My Listing",
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
                              await _cancelCurrentListing(
                                dialogContext,
                                listingId,
                              );
                            },
                      style: TextButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: isCancelling
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.redAccent,
                              ),
                            )
                          : const Text(
                              "Yes, Cancel Listing",
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

  Future<void> _cancelCurrentListing(
    BuildContext dialogContext,
    String listingId,
  ) async {
    final reason = _selectedCancelReason == 'Other'
        ? _otherCancelReasonController.text.trim()
        : (_selectedCancelReason ?? 'Other');

    try {
      await _repo.cancelEnquiry(id: listingId, cancelReason: reason);
    } catch (e) {
      debugPrint('cancelEnquiry listing error: $e');
    }

    if (!mounted || !dialogContext.mounted) return;
    Navigator.pop(dialogContext);

    widget.onCancelListing?.call(listingId, reason);

    setState(() {
      final idx = widget.listings.indexWhere(
        (listing) => listing['id']?.toString() == listingId,
      );
      if (idx != -1) {
        widget.listings[idx]['status'] = 'Cancelled';
        widget.listings[idx]['cancelReason'] = reason;
        widget.listings[idx]['statusColor'] = const Color(0xFFFEE2E2);
        widget.listings[idx]['statusTextColor'] = const Color(0xFFDC2626);
        _selectedListing = widget.listings[idx];
      } else if (_selectedListing != null) {
        _selectedListing!['status'] = 'Cancelled';
        _selectedListing!['cancelReason'] = reason;
        _selectedListing!['statusColor'] = const Color(0xFFFEE2E2);
        _selectedListing!['statusTextColor'] = const Color(0xFFDC2626);
      }
      _confirmedCancelReason = reason;
      _showCancelScreen = false;
      _showCancelSuccess = true;
      _selectedCancelReason = null;
      _otherCancelReasonController.clear();
    });
  }

  void _showCancellationNotAvailableDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
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
                  height: 88,
                  width: 88,
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.warning_rounded,
                    size: 64,
                    color: Colors.amber.shade600,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  "Cancellation not available",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "You can no longer cancel this listing from here. Please contact support for help.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 14,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A78A8),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    "Okay",
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCancelSuccessScreen() {
    final item = _selectedListing;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F5),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 40),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cancel_rounded,
                  color: Colors.red.shade500,
                  size: 58,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "Listing Cancelled",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.red.shade800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Your listing request has been cancelled successfully.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.red.shade400,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 28),
              if (item != null)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.red.shade100),
                  ),
                  child: Column(
                    children: [
                      _dialogRow("Listing ID", "#${item['id']}"),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                      ),
                      _dialogRow(
                        "Reason",
                        _confirmedCancelReason,
                        valueColor: Colors.red.shade600,
                        isBold: true,
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  if (widget.onNavigateToCancelledListings != null) {
                    widget.onNavigateToCancelledListings!();
                  }
                  setState(() {
                    _showCancelSuccess = false;
                    _showCancelScreen = false;
                    _selectedCancelReason = null;
                    _selectedListing = null;
                    _selectedTab = 'Cancelled';
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE11D48),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size(double.infinity, 58),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  "View Cancelled Listings",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  setState(() {
                    _showCancelSuccess = false;
                    _showCancelScreen = false;
                    _selectedCancelReason = null;
                    _selectedListing = null;
                  });
                },
                child: const Text(
                  "Back to Listings",
                  style: TextStyle(
                    color: Color(0xFF4A78A8),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dialogRow(
    String label,
    String value, {
    Color? valueColor,
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: valueColor ?? const Color(0xFF1E293B),
              fontSize: 14,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  String get _supportOrderId {
    final id = _selectedListing?['id']?.toString() ?? '';
    return id.isNotEmpty ? id : 'N/A';
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

  Future<void> _launchSupportContact(String type) async {
    final orderId = _supportOrderId;
    final contact = await _loadSupportContact();
    late final Uri uri;

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
      final message = 'Hello SeloRize, I need help with my Order #$orderId';
      uri = Uri.parse(
        'https://wa.me/${whatsapp.replaceAll('+', '')}?text=${Uri.encodeComponent(message)}',
      );
    } else {
      final email = contact['email'] ?? '';
      if (email.isEmpty || email.toLowerCase() == 'null') {
        _showSupportUnavailable();
        return;
      }
      uri = Uri.parse('mailto:$email?subject=Support for Order $orderId');
    }

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Required app is not installed.')),
        );
      }
    } catch (e) {
      debugPrint('Support launch error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open support.')),
        );
      }
    }
  }

  void _showSupportUnavailable() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Support contact is not available.')),
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
              _buildSupportOption(
                icon: Icons.chat_bubble_rounded,
                title: "WhatsApp Us",
                subtitle: "Fastest response (ID: $_supportOrderId)",
                color: Colors.green,
                onTap: () {
                  Navigator.pop(context);
                  _launchSupportContact('whatsapp');
                },
              ),
              const SizedBox(height: 12),
              _buildSupportOption(
                icon: Icons.phone_in_talk_rounded,
                title: "Call Support",
                subtitle: "Mon - Sat (10 AM to 7 PM)",
                color: const Color(0xFF4267B2),
                onTap: () {
                  Navigator.pop(context);
                  _launchSupportContact('call');
                },
              ),
              const SizedBox(height: 12),
              _buildSupportOption(
                icon: Icons.email_rounded,
                title: "Email Support",
                subtitle: "Send details by email",
                color: const Color(0xFFEF4444),
                onTap: () {
                  Navigator.pop(context);
                  _launchSupportContact('email');
                },
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
            Expanded(
              child: Column(
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
            ),
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

  Widget _buildActionCard({
    bool isPickupScheduled = false,
    bool isCancelled = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFECDD3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.help_outline_rounded,
                color: Color(0xFFE11D48),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isPickupScheduled || isCancelled
                      ? "Have a question?"
                      : "Need to change something?",
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF881337),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isPickupScheduled || isCancelled) ...[
            ElevatedButton.icon(
              onPressed: () => _showContactSupportSheet(context),
              icon: const Icon(Icons.support_agent_rounded, size: 18),
              label: Text(
                isCancelled ? "Contact Support" : "Contact Support",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE11D48),
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ] else ...[
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _showCancelScreen = true;
                  _selectedCancelReason = null;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFFE11D48),
                elevation: 0,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                side: const BorderSide(color: Color(0xFFF43F5E), width: 1),
              ),
              child: const Text(
                "Cancel Listing Request",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
