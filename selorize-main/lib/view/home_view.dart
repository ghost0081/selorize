import 'dart:async';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:provider/provider.dart';
import './order_view.dart';
import './sell_view.dart';
import './profile_view.dart';
import '../repository/auth_repository.dart';
import '../res/api_constants.dart';
import '../service/device_data_cache.dart';
import '../service/notification_service.dart';
import '../view_model/auth_viewmodel.dart';
import 'package:selorize/view/state_selection_view.dart';
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  String currentOrderID = "";
  String? _sellInitialBrandName;
  String? _sellInitialModelName;
  bool _sellOpenBrandSelection = false;
  int _profileResetSignal = 0;
  DateTime? _lastHomeBackPressedAt;
  final AuthRepository _repo = AuthRepository();
  final GlobalKey<SellScreenState> _sellKey = GlobalKey<SellScreenState>();
  DateTime? _lastResumeRefreshAt;
  bool _isRefreshingAfterResume = false;
  Timer? _apiKeepAliveTimer;

  List<Map<String, dynamic>> _listings = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadListingsFromDB();
    });
    _apiKeepAliveTimer = Timer.periodic(const Duration(minutes: 3), (_) {
      _refreshApiDataAfterResume();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _refreshApiDataAfterResume();
    }
  }

  Future<void> _refreshApiDataAfterResume() async {
    if (_isRefreshingAfterResume) return;

    final now = DateTime.now();
    final lastRefresh = _lastResumeRefreshAt;
    if (lastRefresh != null &&
        now.difference(lastRefresh) < const Duration(seconds: 20)) {
      return;
    }

    _isRefreshingAfterResume = true;
    _lastResumeRefreshAt = now;

    try {
      await context.read<AuthViewModel>().refreshLoggedInUser();
      final tasks = <Future<void>>[
        _loadListingsFromDB(),
        if (_selectedIndex == 1)
          _sellKey.currentState?.refreshApiDataAfterResume() ?? Future.value(),
      ];

      await Future.wait(tasks);
    } catch (e) {
      debugPrint('Resume API refresh error: $e');
    } finally {
      _isRefreshingAfterResume = false;
    }
  }

  Future<void> _loadListingsFromDB() async {
    final userId = context.read<AuthViewModel>().loggedInUser?.id ?? '';
    if (userId.isEmpty) return;
    try {
      final enquiries = await _repo.getData(
        tableName: 'enquiries',
        filter: {'userId': userId},
      );
      if (!mounted) return;
      setState(() {
        _listings = enquiries.map((e) => _mapEnquiryToListing(e)).toList();
      });
    } catch (e) {
      debugPrint('Load listings error: $e');
    }
  }



  Future<void> _openNotifications() async {
    await AppNotificationStore.markAllRead();
    if (!mounted) return;

    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const NotificationsPage()));
  }

  String _absoluteMediaUrl(String value) {
    if (value.startsWith('http://') || value.startsWith('https://'))
      return value;
    var clean = value.startsWith('/') ? value.substring(1) : value;
    clean = clean.replaceFirst(RegExp(r'^(cashify/)?public/'), '');
    return '${ApiConstants.MEDIA_BASE_URL}$clean';
  }

  Map<String, String> _agentInfoFromEnquiry(Map<String, dynamic> e) {
    Map<String, dynamic>? parseAgentPayload(dynamic value) {
      if (value is Map) {
        return Map<String, dynamic>.from(value);
      }

      if (value is! String || value.trim().isEmpty) return null;

      var trimmed = value.trim();
      trimmed = trimmed
          .replaceAll('&quot;', '"')
          .replaceAll('&#34;', '"')
          .replaceAll('&apos;', "'")
          .replaceAll(r'\"', '"')
          .replaceAll(r"\'", "'");

      final jsonStart = trimmed.indexOf('{');
      final jsonEnd = trimmed.lastIndexOf('}');
      if (jsonStart == -1 || jsonEnd <= jsonStart) return null;

      final jsonText = trimmed.substring(jsonStart, jsonEnd + 1);
      final candidates = [jsonText, jsonText.replaceAll("'", '"')];

      for (final candidate in candidates) {
        try {
          final decoded = jsonDecode(candidate);
          if (decoded is Map) {
            return Map<String, dynamic>.from(decoded);
          }
        } catch (_) {
          // Try the next relaxed candidate.
        }
      }

      final nameMatch = RegExp(
        r'''["']name["']\s*:\s*["']([^"']+)["']''',
        caseSensitive: false,
      ).firstMatch(jsonText);
      final mobileMatch = RegExp(
        r'''["'](?:mobile|contact|phone|number|contactNumber|mobileNumber|agentNumber)["']\s*:\s*["']?([0-9+\-\s]+)["']?''',
        caseSensitive: false,
      ).firstMatch(jsonText);

      if (nameMatch != null || mobileMatch != null) {
        return {
          if (nameMatch != null) 'name': nameMatch.group(1),
          if (mobileMatch != null) 'mobile': mobileMatch.group(1),
        };
      }

      return null;
    }

    String valueFrom(Map<String, dynamic>? data, List<String> keys) {
      if (data == null) return '';
      for (final key in keys) {
        final value = data[key]?.toString().trim() ?? '';
        if (value.isNotEmpty) return value;
      }
      return '';
    }

    const payloadNameKeys = [
      'name',
      'agentName',
      'agent_name',
      'assignedAgentName',
      'assigned_agent_name',
      'pickupAgentName',
      'pickup_agent_name',
      'agent',
      'agentDetail',
      'agent_detail',
    ];
    const payloadMobileKeys = [
      'mobile',
      'agentMobile',
      'agent_mobile',
      'agentContact',
      'agent_contact',
      'agentPhone',
      'agent_phone',
      'pickupAgentMobile',
      'pickup_agent_mobile',
      'assignedAgentMobile',
      'assigned_agent_mobile',
      'assignAgentMobile',
      'assign_agent_mobile',
      'agentNumber',
      'agent_number',
      'contactNumber',
      'contact_number',
      'mobileNumber',
      'mobile_number',
      'contact',
      'phone',
      'number',
    ];
    const directNameKeys = [
      'agentName',
      'agent_name',
      'assignedAgentName',
      'assigned_agent_name',
      'pickupAgentName',
      'pickup_agent_name',
      'assignedAgent',
      'assigned_agent',
      'pickupAgent',
      'pickup_agent',
      'agentAssigned',
      'agent_assigned',
    ];
    const directMobileKeys = [
      'agentMobile',
      'agent_mobile',
      'agentContact',
      'agent_contact',
      'agentPhone',
      'agent_phone',
      'pickupAgentMobile',
      'pickup_agent_mobile',
      'assignedAgentMobile',
      'assigned_agent_mobile',
      'assignAgentMobile',
      'assign_agent_mobile',
      'agentNumber',
      'agent_number',
      'contactNumber',
      'contact_number',
      'mobileNumber',
      'mobile_number',
      'number',
    ];

    final directName = valueFrom(e, directNameKeys);
    final directMobile = valueFrom(e, directMobileKeys);

    final preferredPayload =
        e['agent'] ??
        e['agentDetail'] ??
        e['agent_detail'] ??
        e['agentDetails'] ??
        e['agent_details'] ??
        e['assignedAgent'] ??
        e['assigned_agent'] ??
        e['pickupAgent'] ??
        e['pickup_agent'] ??
        e['pickupAgentDetail'] ??
        e['pickup_agent_detail'] ??
        e['pickupAgentDetails'] ??
        e['pickup_agent_details'] ??
        e['assignAgent'] ??
        e['assign_agent'] ??
        e['agentAssigned'] ??
        e['agent_assigned'] ??
        e['agentData'] ??
        e['agent_data'];

    Map<String, dynamic>? payloadMap = parseAgentPayload(preferredPayload);

    if (payloadMap == null) {
      for (final value in e.values) {
        final parsed = parseAgentPayload(value);
        if (valueFrom(parsed, payloadNameKeys).isNotEmpty ||
            valueFrom(parsed, payloadMobileKeys).isNotEmpty) {
          payloadMap = parsed;
          break;
        }
      }
    }

    final payloadName = valueFrom(payloadMap, payloadNameKeys);
    final payloadMobile = valueFrom(payloadMap, payloadMobileKeys);

    return {
      'name': payloadName.isNotEmpty ? payloadName : directName,
      'mobile': payloadMobile.isNotEmpty ? payloadMobile : directMobile,
    };
  }

  String _mapEnquiryStatus(Map<String, dynamic> e) {
    final rawStatus =
        e['status'] ??
        e['orderStatus'] ??
        e['order_status'] ??
        e['pickupStatus'] ??
        e['pickup_status'] ??
        e['enquiryStatus'] ??
        e['enquiry_status'] ??
        '0';

    final value = rawStatus.toString().trim();
    final normalized = value
        .toLowerCase()
        .replaceAll(RegExp(r'[\s_-]+'), ' ')
        .trim();
    final numericStatus = int.tryParse(value);

    if (numericStatus == 1 ||
        normalized == 'agent assigned' ||
        normalized == 'assigned') {
      return 'Agent Assigned';
    }
    if (numericStatus == 2 ||
        normalized == 'pickup scheduled' ||
        normalized == 'scheduled') {
      return 'Pickup Scheduled';
    }
    if (numericStatus == 3 ||
        normalized == 'payment processed' ||
        normalized == 'completed' ||
        normalized == 'payment done') {
      return 'Payment Processed';
    }
    if (numericStatus == 4 ||
        numericStatus == 5 ||
        normalized == 'cancelled' ||
        normalized == 'canceled' ||
        normalized == 'cancelled by user') {
      return 'Cancelled';
    }

    return 'Pending';
  }

  Map<String, dynamic> _mapEnquiryToListing(Map<String, dynamic> e) {
    final brand = e['brandName']?.toString() ?? e['brand']?.toString() ?? '';
    final model = e['modelName']?.toString() ?? e['model']?.toString() ?? '';
    final storage =
        e['variantName']?.toString() ??
        e['storage']?.toString() ??
        e['variantId']?.toString() ??
        '';
    final basePrice =
        e['basePrice']?.toString() ??
        e['base_price']?.toString() ??
        e['baseprice']?.toString() ??
        e['price']?.toString() ??
        '0';
    final finalPrice =
        e['finalPrice']?.toString() ??
        e['final_price']?.toString() ??
        e['finalprice']?.toString() ??
        e['price']?.toString() ??
        '0';
    final price = finalPrice;
    final rawDate = e['createdAt']?.toString() ?? e['date']?.toString() ?? '';
    final pickupDateTime =
        e['pickupDateTime']?.toString() ??
        e['pickup_date_time']?.toString() ??
        e['pickupDate']?.toString() ??
        e['pickup_date']?.toString() ??
        e['scheduledDateTime']?.toString() ??
        e['scheduled_date_time']?.toString() ??
        '';
    final status = _mapEnquiryStatus(e);
    final id = e['id']?.toString() ?? e['enquiryId']?.toString() ?? '';
    final address = e['address']?.toString() ?? '';
    final bank = e['bankDetail']?.toString() ?? '';
    final cancelReason = e['cancelReason']?.toString() ?? '';
    final agentInfo = _agentInfoFromEnquiry(e);

    final fullName = (model.contains(brand) || brand.isEmpty)
        ? model
        : '$brand $model';

    Color statusColor;
    Color statusTextColor;
    switch (status) {
      case 'Cancelled':
        statusColor = const Color(0xFFFEE2E2);
        statusTextColor = const Color(0xFFDC2626);
        break;
      case 'Payment Processed':
        statusColor = const Color(0xFFDCFCE7);
        statusTextColor = const Color(0xFF16A34A);
        break;
      case 'Agent Assigned':
      case 'Pickup Scheduled':
        statusColor = const Color(0xFFEFF6FF);
        statusTextColor = const Color(0xFF2563EB);
        break;
      default:
        statusColor = const Color(0xFFFFF7ED);
        statusTextColor = const Color(0xFFEA580C);
    }

    final rawImage =
        e['modelImage']?.toString() ??
        e['model_image']?.toString() ??
        e['modelImg']?.toString() ??
        e['image']?.toString() ??
        '';
    final imageUrl = rawImage.isNotEmpty ? _absoluteMediaUrl(rawImage) : null;

    return {
      'title': fullName,
      'specs': storage,
      'price': price,
      'basePrice': basePrice,
      'finalPrice': finalPrice,
      'id': id.isNotEmpty ? id : currentOrderID,
      'date': rawDate,
      'listingDate': rawDate,
      'pickupDateTime': pickupDateTime,
      'status': status,
      'image': 'assets/iphone_normal.png',
      'imageUrl': imageUrl,
      'statusColor': statusColor,
      'statusTextColor': statusTextColor,
      'address': address,
      'bankDetail': bank,
      'cancelReason': cancelReason,
      'latitude': e['latitude']?.toString() ?? '',
      'longitude':
          e['longtitude']?.toString() ?? e['longitude']?.toString() ?? '',
      // Agent info (assigned by admin panel)
      'agentName': agentInfo['name'] ?? '',
      'agentMobile': agentInfo['mobile'] ?? '',
      'agentId': e['agentId']?.toString() ?? e['agent_id']?.toString() ?? '',
      'rawEnquiry': e,
    };
  }

  void _cancelListing(String id, String reason) {
    setState(() {
      final idx = _listings.indexWhere((l) => l['id'] == id);
      if (idx != -1) {
        _listings[idx]['status'] = 'Cancelled';
        _listings[idx]['cancelReason'] = reason;
        _listings[idx]['statusColor'] = const Color(0xFFFEE2E2);
        _listings[idx]['statusTextColor'] = const Color(0xFFDC2626);
      }
      _selectedIndex = 2;
    });
  }

  void _cancelOrder(String id, String reason) {
    setState(() {
      final idx = _listings.indexWhere((l) => l['id'] == id);
      if (idx != -1) {
        _listings[idx]['status'] = 'Cancelled';
        _listings[idx]['cancelReason'] = reason;
        _listings[idx]['statusColor'] = const Color(0xFFFEE2E2);
        _listings[idx]['statusTextColor'] = const Color(0xFFDC2626);
      }
      _selectedIndex = 2;
    });
  }

  void _navigateToCancelledListings() {
    setState(() {
      _selectedIndex = 2;
    });
  }

  void _onTabTapped(int index) {
    setState(() {
      if (index == 1) {
        final ts = DateTime.now().millisecondsSinceEpoch;
        currentOrderID = '#PC-${(ts % 900000 + 100000)}';
        _sellInitialBrandName = null;
        _sellInitialModelName = null;
        _sellOpenBrandSelection = false;
      }
      if (index == 3) {
        _profileResetSignal++;
      }
      _selectedIndex = index;
    });
    if (index == 2) {
      _loadListingsFromDB();
    }
  }

  void _handleBack() {
    if (_selectedIndex == 1) {
      final handledBySell = _sellKey.currentState?.handleBack() ?? false;
      if (!handledBySell) {
        setState(() => _selectedIndex = 0);
      }
    } else if (_selectedIndex != 0) {
      setState(() => _selectedIndex = 0);
    } else {
      final now = DateTime.now();
      final shouldExit =
          _lastHomeBackPressedAt != null &&
          now.difference(_lastHomeBackPressedAt!) < const Duration(seconds: 2);

      if (shouldExit) {
        SystemNavigator.pop();
        return;
      }

      _lastHomeBackPressedAt = now;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Press back again to exit'),
            duration: Duration(seconds: 2),
          ),
        );
    }
  }

  void _addListing(
    String brand,
    String model,
    String storage,
    int price,
    String date, [
    String address = '',
    String bankDetail = '',
    String latitude = '',
    String longitude = '',
  ]) {
    final String fullName = model.contains(brand) ? model : "$brand $model";
    setState(() {
      _listings.insert(0, {
        'title': fullName,
        'specs': storage,
        'price': price.toString(),
        'id': currentOrderID,
        'date': date,
        'listingDate': 'Now',
        'pickupDateTime': date,
        'status': 'Under Review',
        'image': 'assets/iphone_normal.png',
        'statusColor': const Color(0xFFFFF7ED),
        'statusTextColor': const Color(0xFFEA580C),
        'address': address,
        'bankDetail': bankDetail,
        'latitude': latitude,
        'longitude': longitude,
      });
    });
    Future.delayed(const Duration(milliseconds: 800), _loadListingsFromDB);
  }

  @override
  void dispose() {
    _apiKeepAliveTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
          titleSpacing: 12,
          title: Row(
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 116),
                child: Image.asset(
                  'assets/selorize_text.png',
                  height: 34,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 12),
              // Location Selector
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 170),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: GestureDetector(
                      onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                            builder: (context) => const StateSelectionView(isFromHome: true),
                            ),
                          );
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: context.watch<AuthViewModel>().selectedCity == null
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF6366F1),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              () {
                                final vm = context.watch<AuthViewModel>();
                                if (vm.selectedCity == null || vm.selectedCity!.isEmpty) return 'Select Location';
                                if (vm.selectedState != null && vm.selectedState!.isNotEmpty) return '${vm.selectedState}/${vm.selectedCity}';
                                return vm.selectedCity!;
                              }(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: context.watch<AuthViewModel>().selectedCity == null
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF0F172A),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                                  ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: Color(0xFF94A3B8),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 34,
                height: 34,
                child: Center(
                  child: ValueListenableBuilder<List<AppNotificationItem>>(
                    valueListenable: AppNotificationStore.notifications,
                    builder: (context, notifications, _) {
                      final unread = notifications
                          .where((n) => !n.isRead)
                          .length;
                      return GestureDetector(
                        onTap: _openNotifications,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Image.asset(
                              unread > 0
                                  ? 'assets/notification_active.png'
                                  : 'assets/notification_empty.png',
                              width: 27,
                              height: 27,
                              fit: BoxFit.contain,
                            ),
                            if (unread > 0)
                              Positioned(
                                right: -7,
                                top: -4,
                                child: Container(
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444),
                                    borderRadius: BorderRadius.circular(99),
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 1.4,
                                    ),
                                  ),
                                  child: Text(
                                    unread > 9 ? '9+' : unread.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        body: _selectedIndex == 0
            ? HomeContent(
                onStartSelling:
                    ({
                      String? brandName,
                      String? modelName,
                      bool openBrandSelection = false,
                    }) {
                      setState(() {
                        final ts = DateTime.now().millisecondsSinceEpoch;
                        currentOrderID = '#PC-${(ts % 900000 + 100000)}';
                        _sellInitialBrandName = brandName;
                        _sellInitialModelName = modelName;
                        _sellOpenBrandSelection = openBrandSelection;
                        _selectedIndex = 1;
                      });
                    },
              )
            : _selectedIndex == 1
            ? SellScreen(
                key: _sellKey,
                currentOrderID: currentOrderID,
                initialBrandName: _sellInitialBrandName,
                initialModelName: _sellInitialModelName,
                openBrandSelection: _sellOpenBrandSelection,
                onExitToHome: () {
                  setState(() {
                    _sellInitialBrandName = null;
                    _sellInitialModelName = null;
                    _sellOpenBrandSelection = false;
                    _selectedIndex = 0;
                  });
                },
                onCancelListing: (id, reason) => _cancelListing(id, reason),
                onNavigateToCancelledListings: _navigateToCancelledListings,
                onNavigateToListings: () {
                  setState(() {
                    _selectedIndex = 2;
                  });
                },
                onFinish:
                    (
                      brand,
                      model,
                      storage,
                      price,
                      date,
                      address,
                      bankDetail,
                      latitude,
                      longitude,
                    ) {
                      _addListing(
                        brand,
                        model,
                        storage,
                        price,
                        date,
                        address,
                        bankDetail,
                        latitude,
                        longitude,
                      );
                    },
                onReset: () {
                  setState(() {
                    _sellInitialBrandName = null;
                    _sellInitialModelName = null;
                    _selectedIndex = 0;
                  });
                },
              )
            : _selectedIndex == 2
            ? OrdersScreen(
                orders: _listings,
                onCancelOrder: (id, reason) => _cancelOrder(id, reason),
              )
            : ProfileScreen(
                resetSignal: _profileResetSignal,
                onNavigateToSell: () {
                  setState(() {
                    final ts = DateTime.now().millisecondsSinceEpoch;
                    currentOrderID = '#PC-${(ts % 900000 + 100000)}';
                    _sellInitialBrandName = null;
                    _sellInitialModelName = null;
                    _selectedIndex = 1;
                  });
                },
              ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            elevation: 0,
            selectedItemColor: const Color(0xFF6366F1),
            unselectedItemColor: const Color(0xFF94A3B8),
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
            currentIndex: _selectedIndex,
            onTap: _onTabTapped,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_rounded),
                activeIcon: Icon(Icons.home_filled),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.sell_outlined),
                activeIcon: Icon(Icons.sell),
                label: 'Sell',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.shopping_bag_outlined),
                activeIcon: Icon(Icons.shopping_bag),
                label: 'Orders',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline_rounded),
                activeIcon: Icon(Icons.person_rounded),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  String _timeLabel(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Color(0xFF0F172A),
                        size: 19,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Notifications',
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  ValueListenableBuilder<List<AppNotificationItem>>(
                    valueListenable: AppNotificationStore.notifications,
                    builder: (context, notifications, _) {
                      if (notifications.isEmpty) return const SizedBox();
                      return TextButton(
                        onPressed: AppNotificationStore.clear,
                        child: const Text(
                          'Clear',
                          style: TextStyle(
                            color: Color(0xFF6366F1),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: ValueListenableBuilder<List<AppNotificationItem>>(
                valueListenable: AppNotificationStore.notifications,
                builder: (context, notifications, _) {
                  if (notifications.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.notifications_none_rounded,
                              color: Color(0xFFCBD5E1),
                              size: 62,
                            ),
                            SizedBox(height: 14),
                            Text(
                              'No notifications yet',
                              style: TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Updates from Selorize will appear here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                    itemCount: notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = notifications[index];
                      return Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.025),
                              blurRadius: 14,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: item.isRead
                                    ? const Color(0xFFF1F5F9)
                                    : const Color(0xFF6366F1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.notifications_rounded,
                                color: item.isRead
                                    ? const Color(0xFF64748B)
                                    : Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.title,
                                          style: const TextStyle(
                                            color: Color(0xFF0F172A),
                                            fontSize: 15,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _timeLabel(item.createdAt),
                                        style: const TextStyle(
                                          color: Color(0xFF94A3B8),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (item.body.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      item.body,
                                      style: const TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 13,
                                        height: 1.4,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeContent extends StatefulWidget {
  final void Function({
    String? brandName,
    String? modelName,
    bool openBrandSelection,
  })
  onStartSelling;
  const HomeContent({super.key, required this.onStartSelling});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  static List<Map<String, dynamic>> _cachedBrands = [];
  static List<Map<String, dynamic>> _cachedModels = [];
  static List<Map<String, dynamic>> _cachedTestimonials = [];

  final AuthRepository _repo = AuthRepository();
  final TextEditingController _homeSearchController = TextEditingController();
  late List<Map<String, dynamic>> _apiBrands;
  late List<Map<String, dynamic>> _apiModels;
  late List<Map<String, dynamic>> _apiTestimonials;
  List<Map<String, String>> _homeSearchResults = [];
  String _homeSearchQuery = '';
  bool _isLoadingBrands = false;
  bool _isLoading = true; // full-page skeleton
  String? _homeBrandErrorMessage;
  String? _testimonialErrorMessage;
  final Set<String> _preloadedImageUrls = {};
  bool _homeBrandImagesReady = false;

  @override
  void initState() {
    super.initState();
    _apiBrands = List<Map<String, dynamic>>.from(_cachedBrands);
    _apiModels = List<Map<String, dynamic>>.from(_cachedModels);
    _apiTestimonials = List<Map<String, dynamic>>.from(_cachedTestimonials);
    _isLoading =
        _apiBrands.isEmpty || _apiModels.isEmpty || !_homeBrandImagesReady;
    _bootstrapHomeData();
  }

  Future<void> _bootstrapHomeData() async {
    await _restoreHomeDeviceCache();
    if (!mounted) return;
    await _loadPopularBrands();
  }

  Future<void> _restoreHomeDeviceCache() async {
    if (_apiBrands.isNotEmpty && _apiModels.isNotEmpty) return;

    final results = await Future.wait([
      DeviceDataCache.loadTable('brand'),
      DeviceDataCache.loadTable('model'),
      DeviceDataCache.loadTable('testimonial'),
    ]);
    if (!mounted) return;

    setState(() {
      if (_apiBrands.isEmpty && results[0].isNotEmpty) {
        _apiBrands = results[0];
        _cachedBrands = List<Map<String, dynamic>>.from(results[0]);
      }
      if (_apiModels.isEmpty && results[1].isNotEmpty) {
        _apiModels = results[1];
        _cachedModels = List<Map<String, dynamic>>.from(results[1]);
      }
      if (_apiTestimonials.isEmpty && results[2].isNotEmpty) {
        _apiTestimonials = results[2];
        _cachedTestimonials = List<Map<String, dynamic>>.from(results[2]);
      }
      if (_apiBrands.isNotEmpty) {
        _homeBrandErrorMessage = null;
      }
    });
    await _prepareHomeBrandImages(_apiBrands);
    if (!mounted) return;
    setState(() {
      _homeBrandImagesReady = true;
      if (_apiBrands.isNotEmpty && _apiModels.isNotEmpty) _isLoading = false;
    });
  }

  Future<void> _loadPopularBrands() async {
    final hadDeviceData = _apiBrands.isNotEmpty || _apiModels.isNotEmpty;
    final hadTestimonials = _apiTestimonials.isNotEmpty;

    setState(() {
      _isLoadingBrands = true;
      _isLoading = !hadDeviceData || !_homeBrandImagesReady;
      if (hadDeviceData) _homeBrandErrorMessage = null;
      if (hadTestimonials) _testimonialErrorMessage = null;
    });

    try {
      final testimonialsFuture = _tryLoadHomeTable('testimonial');
      final brandsFuture = _tryLoadHomeTable('brand');
      final modelsFuture = _tryLoadHomeTable('model');
      final brands = await brandsFuture;
      if (!mounted) return;

      if (brands != null && brands.isNotEmpty) {
        setState(() {
          _apiBrands = brands;
          _cachedBrands = List<Map<String, dynamic>>.from(brands);
          _homeBrandErrorMessage = null;
        });
        unawaited(_prepareHomeBrandImages(brands));
        unawaited(DeviceDataCache.saveTable('brand', brands));
      }

      final models = await modelsFuture;
      if (!mounted) return;

      setState(() {
        if (models != null && models.isNotEmpty) {
          _apiModels = models;
          _cachedModels = List<Map<String, dynamic>>.from(models);
          unawaited(DeviceDataCache.saveTable('model', models));
        }

        if (_apiBrands.isNotEmpty) {
          _homeBrandErrorMessage = null;
        } else if (!hadDeviceData) {
          _homeBrandErrorMessage =
              'Could not load device data. Please check your network and try again.';
        } else {
          _homeBrandErrorMessage = null;
        }
      });
      await _prepareHomeBrandImages(_apiBrands);
      if (!mounted) return;
      setState(() => _homeBrandImagesReady = true);
      _loadHomeTestimonialsInBackground(testimonialsFuture, hadTestimonials);
    } catch (e) {
      debugPrint('Home brands error: $e');
      if (mounted) {
        setState(() {
          if (!hadDeviceData) {
            _homeBrandErrorMessage =
                'Could not load device data. Please check your network and try again.';
          } else {
            _homeBrandErrorMessage = null;
          }
          if (!hadTestimonials) {
            _testimonialErrorMessage =
                'Could not load testimonials. Please check your network and try again.';
          } else {
            _testimonialErrorMessage = null;
          }
        });
      }
    } finally {
      if (mounted)
        setState(() {
          _isLoadingBrands = false;
          _isLoading = false;
        });
    }
  }

  Future<void> _loadHomeTestimonialsInBackground(
    Future<List<Map<String, dynamic>>?> testimonialsFuture,
    bool hadTestimonials,
  ) async {
    final testimonials = await testimonialsFuture;
    if (!mounted) return;

    setState(() {
      if (testimonials != null) {
        _apiTestimonials = testimonials;
        if (testimonials.isNotEmpty) {
          _cachedTestimonials = List<Map<String, dynamic>>.from(testimonials);
          unawaited(DeviceDataCache.saveTable('testimonial', testimonials));
        }
      }
      if (_apiTestimonials.isEmpty && !hadTestimonials) {
        _testimonialErrorMessage = 'Testimonials are not available right now.';
      } else {
        _testimonialErrorMessage = null;
      }
    });
  }

  Future<List<Map<String, dynamic>>?> _tryLoadHomeTable(
    String tableName, {
    Map<String, dynamic> filter = const {},
  }) async {
    try {
      return await _repo.getData(tableName: tableName, filter: filter);
    } catch (e) {
      debugPrint('Optional home data error [$tableName]: $e');
      return null;
    }
  }

  @override
  void dispose() {
    _homeSearchController.dispose();
    super.dispose();
  }

  void _onHomeSearchChanged(String value) {
    final query = value.toLowerCase().trim();
    final seen = <String>{};
    final results = <Map<String, String>>[];

    if (query.isNotEmpty) {
      for (final model in _apiModels) {
        final modelName = model['modelName']?.toString().trim() ?? '';
        if (modelName.isEmpty) continue;

        final brandName = _brandNameForModel(model);
        final searchable = '$brandName $modelName'.toLowerCase();
        if (!searchable.contains(query) ||
            seen.contains('$brandName|$modelName')) {
          continue;
        }

        seen.add('$brandName|$modelName');
        final imageUrl = _modelImageUrl(model);
        results.add({
          'brandName': brandName,
          'modelName': modelName,
          if (imageUrl != null) 'imageUrl': imageUrl,
        });
      }
    }

    setState(() {
      _homeSearchQuery = value;
      _homeSearchResults = results.take(8).toList();
    });
  }

  String _brandNameForModel(Map<String, dynamic> model) {
    final modelBrandId = model['brandId']?.toString();
    for (final brand in _apiBrands) {
      if (brand['id']?.toString() == modelBrandId) {
        return brand['brandName']?.toString() ?? '';
      }
    }
    return model['brandName']?.toString() ?? '';
  }

  String? _modelImageUrl(Map<String, dynamic> model) {
    const imageKeys = [
      'modelImage',
      'model_image',
      'mobilePhoto',
      'mobile_photo',
      'mobileImage',
      'mobile_image',
      'phoneImage',
      'phone_image',
      'image',
      'imageUrl',
      'image_url',
      'photo',
      'photoUrl',
      'photo_url',
      'file',
      'fileName',
      'filename',
      'path',
    ];

    for (final key in imageKeys) {
      final value = model[key]?.toString().trim();
      if (value != null && value.isNotEmpty && value.toLowerCase() != 'null') {
        return _absoluteMediaUrl(value);
      }
    }

    for (final value in model.values) {
      final rawValue = value?.toString().trim();
      if (rawValue == null || rawValue.isEmpty) continue;

      final lowerValue = rawValue.toLowerCase();
      final looksLikeImage =
          lowerValue.contains('.png') ||
          lowerValue.contains('.jpg') ||
          lowerValue.contains('.jpeg') ||
          lowerValue.contains('.webp');

      if (looksLikeImage) return _absoluteMediaUrl(rawValue);
    }

    return null;
  }

  void _openSell({
    String? brandName,
    String? modelName,
    bool openBrandSelection = false,
  }) {
    _homeSearchController.clear();
    setState(() {
      _homeSearchQuery = '';
      _homeSearchResults = [];
    });
    widget.onStartSelling(
      brandName: brandName,
      modelName: modelName,
      openBrandSelection: openBrandSelection,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: _isLoading,
      ignoreContainers: true,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Elegant Banner Section
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              padding: const EdgeInsets.only(left: 20, top: 20, bottom: 0),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEEF2FF), Color(0xFFFFFFFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.white),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withOpacity(0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: const Text(
                              'TRUSTED PLATFORM',
                              style: TextStyle(
                                color: Color(0xFF6366F1),
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Sell Your Old\nPhone Instantly',
                            style: TextStyle(
                              fontSize: 27,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              height: 1.1,
                              letterSpacing: -1.0,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Get the best price in seconds',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF475569),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 18),
                          ElevatedButton(
                            onPressed: () =>
                                _openSell(openBrandSelection: true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 13,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 8,
                              shadowColor: const Color(
                                0xFF0F172A,
                              ).withOpacity(0.3),
                            ),
                            child: const Text(
                              'Get Best Value',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Transform.translate(
                      offset: const Offset(0, -60),
                      child: Align(
                        alignment: Alignment.bottomRight,
                        child: Hero(
                          tag: 'phone-hero',
                          child: Image.asset(
                            'assets/home_phone.png',
                            fit: BoxFit.contain,
                            height: 186,
                            alignment: Alignment.bottomRight,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(
                    'Popular Brands',
                    () => _openSell(openBrandSelection: true),
                  ),
                  const SizedBox(height: 12),

                  // Modern Glass Search Bar
                  Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _homeSearchController,
                          onChanged: _onHomeSearchChanged,
                          onSubmitted: (_) {
                            if (_homeSearchResults.isNotEmpty) {
                              final first = _homeSearchResults.first;
                              _openSell(
                                brandName: first['brandName'],
                                modelName: first['modelName']!.isEmpty
                                    ? null
                                    : first['modelName'],
                              );
                            }
                          },
                          decoration: InputDecoration(
                            hintText: 'Search your phone model...',
                            hintStyle: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              color: Color(0xFF6366F1),
                            ),
                            suffixIcon: _homeSearchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      color: Color(0xFF94A3B8),
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      _homeSearchController.clear();
                                      _onHomeSearchChanged('');
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                      if (_homeSearchResults.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            itemCount: _homeSearchResults.length,
                            separatorBuilder: (_, __) => const Divider(
                              height: 1,
                              color: Color(0xFFF1F5F9),
                            ),
                            itemBuilder: (context, index) {
                              final result = _homeSearchResults[index];
                              final brandName = result['brandName'] ?? '';
                              final modelName = result['modelName'] ?? '';
                              final imageUrl = result['imageUrl'];
                              return ListTile(
                                dense: true,
                                leading: _buildSearchModelImage(imageUrl),
                                title: Text(
                                  modelName.isEmpty ? brandName : modelName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                subtitle: brandName.isEmpty || modelName.isEmpty
                                    ? null
                                    : Text(
                                        brandName,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                trailing: const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 14,
                                  color: Color(0xFF94A3B8),
                                ),
                                onTap: () => _openSell(
                                  brandName: brandName,
                                  modelName: modelName.isEmpty
                                      ? null
                                      : modelName,
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  _buildPopularBrands(_openSell),

                  const SizedBox(height: 28),
                  _buildSectionHeader('How It Works', null),
                  const SizedBox(height: 14),
                  IntrinsicHeight(
                    child: Row(
                      children: [
                        _buildStepCard(
                          '01',
                          'Select Your\nPhone',
                          Icons.devices_other_rounded,
                          const Color(0xFFFFF7ED),
                          Colors.orange,
                        ),
                        const SizedBox(width: 12),
                        _buildStepCard(
                          '02',
                          'Answer a few\nQuestions',
                          Icons.fact_check_rounded,
                          const Color(0xFFEFF6FF),
                          Colors.blue,
                        ),
                        const SizedBox(width: 12),
                        _buildStepCard(
                          '03',
                          'Get Price &\nSchedule Pickup',
                          Icons.account_balance_wallet_rounded,
                          const Color(0xFFF0FDF4),
                          Colors.green,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),
                  _buildSectionHeader('Key Benefits', null),
                  const SizedBox(height: 14),
                  IntrinsicHeight(
                    child: Row(
                      children: [
                        _buildBenefitCard(
                          'Best Price\nGuarantee',
                          'assets/best_price.png',
                          const Color(0xFFFBBF24),
                        ),
                        const SizedBox(width: 12),
                        _buildBenefitCard(
                          'Free Doorstep\nPickup',
                          'assets/pickup.png',
                          const Color(0xFF3B82F6),
                        ),
                        const SizedBox(width: 12),
                        _buildBenefitCard(
                          'Instant\nPayment',
                          'assets/payment.png',
                          const Color(0xFFEC4899),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Premium Rated Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.star_rounded,
                            color: Color(0xFFFBBF24),
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '4.8/5.0 Rated',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              Text(
                                'Join 500,000+ satisfied sellers',
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Colors.white24,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),

            // User Testimonials
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28),
              color: const Color(0xFFF8FAFC),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'User Testimonials',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildTestimonialsSection(),
                ],
              ),
            ),

            // Why Choose Us
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
              child: Column(
                children: [
                  const Text(
                    'Why Choose Us?',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                      letterSpacing: -1.0,
                    ),
                  ),
                  const SizedBox(height: 18),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.95,
                    children: [
                      _buildModernChooseUsItem(
                        'Verified Sellers',
                        'Safety first process',
                        Icons.verified_user_rounded,
                        const Color(0xFF6366F1),
                      ),
                      _buildModernChooseUsItem(
                        'Secured Payments',
                        'Encrypted transfers',
                        Icons.security_rounded,
                        const Color(0xFF10B981),
                      ),
                      _buildModernChooseUsItem(
                        'Fast Listings',
                        'Sell in 60 seconds',
                        Icons.bolt_rounded,
                        const Color(0xFFF59E0B),
                      ),
                      _buildModernChooseUsItem(
                        '24/7 Support',
                        'Always here to help',
                        Icons.support_agent_rounded,
                        const Color(0xFF8B5CF6),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),
          ],
        ),
      ), // SingleChildScrollView
    ); // Skeletonizer
  }

  Widget _buildSectionHeader(String title, VoidCallback? onSeeAll) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
            letterSpacing: -0.5,
          ),
        ),
        if (onSeeAll != null)
          TextButton(
            onPressed: onSeeAll,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF6366F1),
            ),
            child: const Text(
              'See All',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ),
      ],
    );
  }

  Widget _buildPopularBrands(
    void Function({String? brandName, String? modelName}) onTap,
  ) {
    final brands = _displayBrands;
    final displayBrands = _isLoadingBrands && brands.isEmpty
        ? List.generate(
            6,
            (_) => {'name': 'Loading', 'asset': 'assets/home_phone.png'},
          )
        : brands;
    return SizedBox(
      height: 84,
      child: displayBrands.isEmpty
          ? Center(
              child: Text(
                _homeBrandErrorMessage ??
                    'Device brands are not available right now.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: displayBrands.length,
              itemBuilder: (context, index) {
                final brand = displayBrands[index];
                final isPlaceholder = brand['name'] == 'Loading';
                return _buildBrandCard(
                  assetPath: brand['asset']!,
                  brandName: brand['name'] ?? '',
                  onTap: isPlaceholder
                      ? () {}
                      : () => onTap(brandName: brand['name']),
                  imageUrl: brand['imageUrl'],
                );
              },
            ),
    );
  }

  List<Map<String, String>> get _displayBrands {
    return _apiBrands
        .map((brand) {
          final name = brand['brandName']?.toString() ?? '';
          final imageUrl = _brandImageUrl(brand);
          final fallbackAsset = _brandAssetForName(name);

          return {
            'name': name,
            'asset': fallbackAsset,
            if (imageUrl != null) 'imageUrl': imageUrl,
          };
        })
        .where((brand) => brand['name']!.isNotEmpty)
        .toList();
  }

  Widget _buildBrandCard({
    required String assetPath,
    required String brandName,
    required VoidCallback onTap,
    String? imageUrl,
  }) {
    final fallback = Center(
      child: Text(
        _brandInitials(brandName),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFF334155),
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: _isLoadingBrands && imageUrl == null
                ? Image.asset(assetPath, fit: BoxFit.contain)
                : imageUrl == null
                ? fallback
                : _buildNetworkMedia(
                    url: imageUrl,
                    placeholder: _buildBrandImageSkeleton(),
                    errorPlaceholder: fallback,
                    fit: BoxFit.contain,
                  ),
          ),
        ),
      ),
    );
  }

  String _brandInitials(String name) {
    final cleanName = name.trim();
    if (cleanName.isEmpty || cleanName == 'Loading') return '';
    if (cleanName.length <= 10) return cleanName.toUpperCase();

    final parts = cleanName.split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final initials = parts.map((p) => p[0]).take(2).join().toUpperCase();
    return initials.isEmpty
        ? cleanName.substring(0, 1).toUpperCase()
        : initials;
  }

  Widget _buildSearchModelImage(String? imageUrl) {
    const fallback = Icon(
      Icons.phone_android_rounded,
      color: Color(0xFF6366F1),
      size: 24,
    );

    return Container(
      width: 44,
      height: 44,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: imageUrl == null
          ? fallback
          : _buildNetworkMedia(
              url: imageUrl,
              placeholder: _buildSearchImageSkeleton(),
              errorPlaceholder: fallback,
              fit: BoxFit.contain,
            ),
    );
  }

  String _brandAssetForName(String name) {
    return 'assets/home_phone.png';
  }

  String? _brandImageUrl(Map<String, dynamic> brand) {
    const imageKeys = [
      'brandImage',
      'brand_image',
      'brandLogo',
      'brand_logo',
      'brandImg',
      'brand_img',
      'image',
      'imageUrl',
      'image_url',
      'logo',
      'logoUrl',
      'logo_url',
      'icon',
      'file',
      'fileName',
      'filename',
      'path',
    ];

    for (final key in imageKeys) {
      final value = brand[key]?.toString().trim();
      if (value != null && value.isNotEmpty && value.toLowerCase() != 'null') {
        return _absoluteMediaUrl(value);
      }
    }

    for (final value in brand.values) {
      final rawValue = value?.toString().trim();
      if (rawValue == null || rawValue.isEmpty) continue;

      final lowerValue = rawValue.toLowerCase();
      final looksLikeImage =
          lowerValue.contains('.png') ||
          lowerValue.contains('.jpg') ||
          lowerValue.contains('.jpeg') ||
          lowerValue.contains('.webp') ||
          lowerValue.contains('.svg');

      if (looksLikeImage) return _absoluteMediaUrl(rawValue);
    }

    return null;
  }

  String _absoluteMediaUrl(String value) {
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }

    var cleanPath = value.startsWith('/') ? value.substring(1) : value;
    cleanPath = cleanPath.replaceFirst(RegExp(r'^(cashify/)?public/'), '');
    return '${ApiConstants.MEDIA_BASE_URL}$cleanPath';
  }

  void _warmHomeDeviceImages({
    Iterable<Map<String, dynamic>> brands = const [],
    Iterable<Map<String, dynamic>> models = const [],
  }) {
    if (!mounted) return;

    final urls = <String>[
      for (final brand in brands)
        ...[_brandImageUrl(brand)].whereType<String>(),
      for (final model in models)
        ...[_modelImageUrl(model)].whereType<String>(),
    ];

    _precacheNetworkImages(urls);
  }

  Future<void> _prepareHomeBrandImages(
    Iterable<Map<String, dynamic>> brands,
  ) async {
    final urls = brands
        .map(_brandImageUrl)
        .whereType<String>()
        .where((url) => url.trim().isNotEmpty)
        .take(12)
        .toList();

    if (urls.isEmpty || !mounted) return;

    final futures = urls.map((url) async {
      if (_isSvgUrl(url)) return;
      try {
        await precacheImage(CachedNetworkImageProvider(url), context);
        _preloadedImageUrls.add(url);
      } catch (error) {
        debugPrint('Home brand image prepare failed => $url | $error');
      }
    });

    await Future.any([
      Future.wait(futures),
      Future<void>.delayed(const Duration(milliseconds: 2500)),
    ]);
  }

  void _precacheNetworkImages(Iterable<String> urls) {
    final nextUrls = urls
        .where((url) => url.trim().isNotEmpty)
        .where((url) => !_isSvgUrl(url))
        .where((url) => _preloadedImageUrls.add(url))
        .take(64)
        .toList();

    if (nextUrls.isEmpty || !mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_precacheNetworkImagesInBackground(nextUrls));
    });
  }

  Future<void> _precacheNetworkImagesInBackground(List<String> urls) async {
    for (final url in urls) {
      if (!mounted) return;
      try {
        await precacheImage(CachedNetworkImageProvider(url), context);
      } catch (error) {
        _preloadedImageUrls.remove(url);
        debugPrint('Home image preload failed => $url | $error');
      }
      await Future<void>.delayed(const Duration(milliseconds: 4));
    }
  }

  bool _isSvgUrl(String url) {
    final cleanUrl = url.split('?').first.toLowerCase();
    return cleanUrl.endsWith('.svg');
  }

  Widget _buildNetworkMedia({
    required String url,
    required Widget placeholder,
    Widget? errorPlaceholder,
    double? height,
    double? width,
    BoxFit fit = BoxFit.contain,
  }) {
    if (_isSvgUrl(url)) {
      return SvgPicture.network(
        url,
        height: height,
        width: width,
        fit: fit,
        placeholderBuilder: (_) => placeholder,
        errorBuilder: (_, error, stackTrace) {
          debugPrint('Home svg image load failed => $url | $error');
          return errorPlaceholder ?? placeholder;
        },
      );
    }

    return CachedNetworkImage(
      imageUrl: url,
      height: height,
      width: width,
      fit: fit,
      filterQuality: FilterQuality.medium,
      placeholder: (context, url) => placeholder,
      errorWidget: (context, url, error) {
        debugPrint('Home image load failed => $url | $error');
        return errorPlaceholder ?? placeholder;
      },
    );
  }

  Widget _buildBrandImageSkeleton() {
    return Center(
      child: Container(
        height: 24,
        width: 46,
        decoration: BoxDecoration(
          color: const Color(0xFFE8EEF5),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildSearchImageSkeleton() {
    return Center(
      child: Container(
        height: 24,
        width: 16,
        decoration: BoxDecoration(
          color: const Color(0xFFE8EEF5),
          borderRadius: BorderRadius.circular(5),
        ),
      ),
    );
  }

  Widget _buildStepCard(
    String num,
    String title,
    IconData icon,
    Color bgColor,
    Color iconColor,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.01),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                height: 1.2,
              ),
            ),
            const Spacer(),
            Text(
              num,
              style: const TextStyle(
                color: Color(0xFFCBD5E1),
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitCard(String title, String assetPath, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              height: 58,
              width: 58,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Image.asset(assetPath, fit: BoxFit.contain),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 11,
                color: Color(0xFF0F172A),
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestimonialsSection() {
    final testimonials = _apiTestimonials.map(_testimonialFromApi).where((
      testimonial,
    ) {
      return testimonial['name']!.isNotEmpty &&
          testimonial['description']!.isNotEmpty;
    }).toList();

    if (testimonials.isEmpty && !_isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Center(
          child: Text(
            _testimonialErrorMessage ??
                'Testimonials are not available right now.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    final visibleTestimonials = testimonials.isNotEmpty
        ? testimonials
        : List.generate(
            4,
            (_) => {
              'name': 'Loading',
              'description': 'Loading testimonial details',
              'rating': '5',
              'imageUrl': '',
            },
          );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: visibleTestimonials.map((testimonial) {
            return _buildReviewCard(
              name: testimonial['name']!,
              review: testimonial['description']!,
              rating: int.tryParse(testimonial['rating']!) ?? 5,
              imageUrl: testimonial['imageUrl'],
            );
          }).toList(),
        ),
      ),
    );
  }

  Map<String, String> _testimonialFromApi(Map<String, dynamic> row) {
    final imageValue =
        row['userImage']?.toString().trim() ??
        row['user_image']?.toString().trim() ??
        row['image']?.toString().trim() ??
        '';

    return {
      'name': row['userName']?.toString().trim() ?? '',
      'description': row['description']?.toString().trim() ?? '',
      'rating': row['rating']?.toString().trim() ?? '5',
      if (imageValue.isNotEmpty && imageValue.toLowerCase() != 'null')
        'imageUrl': _absoluteMediaUrl(imageValue),
    };
  }

  Widget _buildReviewCard({
    required String name,
    required String review,
    required int rating,
    String? imageUrl,
  }) {
    return Container(
      width: 260,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildTestimonialAvatar(imageUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Row(
                      children: List.generate(
                        5,
                        (index) => Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: index < rating
                              ? const Color(0xFFFBBF24)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            review,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF475569),
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          const Icon(
            Icons.format_quote_rounded,
            color: Color(0xFFE2E8F0),
            size: 24,
          ),
        ],
      ),
    );
  }

  Widget _buildTestimonialAvatar(String? imageUrl) {
    const fallback = CircleAvatar(
      radius: 20,
      backgroundColor: Color(0xFFEFF6FF),
      child: Icon(Icons.person_rounded, color: Color(0xFF4A78A8), size: 22),
    );

    if (imageUrl == null || imageUrl.isEmpty) return fallback;

    return ClipOval(
      child: SizedBox(
        width: 40,
        height: 40,
        child: _buildNetworkMedia(
          url: imageUrl,
          placeholder: fallback,
          errorPlaceholder: fallback,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildModernChooseUsItem(
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 26, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
