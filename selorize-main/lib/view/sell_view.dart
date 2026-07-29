import 'dart:async';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lottie/lottie.dart' hide Marker;

import '../model/response/faq_response.dart';
import '../repository/auth_repository.dart';
import '../res/api_constants.dart';
import '../service/device_data_cache.dart';
import '../view_model/auth_viewmodel.dart';
import 'signup_view.dart';

class SellScreen extends StatefulWidget {
  final String currentOrderID;
  final String? initialBrandName;
  final String? initialModelName;
  final bool openBrandSelection;
  final Function(
    String brand,
    String model,
    String storage,
    int price,
    String date,
    String address,
    String bankDetail,
    String latitude,
    String longitude,
  )?
  onFinish;
  final VoidCallback? onReset;
  final VoidCallback? onExitToHome;
  final Function(String id, String reason)? onCancelListing;
  final VoidCallback? onNavigateToCancelledListings;
  final VoidCallback? onNavigateToListings;
  const SellScreen({
    super.key,
    this.onFinish,
    this.onReset,
    this.onExitToHome,
    required this.currentOrderID,
    this.initialBrandName,
    this.initialModelName,
    this.openBrandSelection = false,
    this.onCancelListing,
    this.onNavigateToCancelledListings,
    this.onNavigateToListings,
  });
  @override
  State<SellScreen> createState() => SellScreenState();
}

class SellScreenState extends State<SellScreen> {
  final AuthRepository _repo = AuthRepository();
  static List<Map<String, dynamic>> _cachedBrands = [];
  static List<Map<String, dynamic>> _cachedSeries = [];
  static List<Map<String, dynamic>> _cachedModels = [];
  static List<Map<String, dynamic>> _cachedVariants = [];

  bool _showBrandSelection = false;
  String _brandSearchQuery = '';
  String _modelListSearchQuery = '';
  List<Map<String, dynamic>> _modelSearchResults = [];
  String? _selectedBrand;
  String? _selectedModel;
  bool _showValuation = false;
  bool _showCondition = false;
  bool _showDefects = false;
  bool _showScreenCondition = false;
  bool _showDiscoloration = false;
  bool _showDentsCondition = false;
  bool _showBackPanelCondition = false;
  bool _showBentCondition = false;
  bool _showFunctionalCondition = false;
  bool _showAccessoriesCondition = false;
  bool _showAdminImageQuestion = false;
  bool _showCheckout = false;
  bool _showAddressSelection = false;
  bool _showAddAddress = false;
  bool _showPickupType = false;
  bool _showFinalReview = false;
  bool _showSuccess = false;
  bool _showCancelScreen = false;
  bool _showCancelSuccess = false;
  String _confirmedCancelReason = '';

  // Selection states for details
  String _selectedStorage = '';

  // Condition states (Yes/No)
  bool? _isScreenCracked;
  bool? _hasScratches;
  bool? _isBatteryLow;
  bool? _hasBillBox;
  bool? _powersOn;
  bool? _canMakeReceiveCalls;

  // Defect states (Multi-select)
  final Set<String> _selectedDefects = {};
  final Set<String> _selectedFunctionalProblems = {};
  final Set<String> _selectedAccessories = {};

  // Single-select conditions
  String? _selectedPhysicalCondition;
  String? _selectedDentsCondition;
  String? _selectedBackPanelCondition;
  String? _selectedBentCondition;
  String? _selectedDiscoloration;

  // Pickup states
  bool isInstantPickup = false;
  String _selectedPickupSlot = '10 AM - 3 PM';
  DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
  DateTime _selectedPickupDate = DateTime.now().add(const Duration(days: 1));
  late String finalOrderID;
  //ONE MAJOR ISSUE PURE APP ME HAI KI
  // Coupon state
  String? _appliedCoupon;
  int _couponDiscount = 0;
  int _enquiryBasePrice = 0;
  int _calculatedBasePrice = 0;
  bool _isLoadingQuestions = false;
  bool _isCalculatingPrice = false;
  bool _isLoadingSellData = false;
  bool _isLoadingCheckoutFaqs = false;
  String? _sellDataErrorMessage;
  String? _modelQuestionsErrorMessage;
  String? _checkoutFaqErrorMessage;
  bool _isSavingEnquiry = false;
  bool _isSavingAddress = false;
  bool _isSellLoginLoading = false;
  List<Map<String, dynamic>> _modelQuestions = [];
  final Map<String, String> _selectedAdminQuestionOptions = {};
  final Map<String, Set<String>> _selectedCheckboxQuestionOptions = {};
  int _adminImageQuestionIndex = 0;
  List<Map<String, dynamic>> _apiBrands = [];
  List<Map<String, dynamic>> _apiSeries = [];
  List<Map<String, dynamic>> _apiModels = [];
  List<Map<String, dynamic>> _seriesFilteredModels = [];
  List<Map<String, dynamic>> _apiVariants = [];
  List<Map<String, dynamic>> _apiCoupons = [];
  List<FaqItem> _checkoutFaqs = [];
  int _visibleCheckoutFaqCount = 4;
  Map<String, String>? _supportContact;
  List<Map<String, dynamic>> _savedAddresses = [];
  List<Map<String, dynamic>> _savedBankDetails = [];
  Map<String, dynamic>? _selectedPickupAddress;
  Map<String, dynamic>? _selectedBankDetail;
  String _pickupLatitude = '';
  String _pickupLongitude = '';
  bool _isFetchingLocation = false;
  bool _isFetchingManualLocation = false;
  final MapController _mapController = MapController();
  String _locationStatusMessage = '';
  String _fetchedAddress = '';
  bool _isFetchingAddress = false;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  Timer? _mapMoveDebounce;
  final TextEditingController _brandSearchController = TextEditingController();
  final TextEditingController _modelListSearchController =
      TextEditingController();
  final TextEditingController _couponController = TextEditingController();
  final TextEditingController _sellLoginMobileController =
      TextEditingController();
  final TextEditingController _sellLoginPasswordController =
      TextEditingController();
  final TextEditingController _addressNameController = TextEditingController();
  final TextEditingController _addressMobileController =
      TextEditingController();
  final TextEditingController _addressHouseController = TextEditingController();
  final TextEditingController _addressStreetController =
      TextEditingController();
  final TextEditingController _otherCancelReasonController =
      TextEditingController();
  final TextEditingController _addressCityController = TextEditingController();
  final TextEditingController _addressStateController = TextEditingController();
  final TextEditingController _addressPincodeController =
      TextEditingController();
  final TextEditingController _bankAccountNameController =
      TextEditingController();
  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _bankAccountNoController =
      TextEditingController();
  final TextEditingController _bankIfscController = TextEditingController();
  final TextEditingController _upiIdController = TextEditingController();
  bool _showInlineBankForm = false;
  bool _isSavingBankDetail = false;
  String? _selectedPayoutMethod;
  String _addressType = 'Home';
  bool _isCheckingBrandModels = false;
  bool _isLoadingSeriesModels = false;
  bool _sellBrandImagesReady = false;
  bool _modelImagesReady = true;
  String? _selectedSeriesId;
  Timer? _brandModelEmptyTimer;
  final Set<String> _preloadedImageUrls = {};

  List<String> get _currentAvailableModels {
    if (_selectedBrand == null) return [];
    return _modelsForBrandName(_selectedBrand!);
  }

  List<String> _modelsForBrandName(String brandName) {
    if (brandName.trim().isEmpty) return [];
    String? brandId;
    final normalizedBrandName = _normalizeBrandName(brandName);
    for (final brand in _apiBrands) {
      if (_normalizeBrandName(brand['brandName']?.toString()) ==
          normalizedBrandName) {
        brandId = brand['id']?.toString();
        break;
      }
    }

    if (brandId != null && _apiModels.isNotEmpty) {
      final sourceModels = _selectedSeriesId == null
          ? _apiModels
          : _seriesFilteredModels;
      final models = sourceModels
          .where((model) => model['brandId']?.toString() == brandId)
          .map((model) => model['modelName']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .toSet()
          .toList();

      if (models.isNotEmpty) return models;
    }

    return [];
  }

  String _normalizeBrandName(String? value) {
    return (value ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }

  String _canonicalBrandName(String value) {
    final normalized = _normalizeBrandName(value);
    for (final brand in _apiBrands) {
      final apiName = brand['brandName']?.toString() ?? '';
      if (_normalizeBrandName(apiName) == normalized) return apiName.trim();
    }
    return value.trim();
  }

  List<Map<String, dynamic>> get _currentBrandSeries {
    final brandId = _selectedBrandId;
    if (brandId == null) return [];

    return _apiSeries
        .where((series) => series['brandId']?.toString() == brandId)
        .where((series) => _seriesName(series).isNotEmpty)
        .toList();
  }

  String _seriesName(Map<String, dynamic> series) {
    return (series['seriesName'] ??
            series['series'] ??
            series['title'] ??
            series['name'] ??
            '')
        .toString()
        .trim();
  }

  String get _selectedSeriesName {
    final selectedId = _selectedSeriesId;
    if (selectedId == null) return '';

    for (final series in _apiSeries) {
      if (series['id']?.toString() == selectedId) {
        return _seriesName(series);
      }
    }
    return '';
  }

  List<String> get _currentAvailableStorageOptions {
    final modelId = _selectedModelId;

    if (_apiVariants.isNotEmpty) {
      final storageOptions = _apiVariants
          .where((variant) => variant['modelId']?.toString() == modelId)
          .map((variant) => _formatStorage(variant['storage']?.toString()))
          .where((storage) => storage.isNotEmpty)
          .toSet()
          .toList();

      if (storageOptions.isNotEmpty) return storageOptions;
    }

    return [];
  }

  String? get _selectedBrandId {
    final normalizedSelectedBrand = _normalizeBrandName(_selectedBrand);
    for (final brand in _apiBrands) {
      if (_normalizeBrandName(brand['brandName']?.toString()) ==
          normalizedSelectedBrand) {
        return brand['id']?.toString();
      }
    }

    return null;
  }

  String get _selectedModelId {
    final selectedModel = _selectedModel;
    if (selectedModel == null || selectedModel.trim().isEmpty) return '';
    return _modelIdForName(selectedModel) ?? '';
  }

  String get _selectedVariantId {
    final modelId = _selectedModelId;
    final selectedStorage = _normalizeStorage(_selectedStorage);

    for (final variant in _apiVariants) {
      final variantModelId = variant['modelId']?.toString();
      final variantStorage = _normalizeStorage(variant['storage']?.toString());

      if (variantModelId == modelId && variantStorage == selectedStorage) {
        return variant['id']?.toString() ?? '';
      }
    }

    return '';
  }

  bool handleBack() => _handleSystemBack();
  void _resetState() {
    setState(() {
      _showBrandSelection = false;
      _modelListSearchQuery = '';
      _selectedSeriesId = null;
      _seriesFilteredModels = [];
      _selectedBrand = null;
      _selectedModel = null;
      _modelQuestions = [];
      _selectedAdminQuestionOptions.clear();
      _selectedCheckboxQuestionOptions.clear();
      _selectedStorage = '';
      _enquiryBasePrice = 0;
      _calculatedBasePrice = 0;
      _showValuation = false;
      _showCondition = false;
      _showDefects = false;
      _showScreenCondition = false;
      _showDiscoloration = false;
      _showDentsCondition = false;
      _showBackPanelCondition = false;
      _showBentCondition = false;
      _showFunctionalCondition = false;
      _showAccessoriesCondition = false;
      _showAdminImageQuestion = false;
      _showCheckout = false;
      _showAddressSelection = false;
      _showAddAddress = false;
      _showPickupType = false;
      _showFinalReview = false;
      _showSuccess = false;
      _showCancelScreen = false;
      _showCancelSuccess = false;
      _confirmedCancelReason = '';
      _isScreenCracked = null;
      _hasScratches = null;
      _isBatteryLow = null;
      _hasBillBox = null;
      _powersOn = null;
      _canMakeReceiveCalls = null;
      _selectedDefects.clear();
      _selectedFunctionalProblems.clear();
      _selectedAccessories.clear();
      _selectedPhysicalCondition = null;
      _selectedDentsCondition = null;
      _selectedBackPanelCondition = null;
      _selectedBentCondition = null;
      _selectedDiscoloration = null;
      isInstantPickup = false;
      _selectedPickupDate = DateTime.now().add(const Duration(days: 1));
      _appliedCoupon = null;
      _couponDiscount = 0;
      _selectedPayoutMethod = null;
      _upiIdController.clear();
      _modelListSearchController.clear();
    });
  }

  @override
  void initState() {
    super.initState();
    _apiBrands = List<Map<String, dynamic>>.from(_cachedBrands);
    _apiSeries = List<Map<String, dynamic>>.from(_cachedSeries);
    _apiModels = List<Map<String, dynamic>>.from(_cachedModels);
    _apiVariants = List<Map<String, dynamic>>.from(_cachedVariants);
    finalOrderID = widget.currentOrderID;
    _applyInitialSelection();
    final user = context.read<AuthViewModel>().loggedInUser;
    _addressNameController.text = user?.name ?? '';
    _addressMobileController.text = user?.mobile ?? '';
    _bankAccountNameController.text = user?.name ?? '';
    DateTime now = DateTime.now();
    selectedDate = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 1));
    _showBrandSelection = widget.openBrandSelection;
    if (widget.openBrandSelection) {
      _selectedBrand = null;
      _selectedModel = null;
      _isCheckingBrandModels = false;
    }
    _bootstrapSellData();
    _loadCheckoutFaqs();
    _fetchCurrentLocation();
  }

  Future<void> _bootstrapSellData() async {
    await _restoreSellDeviceCache();
    if (!mounted) return;
    await _loadSellData();
  }

  Future<void> _restoreSellDeviceCache() async {
    if (_apiBrands.isNotEmpty && _apiModels.isNotEmpty) return;

    final results = await Future.wait([
      DeviceDataCache.loadTable('brand'),
      DeviceDataCache.loadTable('series'),
      DeviceDataCache.loadTable('model'),
      DeviceDataCache.loadTable('modelVariant'),
    ]);
    if (!mounted) return;

    setState(() {
      if (_apiBrands.isEmpty && results[0].isNotEmpty) {
        _apiBrands = results[0];
        _cachedBrands = List<Map<String, dynamic>>.from(results[0]);
      }
      if (_apiSeries.isEmpty && results[1].isNotEmpty) {
        _apiSeries = results[1];
        _cachedSeries = List<Map<String, dynamic>>.from(results[1]);
      }
      if (_apiModels.isEmpty && results[2].isNotEmpty) {
        _apiModels = results[2];
        _cachedModels = List<Map<String, dynamic>>.from(results[2]);
      }
      if (_apiVariants.isEmpty && results[3].isNotEmpty) {
        _apiVariants = results[3];
        _cachedVariants = List<Map<String, dynamic>>.from(results[3]);
      }
      if (_apiBrands.isNotEmpty) _sellDataErrorMessage = null;
    });
    await _prepareSellBrandImages(_apiBrands);
    if (!mounted) return;
    setState(() => _sellBrandImagesReady = _apiBrands.isNotEmpty);
  }

  Future<void> _loadCheckoutFaqs() async {
    setState(() {
      _isLoadingCheckoutFaqs = true;
      _checkoutFaqErrorMessage = null;
    });

    try {
      final faqs = await _repo.getFaq();
      if (!mounted) return;

      final checkoutFaqs = faqs.where((faq) {
        final type = _normalizeFaqType(faq.category);
        return type.contains('checkout') && type.contains('faq');
      }).toList();

      setState(() {
        _checkoutFaqs = checkoutFaqs;
        _visibleCheckoutFaqCount = 4;
        if (_checkoutFaqs.isEmpty) {
          _checkoutFaqErrorMessage = 'FAQs are not available right now.';
        }
      });
    } catch (e) {
      debugPrint('Checkout FAQ error: $e');
      if (mounted) {
        setState(() {
          _checkoutFaqErrorMessage =
              'Could not load FAQs. Please check your network and try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingCheckoutFaqs = false);
    }
  }

  String _normalizeFaqType(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

  @override
  void didUpdateWidget(covariant SellScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialBrandName != widget.initialBrandName ||
        oldWidget.initialModelName != widget.initialModelName) {
      _applyInitialSelection();
    }
    if (widget.openBrandSelection && !oldWidget.openBrandSelection) {
      _brandModelEmptyTimer?.cancel();
      setState(() {
        _showBrandSelection = true;
        _selectedBrand = null;
        _selectedModel = null;
        _isCheckingBrandModels = false;
      });
    }
  }

  void _applyInitialSelection() {
    final brandName = widget.initialBrandName?.trim();
    final modelName = widget.initialModelName?.trim();

    if ((brandName == null || brandName.isEmpty) &&
        (modelName == null || modelName.isEmpty)) {
      return;
    }

    _showBrandSelection = false;
    if (brandName != null && brandName.isNotEmpty) {
      _brandModelEmptyTimer?.cancel();
      _selectedBrand = brandName;
      _isCheckingBrandModels = _modelsForBrandName(brandName).isEmpty;
      if (_isCheckingBrandModels) {
        _refreshModelsForSelectedBrand(brandName);
      }
    }
    if (modelName != null && modelName.isNotEmpty) {
      _selectedModel = modelName;
      _modelQuestions = [];
      _selectedAdminQuestionOptions.clear();
      _selectedCheckboxQuestionOptions.clear();
      _showAdminImageQuestion = false;
      _adminImageQuestionIndex = 0;
      _fetchModelQuestions();
    } else {
      _selectedModel = null;
    }
  }

  @override
  void dispose() {
    _mapMoveDebounce?.cancel();
    _brandModelEmptyTimer?.cancel();
    _brandSearchController.dispose();
    _modelListSearchController.dispose();
    _searchController.dispose();
    _couponController.dispose();
    _sellLoginMobileController.dispose();
    _sellLoginPasswordController.dispose();
    _addressNameController.dispose();
    _addressMobileController.dispose();
    _addressHouseController.dispose();
    _addressStreetController.dispose();
    _addressCityController.dispose();
    _addressStateController.dispose();
    _addressPincodeController.dispose();
    _bankAccountNameController.dispose();
    _bankNameController.dispose();
    _bankAccountNoController.dispose();
    _bankIfscController.dispose();
    _upiIdController.dispose();
    super.dispose();
  }

  int get _totalPrice {
    return _calculatedBasePrice + _couponDiscount;
  }

  double get _estimationAccuracyValue {
    final base = _selectedVariantBasePrice > 0
        ? _selectedVariantBasePrice
        : (_enquiryBasePrice > 0 ? _enquiryBasePrice : _calculatedBasePrice);
    final hasApiVariant = _selectedVariantBasePrice > 0;
    final hasStorage = _selectedStorage.trim().isNotEmpty;
    final hasQuestions = _modelQuestions.isNotEmpty;
    final selectedAnswerCount =
        _selectedAdminQuestionOptions.length +
        _selectedCheckboxQuestionOptions.values.fold<int>(
          0,
          (total, selected) => total + selected.length,
        );

    if (selectedAnswerCount == 0) {
      if (base > 0 && hasApiVariant && hasStorage && hasQuestions) return 0.82;
      if (base > 0 && hasApiVariant && hasStorage) return 0.74;
      if (base > 0) return 0.62;
      return 0.35;
    }

    if (base <= 0) return 0.45;
    final answeredBoost = 0.08;
    final priceRatio = (_calculatedBasePrice / base).clamp(0.05, 1.0);
    return (priceRatio + answeredBoost).clamp(0.25, 1.0).toDouble();
  }

  String get _estimationAccuracyLabel {
    final value = _estimationAccuracyValue;
    if (value >= 0.82) return 'High';
    if (value >= 0.58) return 'Medium';
    return 'Low';
  }

  Color get _estimationAccuracyColor {
    final value = _estimationAccuracyValue;
    if (value >= 0.82) return Colors.green;
    if (value >= 0.58) return Colors.orange;
    return Colors.redAccent;
  }

  bool get _usesAdminQuestions => _modelQuestions.isNotEmpty;

  List<Map<String, dynamic>> get _configuredAdminQuestions {
    return _modelQuestions.where((question) {
      final options = _questionOptions(question);
      return _questionTitle(question).isNotEmpty &&
          options.isNotEmpty &&
          _isDefaultQuestionEnabled(question);
    }).toList();
  }

  List<Map<String, dynamic>> get _adminImageQuestions {
    return _configuredAdminQuestions;
  }

  bool _isDefaultQuestionEnabled(Map<String, dynamic> question) {
    final rawDefault =
        question['default'] ??
        question['isDefault'] ??
        question['is_default'] ??
        question['defaultQuestion'] ??
        question['default_question'] ??
        question['status'];

    if (rawDefault == null) return true;

    final value = rawDefault.toString().trim().toLowerCase();
    return value == 'yes' ||
        value == 'y' ||
        value == 'true' ||
        value == '1' ||
        value == 'active' ||
        value == 'enabled';
  }

  String _questionId(Map<String, dynamic> question) {
    return question['id']?.toString() ??
        question['questionId']?.toString() ??
        question['question_id']?.toString() ??
        _questionTitle(question);
  }

  String _questionTitle(Map<String, dynamic> question) {
    return question['title']?.toString() ??
        question['questionTitle']?.toString() ??
        question['question_title']?.toString() ??
        question['question']?.toString() ??
        question['name']?.toString() ??
        '';
  }

  List<Map<String, dynamic>> _questionOptions(Map<String, dynamic> question) {
    final rawOptions =
        question['options'] ??
        question['option'] ??
        question['questionOptions'] ??
        question['question_options'];

    if (rawOptions is List) {
      return rawOptions
          .whereType<Map>()
          .map((option) => Map<String, dynamic>.from(option))
          .toList();
    }

    return <Map<String, dynamic>>[];
  }

  String _questionType(Map<String, dynamic> question) {
    final raw =
        question['type']?.toString() ??
        question['dataType']?.toString() ??
        question['data_type']?.toString() ??
        question['questionType']?.toString() ??
        question['question_type']?.toString() ??
        'Radio';
    final normalized = raw.trim().toLowerCase();
    if (normalized == 'checkbox' ||
        normalized == 'check box' ||
        normalized == 'multi' ||
        normalized == 'multiple' ||
        normalized == 'multi-select' ||
        normalized == 'multiselect') {
      return 'Checkbox';
    }
    return 'Radio';
  }

  String _optionId(Map<String, dynamic> option) {
    return option['id']?.toString() ??
        option['optionId']?.toString() ??
        option['option_id']?.toString() ??
        option['value']?.toString() ??
        _optionLabel(option);
  }

  String _optionLabel(Map<String, dynamic> option) {
    return option['label']?.toString() ??
        option['optionLabel']?.toString() ??
        option['option_label']?.toString() ??
        option['title']?.toString() ??
        option['name']?.toString() ??
        option['value']?.toString() ??
        '';
  }

  String _optionMediaUrl(String value) {
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value.replaceAll('\\', '/');
    }
    var cleanPath = value.replaceAll('\\', '/').trim();
    cleanPath = cleanPath.startsWith('/') ? cleanPath.substring(1) : cleanPath;
    cleanPath = cleanPath.replaceFirst(RegExp(r'^(cashify/)?(public/)?'), '');
    return Uri.parse(ApiConstants.WEBSITE_URL).resolve(cleanPath).toString();
  }

  String? _optionImageUrl(Map<String, dynamic> option) {
    const imageKeys = [
      'optionImage',
      'option_image',
      'image',
      'imageUrl',
      'image_url',
      'icon',
      'file',
      'fileName',
      'filename',
      'path',
    ];

    for (final key in imageKeys) {
      final value = option[key]?.toString().trim();
      if (value != null && value.isNotEmpty && value.toLowerCase() != 'null') {
        final imageUrl = _optionMediaUrl(value);
        debugPrint('Option image URL => $imageUrl');
        return imageUrl;
      }
    }

    for (final value in option.values) {
      final rawValue = value?.toString().trim();
      if (rawValue == null || rawValue.isEmpty) continue;

      final lowerValue = rawValue.toLowerCase();
      final looksLikeImage =
          lowerValue.contains('.png') ||
          lowerValue.contains('.jpg') ||
          lowerValue.contains('.jpeg') ||
          lowerValue.contains('.webp') ||
          lowerValue.contains('.svg');

      if (looksLikeImage) {
        final imageUrl = _optionMediaUrl(rawValue);
        debugPrint('Option fallback image URL => $imageUrl');
        return imageUrl;
      }
    }

    return null;
  }

  bool get _areAdminQuestionsAnswered {
    final questions = _configuredAdminQuestions;
    if (questions.isEmpty) return true;
    return questions.every(_isAdminQuestionAnswered);
  }

  bool _isAdminQuestionAnswered(Map<String, dynamic> question) {
    final questionId = _questionId(question);
    final type = _questionType(question);
    if (type == 'Checkbox') {
      return (_selectedCheckboxQuestionOptions[questionId] ?? <String>{})
          .isNotEmpty;
    }
    return (_selectedAdminQuestionOptions[questionId] ?? '').isNotEmpty;
  }

  String _formatCurrency(int amount) {
    return '\u20b9 ${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => "${m[1]},")}';
  }

  String _checkoutPriceText(bool isLoggedIn) {
    return isLoggedIn ? _formatCurrency(_totalPrice) : '\u20b9 XX,XXX';
  }

  DateTime? _parseCouponDate(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty || raw.toLowerCase() == 'null') return null;
    return DateTime.tryParse(raw);
  }

  bool _isCouponActiveToday(Map<String, dynamic> coupon) {
    final status = coupon['status']?.toString().trim() ?? '';
    if (status != '1') return false;

    final startDate = _parseCouponDate(coupon['startDate']);
    final endDate = _parseCouponDate(coupon['endDate']);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (startDate != null) {
      final start = DateTime(startDate.year, startDate.month, startDate.day);
      if (today.isBefore(start)) return false;
    }

    if (endDate != null) {
      final end = DateTime(endDate.year, endDate.month, endDate.day);
      if (today.isAfter(end)) return false;
    }

    return true;
  }

  String _couponName(Map<String, dynamic> coupon) {
    return coupon['couponName']?.toString().trim() ??
        coupon['coupon']?.toString().trim() ??
        coupon['code']?.toString().trim() ??
        '';
  }

  int _couponPrice(Map<String, dynamic> coupon) {
    final rawPrice =
        coupon['price'] ??
        coupon['couponPrice'] ??
        coupon['coupon_price'] ??
        coupon['amount'];
    return int.tryParse(rawPrice?.toString() ?? '') ?? 0;
  }

  Map<String, dynamic>? _findActiveCoupon(String code) {
    final normalized = code.trim().toLowerCase();
    for (final coupon in _apiCoupons) {
      if (_couponName(coupon).toLowerCase() == normalized) {
        return coupon;
      }
    }
    return null;
  }

  bool _handleSystemBack() {
    if (!mounted) return false;

    if (_selectedModel == null && _selectedSeriesId != null) {
      setState(() {
        _selectedSeriesId = null;
        _seriesFilteredModels = [];
        _isLoadingSeriesModels = false;
        _modelListSearchQuery = '';
        _modelListSearchController.clear();
      });
      return true;
    }

    final enteredDirectlyFromHome =
        widget.initialBrandName?.trim().isNotEmpty == true;
    if (_selectedModel == null &&
        _selectedBrand != null &&
        enteredDirectlyFromHome) {
      widget.onExitToHome?.call();
      return true;
    }

    if (_showBrandSelection &&
        widget.openBrandSelection &&
        _selectedBrand == null &&
        _selectedModel == null) {
      widget.onExitToHome?.call();
      return true;
    }

    var handled = true;

    setState(() {
      if (_showCancelSuccess) {
        _showCancelSuccess = false;
        _showCancelScreen = true;
      } else if (_showCancelScreen) {
        _showCancelScreen = false;
      } else if (_showSuccess) {
        handled = false;
      } else if (_showFinalReview) {
        _showFinalReview = false;
        _showPickupType = true;
      } else if (_showPickupType) {
        _showPickupType = false;
        _showAddressSelection = true;
      } else if (_showAddAddress) {
        _showAddAddress = false;
        _showAddressSelection = true;
      } else if (_showAddressSelection) {
        _showAddressSelection = false;
        _showCheckout = true;
      } else if (_showCheckout) {
        _showCheckout = false;
        if (_adminImageQuestions.isNotEmpty) {
          _showAdminImageQuestion = true;
          _adminImageQuestionIndex = _adminImageQuestions.length - 1;
        } else {
          _showCondition = true;
        }
      } else if (_showAdminImageQuestion) {
        if (_adminImageQuestionIndex > 0) {
          _adminImageQuestionIndex--;
        } else {
          _showAdminImageQuestion = false;
          _showValuation = true;
        }
      } else if (_showCondition) {
        _showCondition = false;
        _showValuation = true;
      } else if (_showValuation) {
        _showValuation = false;
      } else if (_selectedModel != null) {
        _selectedModel = null;
        _modelQuestions = [];
      } else if (_selectedBrand != null) {
        _selectedBrand = null;
        _selectedSeriesId = null;
        _seriesFilteredModels = [];
        _modelListSearchQuery = '';
        _modelListSearchController.clear();
      } else if (_showBrandSelection) {
        _showBrandSelection = false;
      } else {
        handled = false;
      }
    });

    return handled;
  }

  Future<void> _fetchModelQuestions() async {
    if (_selectedModel == null) return;

    setState(() {
      _isLoadingQuestions = true;
      _modelQuestionsErrorMessage = null;
      _modelQuestions = [];
    });

    try {
      final questions = await _repo.getModelQuestions(_selectedModelId);

      if (!mounted) return;

      setState(() {
        _modelQuestions = questions;
        if (questions.isEmpty) {
          _modelQuestionsErrorMessage =
              'Questions are not available for this model right now.';
        }
        final validQuestionIds = _configuredAdminQuestions
            .map(_questionId)
            .toSet();
        _selectedAdminQuestionOptions.removeWhere(
          (questionId, _) => !validQuestionIds.contains(questionId),
        );
        _selectedCheckboxQuestionOptions.removeWhere(
          (questionId, _) => !validQuestionIds.contains(questionId),
        );
      });
    } catch (e) {
      debugPrint('Model questions error: $e');
      if (mounted) {
        setState(() {
          _modelQuestionsErrorMessage =
              'Could not fetch model questions. Please check your network and try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingQuestions = false);
      }
    }
  }

  Future<void> _loadSellData({bool showLoader = true}) async {
    final hadDeviceData =
        _apiBrands.isNotEmpty ||
        _apiModels.isNotEmpty ||
        _apiVariants.isNotEmpty;

    if (showLoader) {
      setState(() {
        _isLoadingSellData = true;
        _sellDataErrorMessage = null;
      });
    } else if (_sellDataErrorMessage != null && hadDeviceData) {
      setState(() => _sellDataErrorMessage = null);
    }

    try {
      final userId = context.read<AuthViewModel>().loggedInUser?.id ?? '';
      final optionalResultsFuture = Future.wait([
        _tryLoadSellDataTable('coupon', filter: {'status': '1'}),
        if (userId.isNotEmpty)
          _tryLoadSellDataTable('address', filter: {'userId': userId})
        else
          Future.value(<Map<String, dynamic>>[]),
        if (userId.isNotEmpty)
          _tryLoadSellDataTable('bankDetail', filter: {'userId': userId})
        else
          Future.value(<Map<String, dynamic>>[]),
      ]);

      final brandsFuture = _tryLoadSellDataTable('brand');
      final seriesFuture = _tryLoadSellDataTable('series');
      final modelsFuture = _tryLoadSellDataTable('model');
      final variantsFuture = _tryLoadSellDataTable('modelVariant');

      final brands = await brandsFuture;
      if (!mounted) return;

      if (brands != null && brands.isNotEmpty) {
        setState(() {
          _apiBrands = brands;
          _cachedBrands = List<Map<String, dynamic>>.from(brands);
          _sellDataErrorMessage = null;
          if (_selectedBrand != null) {
            _selectedBrand = _canonicalBrandName(_selectedBrand!);
          }
        });
        unawaited(_prepareSellBrandImages(brands));
        unawaited(DeviceDataCache.saveTable('brand', brands));
      }

      final remainingDeviceResults = await Future.wait([
        seriesFuture,
        modelsFuture,
        variantsFuture,
      ]);

      if (!mounted) return;

      final series = remainingDeviceResults[0];
      final models = remainingDeviceResults[1];
      final variants = remainingDeviceResults[2];

      setState(() {
        if (series != null && series.isNotEmpty) {
          _apiSeries = series;
          _cachedSeries = List<Map<String, dynamic>>.from(series);
          unawaited(DeviceDataCache.saveTable('series', series));
        }
        if (models != null && models.isNotEmpty) {
          _apiModels = models;
          _cachedModels = List<Map<String, dynamic>>.from(models);
          unawaited(DeviceDataCache.saveTable('model', models));
        }
        if (variants != null && variants.isNotEmpty) {
          _apiVariants = variants;
          _cachedVariants = List<Map<String, dynamic>>.from(variants);
          unawaited(DeviceDataCache.saveTable('modelVariant', variants));
        }

        if (_apiBrands.isNotEmpty && _apiModels.isNotEmpty) {
          _sellDataErrorMessage = null;
        } else if (!hadDeviceData) {
          _sellDataErrorMessage =
              'Could not load device data. Please check your network and try again.';
        } else {
          _sellDataErrorMessage = null;
        }
        if (_selectedBrand != null) {
          _selectedBrand = _canonicalBrandName(_selectedBrand!);
        }
        if (_selectedBrand != null && _currentAvailableModels.isNotEmpty) {
          _brandModelEmptyTimer?.cancel();
          _isCheckingBrandModels = false;
        }
      });
      if (_selectedBrand != null) {
        _warmDeviceImagesForBrand(_selectedBrand!);
      } else {
        await _prepareSellBrandImages(_apiBrands);
        if (!mounted) return;
        setState(() => _sellBrandImagesReady = _apiBrands.isNotEmpty);
      }
      _loadSellOptionalDataInBackground(optionalResultsFuture, userId);
    } catch (e) {
      debugPrint('Sell data error: $e');
      if (mounted) {
        setState(() {
          if (hadDeviceData) {
            _sellDataErrorMessage = null;
          } else {
            _sellDataErrorMessage =
                'Could not load device data. Please check your network and try again.';
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingSellData = false);
      }
    }
  }

  Future<void> _loadSellOptionalDataInBackground(
    Future<List<List<Map<String, dynamic>>?>> optionalResultsFuture,
    String userId,
  ) async {
    final optionalResults = await optionalResultsFuture;
    if (!mounted) return;

    setState(() {
      final coupons = optionalResults[0];
      final addresses = optionalResults[1];
      final bankDetails = optionalResults[2];
      if (coupons != null) {
        _apiCoupons = coupons.where(_isCouponActiveToday).toList();
      }
      if (addresses != null) {
        _savedAddresses = addresses;
      }
      if (bankDetails != null) {
        _savedBankDetails = bankDetails;
      }
      if (userId.isEmpty) {
        _selectedPickupAddress = null;
        _selectedBankDetail = null;
      }
      if (_savedAddresses.isNotEmpty) {
        _selectedPickupAddress ??= _savedAddresses.first;
      }
      if (_savedBankDetails.isNotEmpty) {
        _selectedBankDetail ??= _savedBankDetails.first;
      }
    });
  }

  Future<List<Map<String, dynamic>>?> _tryLoadSellDataTable(
    String tableName, {
    Map<String, dynamic> filter = const {},
  }) async {
    try {
      return await _repo.getData(tableName: tableName, filter: filter);
    } catch (e) {
      debugPrint('Optional sell data error [$tableName]: $e');
      return null;
    }
  }

  Future<void> refreshApiDataAfterResume() async {
    await _loadSellData(showLoader: false);
    if (_selectedModel != null && _selectedModel!.trim().isNotEmpty) {
      await _fetchModelQuestions();
    }
    await _loadCheckoutFaqs();
  }

  Future<void> _fetchCurrentLocation() async {
    if (_isFetchingLocation) return;

    setState(() {
      _isFetchingLocation = true;
      _locationStatusMessage = 'Fetching your location...';
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(
            () => _locationStatusMessage =
                'Location services are disabled. Please enable GPS.',
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        if (mounted) {
          setState(
            () => _locationStatusMessage = 'Location permission denied.',
          );
        }
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
        _locationStatusMessage = 'Location fetched';
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
      debugPrint('Location: $_pickupLatitude, $_pickupLongitude');
    } catch (e) {
      debugPrint('Location fetch error: $e');
      if (mounted) {
        setState(() => _locationStatusMessage = 'Could not fetch location.');
      }
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

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

  Future<void> _reverseGeocode(double lat, double lng) async {
    if (!mounted) return;
    setState(() => _isFetchingAddress = true);
    try {
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

        final parts = <String>[];
        for (final v in [
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
          if (v.isNotEmpty && !parts.contains(v)) parts.add(v);
        }
        final displayName = data['display_name']?.toString().trim() ?? '';
        final address =
            nativeHouse.isNotEmpty && !displayName.contains(nativeHouse)
            ? [
                nativeHouse,
                displayName,
              ].where((value) => value.isNotEmpty).join(', ')
            : (displayName.isNotEmpty ? displayName : parts.join(', '));

        if (mounted) {
          // Sirf map ke liye fetched address set karo.
          // Manual form fields sirf _detectLocationForManualForm() se fill honge.
          setState(() => _fetchedAddress = address);
        }
      }
    } catch (e) {
      debugPrint('Reverse geocode error: $e');
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

    final addr = result['address'] as Map<String, dynamic>? ?? {};
    final road = addr['road']?.toString() ?? '';
    final suburb = addr['suburb']?.toString().isNotEmpty == true
        ? addr['suburb'].toString()
        : (addr['neighbourhood']?.toString() ?? '');
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

    setState(() {
      _pickupLatitude = lat.toString();
      _pickupLongitude = lng.toString();
      _searchResults = [];
      _searchController.clear();
      _fetchedAddress = result['display_name']?.toString() ?? '';
    });

    if (_addressStreetController.text.isEmpty) {
      _addressStreetController.text = [
        road,
        suburb,
      ].where((s) => s.isNotEmpty).join(', ');
    }
    if (_addressCityController.text.isEmpty) {
      _addressCityController.text = city.isNotEmpty ? city : district;
    }
    if (_addressStateController.text.isEmpty) {
      _addressStateController.text = state;
    }
    if (_addressPincodeController.text.isEmpty) {
      _addressPincodeController.text = postcode;
    }

    try {
      _mapController.move(LatLng(lat, lng), 17.0);
    } catch (_) {}
  }

  void _selectModel(String name) {
    final storageOptions = _storageOptionsForModel(name);
    FocusScope.of(context).unfocus();

    setState(() {
      _selectedModel = name;
      _modelListSearchQuery = '';
      _modelListSearchController.clear();
      if (storageOptions.isNotEmpty &&
          !storageOptions.contains(_selectedStorage)) {
        _selectedStorage = storageOptions.first;
      }
      _modelQuestions = [];
      _selectedAdminQuestionOptions.clear();
      _selectedCheckboxQuestionOptions.clear();
      _showAdminImageQuestion = false;
      _adminImageQuestionIndex = 0;
      _enquiryBasePrice = 0;
      _calculatedBasePrice = 0;
    });
    _fetchModelQuestions();
  }

  void _selectBrand(String name) {
    _brandModelEmptyTimer?.cancel();
    final canonicalName = _canonicalBrandName(name);
    final hasModelsForBrand = _modelsForBrandName(canonicalName).isNotEmpty;
    setState(() {
      _selectedBrand = canonicalName;
      _selectedModel = null;
      _selectedSeriesId = null;
      _seriesFilteredModels = [];
      _modelListSearchQuery = '';
      _modelListSearchController.clear();
      _modelQuestions = [];
      _selectedAdminQuestionOptions.clear();
      _selectedCheckboxQuestionOptions.clear();
      _showAdminImageQuestion = false;
      _adminImageQuestionIndex = 0;
      _enquiryBasePrice = 0;
      _calculatedBasePrice = 0;
      _isCheckingBrandModels = !hasModelsForBrand;
      _modelImagesReady = false;
    });
    unawaited(_prepareModelImagesForBrand(canonicalName));
    if (hasModelsForBrand) return;
    _refreshModelsForSelectedBrand(canonicalName);
  }

  Future<void> _refreshModelsForSelectedBrand(String brandName) async {
    await _loadSellData(showLoader: false);
    if (!mounted || _selectedBrand != brandName) return;

    final hasModelsForBrand = _modelsForBrandName(brandName).isNotEmpty;
    if (hasModelsForBrand) _brandModelEmptyTimer?.cancel();
    setState(() => _isCheckingBrandModels = false);
    unawaited(_prepareModelImagesForBrand(brandName));
  }

  Future<void> _selectSeries(String? seriesId) async {
    if (_selectedSeriesId == seriesId) return;

    final localModels = seriesId == null
        ? <Map<String, dynamic>>[]
        : _modelsForSeries(seriesId);

    setState(() {
      _selectedSeriesId = seriesId;
      _seriesFilteredModels = localModels;
      _modelListSearchQuery = '';
      _modelListSearchController.clear();
      _isLoadingSeriesModels = seriesId != null && localModels.isEmpty;
      _modelImagesReady = false;
      _sellDataErrorMessage = null;
    });
    if (seriesId == null) {
      final brandName = _selectedBrand;
      if (brandName != null) unawaited(_prepareModelImagesForBrand(brandName));
    } else {
      unawaited(_prepareModelImages(localModels));
    }

    if (seriesId == null || localModels.isNotEmpty) return;

    await _loadSellData(showLoader: false);
    if (!mounted || _selectedSeriesId != seriesId) return;

    setState(() {
      _seriesFilteredModels = _modelsForSeries(seriesId);
      _sellDataErrorMessage = null;
      _isLoadingSeriesModels = false;
    });
    unawaited(_prepareModelImages(_seriesFilteredModels));
  }

  List<Map<String, dynamic>> _modelsForSeries(String seriesId) {
    final brandId = _selectedBrandId;
    return _apiModels.where((model) {
      final modelSeriesId = model['seriesId']?.toString();
      final modelBrandId = model['brandId']?.toString();
      return modelSeriesId == seriesId &&
          (brandId == null || modelBrandId == brandId);
    }).toList();
  }

  bool get _hasSelectedSeriesModels {
    if (_selectedSeriesId == null) return true;
    if (_seriesFilteredModels.isNotEmpty) return true;
    if (_isLoadingSeriesModels) return true;
    return _modelsForSeries(_selectedSeriesId!).isNotEmpty;
  }

  String get _emptyModelMessage {
    if (_selectedSeriesId != null && !_hasSelectedSeriesModels) {
      return 'No models are available for this series right now.';
    }
    return 'No models are available for this brand right now.';
  }

  Future<void> _calculateExactPrice() async {
    setState(() => _isCalculatingPrice = true);

    try {
      if (_selectedModel == null) {
        throw Exception('Please select a model first.');
      }

      if (_selectedModelId.isEmpty || _selectedVariantId.isEmpty) {
        await _loadSellData();
      }

      if (_selectedModelId.isEmpty || _selectedVariantId.isEmpty) {
        final deviceDataUnavailable =
            _apiModels.isEmpty || _apiVariants.isEmpty;
        throw Exception(
          deviceDataUnavailable
              ? 'Device data is not available right now. Please check your network and try again.'
              : 'This model or storage option is no longer available. Please select it again.',
        );
      }

      if (_modelQuestions.isEmpty) {
        await _fetchModelQuestions();
      }
      if (_modelQuestions.isEmpty && _modelQuestionsErrorMessage != null) {
        throw Exception(_modelQuestionsErrorMessage);
      }

      final selectedOptions = _selectedQuestionOptionIds();

      debugPrint(
        'Sell calculate => modelId=$_selectedModelId variantId=$_selectedVariantId selectedOptions=$selectedOptions',
      );
      debugPrint('Selected accessories => $_selectedAccessories');

      final priceResult = await _repo.calculatePrice(
        modelId: _selectedModelId,
        variantId: _selectedVariantId,
        selectedOptions: selectedOptions,
      );

      if (!mounted) return;

      if (priceResult.finalPrice <= 0) {
        throw Exception('Final price was not returned by server.');
      }

      final variantBasePrice = _selectedVariantBasePrice;
      final enquiryBasePrice =
          priceResult.basePrice == priceResult.finalPrice &&
              variantBasePrice > 0
          ? variantBasePrice
          : priceResult.basePrice;

      setState(() {
        _enquiryBasePrice = enquiryBasePrice;
        _calculatedBasePrice = priceResult.finalPrice;
        _showCheckout = true;
      });
    } catch (e) {
      debugPrint('Calculate price error: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not calculate price: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCalculatingPrice = false);
      }
    }
  }

  List<String> _selectedQuestionOptionIds() {
    if (_usesAdminQuestions) {
      final ids = <String>{};
      // Radio selections
      ids.addAll(
        _selectedAdminQuestionOptions.values.where(
          (optionId) => optionId.trim().isNotEmpty,
        ),
      );
      // Checkbox selections
      for (final set in _selectedCheckboxQuestionOptions.values) {
        ids.addAll(set.where((id) => id.trim().isNotEmpty));
      }
      return ids.toList();
    }

    final selectedIds = <String>[];

    Map<String, dynamic>? findQuestion(List<String> titleParts) {
      for (final question in _modelQuestions) {
        final title = question['title']?.toString().toLowerCase() ?? '';
        final matches = titleParts.any(
          (part) => title.contains(part.toLowerCase()),
        );

        if (matches) return question;
      }

      return null;
    }

    String? findOptionIdInQuestion(
      Map<String, dynamic>? question,
      List<String> labels,
    ) {
      final options = question?['options'];

      if (options is! List) return null;

      for (final option in options.whereType<Map>()) {
        final label = option['label']?.toString().toLowerCase() ?? '';
        final matches = labels.any(
          (item) => label.contains(item.toLowerCase()),
        );

        if (matches) {
          return option['id']?.toString();
        }
      }

      return null;
    }

    String? findOptionIdAnywhere(List<String> labels) {
      for (final question in _modelQuestions) {
        final optionId = findOptionIdInQuestion(question, labels);
        if (optionId != null) return optionId;
      }

      return null;
    }

    void addOption(String? optionId) {
      if (optionId != null && optionId.isNotEmpty) {
        selectedIds.add(optionId);
      }
    }

    final screenQuestion = findQuestion(['screen']);
    final powerQuestion = findQuestion(['power']);
    final callingQuestion = findQuestion(['call', 'network', 'cellular']);
    final batteryQuestion = findQuestion(['battery', 'batter']);
    final physicalQuestion = findQuestion(['physical']);
    final accessoriesQuestion = findQuestion(['accessories']);
    final discolorationQuestion = findQuestion(['discoloration']);
    final dentsQuestion = findQuestion(['dent']);
    final backPanelQuestion = findQuestion(['back', 'panel']);
    final bentQuestion = findQuestion(['bent', 'loose']);
    final physicalCondition =
        _selectedPhysicalCondition?.toLowerCase().trim() ?? '';
    final selectedNoScreenScratch = physicalCondition.contains('no scratch');
    final selectedCrackedScreen = physicalCondition.contains('cracked');
    final selectedScreenScratch =
        !selectedNoScreenScratch && physicalCondition.contains('scratch');

    final selectedMajorScreenScratch = physicalCondition.contains(
      'more than 2',
    );
    if (_isScreenCracked != null || _selectedPhysicalCondition != null) {
      final screenChoice = (_isScreenCracked == true || selectedCrackedScreen)
          ? findOptionIdInQuestion(screenQuestion, [
              'cracked screen',
              'cracked',
            ])
          : selectedNoScreenScratch
          ? findOptionIdInQuestion(screenQuestion, ['no damage', 'no'])
          : selectedMajorScreenScratch
          ? findOptionIdInQuestion(screenQuestion, ['major scratches']) ??
                findOptionIdAnywhere(['major scratches']) ??
                findOptionIdInQuestion(screenQuestion, ['minor scratches'])
          : selectedScreenScratch
          ? findOptionIdInQuestion(screenQuestion, ['minor scratches'])
          : _isScreenCracked == false
          ? findOptionIdInQuestion(screenQuestion, ['no damage', 'no'])
          : null;
      addOption(screenChoice);
    }

    if (_powersOn != null) {
      final powersOnChoice = findOptionIdInQuestion(
        powerQuestion,
        _powersOn == false ? ['no'] : ['yes'],
      );
      addOption(powersOnChoice);
    }

    if (_canMakeReceiveCalls != null) {
      final callingChoice = findOptionIdInQuestion(
        callingQuestion,
        _canMakeReceiveCalls == true ? ['yes'] : ['no'],
      );
      addOption(callingChoice);
    }

    if (_isBatteryLow != null) {
      final batteryChoice =
          findOptionIdInQuestion(
            batteryQuestion,
            _isBatteryLow == true ? ['yes'] : ['no'],
          ) ??
          (_isBatteryLow == true ? '12' : '13');
      addOption(batteryChoice);
    }

    bool isNoIssue(String? value) {
      final normalized = value?.toLowerCase() ?? '';
      return normalized.isEmpty || normalized.contains('no');
    }

    final dents = _selectedDentsCondition?.toLowerCase() ?? '';
    final hasMajorDents = dents.contains('major');
    final hasMinorDents = dents.contains('minor') || dents.contains('1-2');
    final hasBackPanelIssue = !isNoIssue(_selectedBackPanelCondition);
    final hasBentIssue = !isNoIssue(_selectedBentCondition);
    final hasFunctionalIssue = _selectedFunctionalProblems.isNotEmpty;
    final hasPoorBodyIssue =
        hasMajorDents ||
        hasBackPanelIssue ||
        hasBentIssue ||
        hasFunctionalIssue;
    final hasMinorBodyIssue =
        _hasScratches == true ||
        _selectedDiscoloration == 'Minor Discoloration' ||
        hasMinorDents;
    if (_selectedPhysicalCondition != null ||
        _hasScratches != null ||
        _selectedDiscoloration != null ||
        _selectedDentsCondition != null ||
        _selectedBackPanelCondition != null ||
        _selectedBentCondition != null ||
        _selectedFunctionalProblems.isNotEmpty) {
      final physicalChoice = hasPoorBodyIssue
          ? findOptionIdInQuestion(physicalQuestion, ['poor'])
          : hasMinorBodyIssue
          ? findOptionIdInQuestion(physicalQuestion, ['good'])
          : findOptionIdInQuestion(physicalQuestion, ['excellent']);
      addOption(physicalChoice);
    }

    if (_selectedDiscoloration != null) {
      final discoloration = _selectedDiscoloration!.toLowerCase();
      final discolorationChoice = discoloration.contains('major')
          ? findOptionIdInQuestion(discolorationQuestion, [
                  'major discoloration',
                ]) ??
                findOptionIdAnywhere(['major discoloration']) ??
                '14'
          : discoloration.contains('minor')
          ? findOptionIdInQuestion(discolorationQuestion, [
                  'minor discoloration',
                ]) ??
                findOptionIdAnywhere(['minor discoloration']) ??
                '27'
          : findOptionIdInQuestion(discolorationQuestion, [
                  'no discoloration',
                ]) ??
                findOptionIdAnywhere(['no discoloration']) ??
                '30';
      addOption(discolorationChoice);
    }

    if (_selectedDentsCondition != null) {
      final dentsChoice = hasMajorDents
          ? findOptionIdInQuestion(dentsQuestion, ['major dents']) ??
                findOptionIdAnywhere(['major dents']) ??
                '32'
          : hasMinorDents
          ? findOptionIdInQuestion(dentsQuestion, ['minor dents']) ??
                findOptionIdAnywhere(['minor dents']) ??
                '33'
          : findOptionIdInQuestion(dentsQuestion, ['no dents']) ??
                findOptionIdAnywhere(['no dents']) ??
                '34';
      addOption(dentsChoice);
    }

    if (_selectedBackPanelCondition != null) {
      final panel = _selectedBackPanelCondition!.toLowerCase();
      final backPanelChoice =
          panel.contains('cracked') || panel.contains('broken')
          ? findOptionIdInQuestion(backPanelQuestion, ['cracked']) ??
                findOptionIdAnywhere(['cracked']) ??
                '35'
          : panel.contains('missing')
          ? findOptionIdInQuestion(backPanelQuestion, ['missing']) ??
                findOptionIdAnywhere(['missing']) ??
                '36'
          : findOptionIdInQuestion(backPanelQuestion, ['no defect']) ??
                findOptionIdAnywhere(['no defect']) ??
                '37';
      addOption(backPanelChoice);
    }

    if (_selectedBentCondition != null) {
      final bent = _selectedBentCondition!.toLowerCase();
      final bentChoice = bent.contains('bent') || bent.contains('curved')
          ? findOptionIdInQuestion(bentQuestion, ['bent curved']) ??
                findOptionIdAnywhere(['bent curved']) ??
                '38'
          : bent.contains('loose')
          ? findOptionIdInQuestion(bentQuestion, ['loose screen']) ??
                findOptionIdAnywhere(['loose screen']) ??
                '39'
          : findOptionIdInQuestion(bentQuestion, ['no defects']) ??
                findOptionIdAnywhere(['no defects']) ??
                '40';
      addOption(bentChoice);
    }

    for (final problem in _selectedFunctionalProblems) {
      final normalized = problem.toLowerCase();
      final functionalChoice = normalized.contains('front camera')
          ? findOptionIdAnywhere(['front camera not working']) ?? '41'
          : normalized.contains('back camera')
          ? findOptionIdAnywhere(['back camera not working']) ?? '42'
          : normalized.contains('volume')
          ? findOptionIdAnywhere(['volume button not working']) ?? '43'
          : normalized.contains('finger')
          ? findOptionIdAnywhere(['fingertouch not working']) ??
                findOptionIdAnywhere(['finger touch not working']) ??
                '44'
          : normalized.contains('wifi')
          ? findOptionIdAnywhere(['wifi not working']) ?? '45'
          : normalized.contains('speaker')
          ? findOptionIdAnywhere(['speaker faulty']) ?? '46'
          : null;
      addOption(functionalChoice);
    }

    if (_selectedAccessories.contains('Original Box with same IMEI') ||
        _hasBillBox == true) {
      final boxChoice =
          findOptionIdInQuestion(accessoriesQuestion, ['box']) ?? '9';
      addOption(boxChoice);
    }

    if (_selectedAccessories.contains('Original Charger of Device')) {
      final chargerChoice =
          findOptionIdInQuestion(accessoriesQuestion, ['charger']) ?? '10';
      addOption(chargerChoice);
    }

    return selectedIds.toSet().toList();
  }

  List<Map<String, dynamic>> _selectedQuestionAnswers() {
    if (_usesAdminQuestions) {
      final answers = <Map<String, dynamic>>[];

      for (final question in _configuredAdminQuestions) {
        final qId = _questionId(question);
        final type = _questionType(question);
        final options = _questionOptions(question);

        if (type == 'Checkbox') {
          final selectedIds = _selectedCheckboxQuestionOptions[qId] ?? {};
          for (final optId in selectedIds) {
            Map<String, dynamic>? selectedOption;
            for (final option in options) {
              if (_optionId(option) == optId) {
                selectedOption = option;
                break;
              }
            }
            if (selectedOption == null) continue;
            answers.add({
              'questionTitle': _questionTitle(question),
              'optionLabel': _optionLabel(selectedOption),
              'priceModifier':
                  selectedOption['priceModifier'] ??
                  selectedOption['price_modifier'] ??
                  selectedOption['modifier'] ??
                  selectedOption['price'] ??
                  0,
            });
          }
        } else {
          final selectedOptionId = _selectedAdminQuestionOptions[qId] ?? '';
          if (selectedOptionId.isEmpty) continue;

          Map<String, dynamic>? selectedOption;
          for (final option in options) {
            if (_optionId(option) == selectedOptionId) {
              selectedOption = option;
              break;
            }
          }

          if (selectedOption == null) continue;

          answers.add({
            'questionTitle': _questionTitle(question),
            'optionLabel': _optionLabel(selectedOption),
            'priceModifier':
                selectedOption['priceModifier'] ??
                selectedOption['price_modifier'] ??
                selectedOption['modifier'] ??
                selectedOption['price'] ??
                0,
          });
        }
      }

      return answers;
    }

    final selectedIds = _selectedQuestionOptionIds().toSet();
    final answers = <Map<String, dynamic>>[];

    for (final question in _modelQuestions) {
      final options = question['options'];

      if (options is! List) continue;

      final questionTitle =
          question['title']?.toString() ??
          question['questionTitle']?.toString() ??
          question['question']?.toString() ??
          '';

      for (final option in options.whereType<Map>()) {
        final optionId = option['id']?.toString() ?? '';

        if (!selectedIds.contains(optionId)) continue;

        answers.add({
          'questionTitle': questionTitle,
          'optionLabel':
              option['label']?.toString() ??
              option['optionLabel']?.toString() ??
              option['title']?.toString() ??
              '',
          'priceModifier':
              option['priceModifier'] ??
              option['price_modifier'] ??
              option['modifier'] ??
              option['price'] ??
              0,
        });
      }
    }

    return answers;
  }

  List<String> _storageOptionsForModel(String modelName) {
    final modelId = _modelIdForName(modelName);

    if (modelId == null) return [];

    final storageOptions = _apiVariants
        .where((variant) => variant['modelId']?.toString() == modelId)
        .map((variant) => _formatStorage(variant['storage']?.toString()))
        .where((storage) => storage.isNotEmpty)
        .toSet()
        .toList();

    return storageOptions;
  }

  String? _modelIdForName(String modelName) {
    final normalizedModelName = _normalizeModelSearchText(modelName);
    final selectedBrandId = _selectedBrandId;

    for (final model in _apiModels) {
      final currentName = _normalizeModelSearchText(
        model['modelName']?.toString() ?? '',
      );
      final belongsToSelectedBrand =
          selectedBrandId == null ||
          model['brandId']?.toString() == selectedBrandId;

      if (belongsToSelectedBrand && currentName == normalizedModelName) {
        return model['id']?.toString();
      }
    }

    return null;
  }

  String _normalizeStorage(String? storage) {
    return (storage ?? '').toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]+'), '');
  }

  String _formatStorage(String? storage) {
    final value = (storage ?? '').trim().toUpperCase();
    if (value.isEmpty) return '';

    return value
        .replaceAllMapped(
          RegExp(r'(\d+)\s*(GB|TB)'),
          (match) => '${match.group(1)} ${match.group(2)}',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  int get _selectedVariantBasePrice {
    final variantId = _selectedVariantId;
    final modelId = _selectedModelId;
    final selectedStorage = _normalizeStorage(_selectedStorage);

    for (final variant in _apiVariants) {
      final currentVariantId = variant['id']?.toString();
      final variantModelId = variant['modelId']?.toString();
      final variantStorage = _normalizeStorage(variant['storage']?.toString());

      if (currentVariantId == variantId ||
          (variantModelId == modelId && variantStorage == selectedStorage)) {
        return _readPrice(variant, const [
          'basePrice',
          'base_price',
          'price',
          'variantPrice',
          'sellingPrice',
          'amount',
        ]);
      }
    }

    return 0;
  }

  int _readPrice(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final raw = row[key]?.toString();

      if (raw == null || raw.isEmpty) continue;

      final normalized = raw.replaceAll(RegExp(r'[^0-9-]'), '');
      final price = int.tryParse(normalized);

      if (price != null && price > 0) return price;
    }

    return 0;
  }

  Future<void> _launchContact(String type) async {
    Uri uri;
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
      String message =
          "Hello SeloRize, I need help with my Order #${finalOrderID}";
      String url =
          "https://wa.me/${whatsapp.replaceAll('+', '')}?text=${Uri.encodeComponent(message)}";
      uri = Uri.parse(url);
    } else {
      final email = contact['email'] ?? '';
      if (email.isEmpty || email.toLowerCase() == 'null') {
        _showSupportUnavailable();
        return;
      }
      uri = Uri.parse(
        "mailto:$email?subject=Support for Order ${finalOrderID}",
      );
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

  void _showSupportUnavailable() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Support contact is not available.")),
    );
  }

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }

  String _formatAddress(Map<String, dynamic>? address) {
    if (address == null) return 'Select pickup address';
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

  DateTime _pickupDateTimeForSave() {
    if (isInstantPickup) {
      return DateTime.now().add(const Duration(hours: 3));
    }

    final startHour = _selectedPickupSlot == '3 PM - 8 PM' ? 15 : 10;
    return DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      startHour,
    );
  }

  String _pickupDateTimePayload() {
    final pickupDateTime = _pickupDateTimeForSave();
    if (isInstantPickup) {
      return DateFormat('yyyy-MM-dd HH:mm:ss').format(pickupDateTime);
    }

    return '${DateFormat('yyyy-MM-dd').format(pickupDateTime)} $_selectedPickupSlot';
  }

  String _pickupArrivalLabel() {
    return isInstantPickup ? 'Within 3 Hours' : _selectedPickupSlot;
  }

  String _pickupReviewLabel() {
    final pickupDate = _pickupDateTimeForSave();
    if (isInstantPickup) {
      return 'Instant - Within 3 hours';
    }

    return '${DateFormat('d MMM yyyy').format(pickupDate)} | $_selectedPickupSlot';
  }

  Future<void> _pickPickupDate() async {
    final now = DateTime.now();
    final firstDate = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 1));
    final initialDate = selectedDate.isBefore(firstDate)
        ? firstDate
        : selectedDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: firstDate.add(const Duration(days: 90)),
      helpText: 'Select Pickup Date',
      confirmText: 'Confirm',
      cancelText: 'Cancel',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: const Color(0xFF4267B2)),
          ),
          child: child!,
        );
      },
    );

    if (picked == null || !mounted) return;
    setState(() => selectedDate = picked);
  }

  String _bankDetailValue(Map<String, dynamic>? bank) {
    if (bank == null) return '';
    final parts =
        [
              bank['accountName'],
              bank['bankName'],
              bank['accountNo'],
              bank['ifscCode'],
            ]
            .map((v) => v?.toString().trim() ?? '')
            .where((v) => v.isNotEmpty)
            .toList();
    if (parts.isNotEmpty) return parts.join(' | ');
    return bank['id']?.toString() ?? '';
  }

  String _bankDetailLabel(Map<String, dynamic> bank) {
    final accountNo = bank['accountNo']?.toString() ?? '';
    final masked = accountNo.length > 4
        ? '**** ${accountNo.substring(accountNo.length - 4)}'
        : accountNo;
    return '${bank['bankName'] ?? 'Bank'} - $masked';
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
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
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
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF4267B2).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.location_on_rounded,
              color: Color(0xFF4267B2),
              size: 20,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: hasMultipleAddresses
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
                      itemHeight: 48,
                      menuMaxHeight: 320,
                      style: const TextStyle(
                        color: Color(0xFF1E293B),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                      selectedItemBuilder: (context) => _savedAddresses
                          .map((address) => _buildAddressSelectionText(address))
                          .toList(),
                      items: _savedAddresses
                          .map(
                            (address) => DropdownMenuItem(
                              value: address,
                              child: _buildAddressSelectionText(address),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _selectedPickupAddress = value),
                    ),
                  )
                : _savedAddresses.isNotEmpty
                ? GestureDetector(
                    onTap: () => setState(
                      () => _selectedPickupAddress = _savedAddresses.first,
                    ),
                    child: _buildAddressSelectionText(
                      isGpsSelected
                          ? _savedAddresses.first
                          : _selectedPickupAddress,
                    ),
                  )
                : const Text(
                    'No saved address',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
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
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          _formatAddress(address),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 10,
            fontWeight: FontWeight.w600,
            height: 1.15,
          ),
        ),
      ],
    );
  }

  Widget _buildModernBankSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Map<String, dynamic>>(
          value: _selectedBankDetail,
          isExpanded: true,
          borderRadius: BorderRadius.circular(18),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xFF4A78A8),
          ),
          dropdownColor: Colors.white,
          itemHeight: 60,
          menuMaxHeight: 300,
          selectedItemBuilder: (context) => _savedBankDetails
              .map((bank) => _buildBankSelectionText(bank))
              .toList(),
          items: _savedBankDetails
              .map(
                (bank) => DropdownMenuItem(
                  value: bank,
                  child: _buildBankSelectionText(bank),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => _selectedBankDetail = value),
        ),
      ),
    );
  }

  Widget _buildPayoutMethodSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose payout method',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildPayoutMethodCard(
              value: 'bank',
              label: 'Bank',
              icon: Icons.account_balance_rounded,
            ),
            const SizedBox(width: 8),
            _buildPayoutMethodCard(
              value: 'upi',
              label: 'UPI',
              icon: Icons.qr_code_rounded,
            ),
            const SizedBox(width: 8),
            _buildPayoutMethodCard(
              value: 'cash',
              label: 'Cash',
              icon: Icons.payments_rounded,
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_selectedPayoutMethod == 'bank') ...[
          if (_savedBankDetails.isNotEmpty) ...[
            _buildModernBankSelector(),
            const SizedBox(height: 8),
          ],
          if (_showInlineBankForm)
            _buildInlineBankForm()
          else
            _buildInlineAddBankButton(),
        ] else if (_selectedPayoutMethod == 'upi') ...[
          TextField(
            controller: _upiIdController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              hintText: 'Enter UPI ID',
              prefixIcon: const Icon(Icons.alternate_email_rounded),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF4267B2)),
              ),
            ),
          ),
        ] else if (_selectedPayoutMethod == 'cash') ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: const Text(
              'Cash payment will be completed at pickup.',
              style: TextStyle(
                color: Color(0xFF166534),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPayoutMethodCard({
    required String value,
    required String label,
    required IconData icon,
  }) {
    final selected = _selectedPayoutMethod == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedPayoutMethod = value),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEFF6FF) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? const Color(0xFF4267B2)
                  : const Color(0xFFE2E8F0),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: selected
                    ? const Color(0xFF4267B2)
                    : const Color(0xFF64748B),
                size: 20,
              ),
              const SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? const Color(0xFF1E40AF)
                      : const Color(0xFF475569),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBankSelectionText(Map<String, dynamic> bank) {
    return Row(
      children: [
        Container(
          height: 38,
          width: 38,
          decoration: BoxDecoration(
            color: const Color(0xFF4A78A8).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(
            Icons.account_balance_rounded,
            color: Color(0xFF4A78A8),
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Payout Bank',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _bankDetailLabel(bank),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInlineAddBankButton() {
    return InkWell(
      onTap: () {
        final user = context.read<AuthViewModel>().loggedInUser;
        setState(() {
          _showInlineBankForm = true;
          if (_bankAccountNameController.text.trim().isEmpty) {
            _bankAccountNameController.text = user?.name ?? '';
          }
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: const Color(0xFFEEF2FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFC7D2FE)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_card_rounded, color: Color(0xFF4F46E5), size: 20),
            SizedBox(width: 8),
            Text(
              'Add Bank Account',
              style: TextStyle(
                color: Color(0xFF4F46E5),
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInlineBankField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: Color(0xFF0F172A),
      ),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 20),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.4),
        ),
      ),
    );
  }

  Widget _buildInlineBankForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 38,
                width: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Color(0xFF16A34A),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Add payout bank',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              IconButton(
                onPressed: _isSavingBankDetail
                    ? null
                    : () => setState(() => _showInlineBankForm = false),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildInlineBankField(
            controller: _bankAccountNameController,
            label: 'Account holder name',
            icon: Icons.person_outline_rounded,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          _buildInlineBankField(
            controller: _bankNameController,
            label: 'Bank name',
            icon: Icons.account_balance_rounded,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          _buildInlineBankField(
            controller: _bankAccountNoController,
            label: 'Account number',
            icon: Icons.numbers_rounded,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          _buildInlineBankField(
            controller: _bankIfscController,
            label: 'IFSC code',
            icon: Icons.qr_code_rounded,
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isSavingBankDetail ? null : _saveInlineBankDetail,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E293B),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            child: _isSavingBankDetail
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Save & Use This Bank',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                  ),
          ),
        ],
      ),
    );
  }

  void _clearInlineBankFields() {
    _bankNameController.clear();
    _bankAccountNoController.clear();
    _bankIfscController.clear();
  }

  Future<void> _saveInlineBankDetail() async {
    final vm = context.read<AuthViewModel>();
    final userId = vm.loggedInUser?.id ?? '';
    final accountName = _bankAccountNameController.text.trim();
    final bankName = _bankNameController.text.trim();
    final accountNo = _bankAccountNoController.text.trim();
    final ifscCode = _bankIfscController.text.trim().toUpperCase();

    if (userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login before adding bank.')),
      );
      return;
    }
    if (accountName.isEmpty ||
        bankName.isEmpty ||
        accountNo.isEmpty ||
        ifscCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all bank details.')),
      );
      return;
    }
    if (accountNo.length < 9) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid account number.')),
      );
      return;
    }
    if (!RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(ifscCode)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter valid IFSC code.')));
      return;
    }

    setState(() => _isSavingBankDetail = true);
    final success = await vm.saveBankDetails(
      userId: userId,
      accountName: accountName,
      bankName: bankName,
      accountNo: accountNo,
      ifscCode: ifscCode,
    );
    if (!mounted) return;

    if (!success) {
      setState(() => _isSavingBankDetail = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(vm.errorMessage ?? 'Bank details save failed.')),
      );
      return;
    }

    await _loadSellData();
    if (!mounted) return;

    Map<String, dynamic>? savedBank;
    for (final bank in _savedBankDetails.reversed) {
      if ((bank['accountNo']?.toString() ?? '') == accountNo &&
          (bank['ifscCode']?.toString() ?? '').toUpperCase() == ifscCode) {
        savedBank = bank;
        break;
      }
    }

    setState(() {
      _selectedBankDetail =
          savedBank ??
          (_savedBankDetails.isNotEmpty ? _savedBankDetails.last : null);
      _showInlineBankForm = false;
      _isSavingBankDetail = false;
      _clearInlineBankFields();
      _bankAccountNameController.text = vm.loggedInUser?.name ?? accountName;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bank details saved and selected.')),
    );
  }

  void _confirmPickupAddress() {
    if (_selectedPickupAddress == null && _fetchedAddress.isNotEmpty) {
      setState(() {
        _selectedPickupAddress = _buildGpsAddress();
      });
    }

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

  void _openAddressSelectionScreen() {
    if (_pickupLatitude.isEmpty || _pickupLongitude.isEmpty) {
      _fetchCurrentLocation();
    }
    setState(() => _showAddressSelection = true);
  }

  Future<void> _savePickupAddress() async {
    if (_isSavingAddress) return;

    final user = context.read<AuthViewModel>().loggedInUser;
    final userId = user?.id ?? '';
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
      await _repo.saveAddress(
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

      try {
        final freshAddresses = await _repo.getData(
          tableName: 'address',
          filter: {'userId': userId},
        );
        if (!mounted) return;

        Map<String, dynamic>? newAddress;
        if (freshAddresses.isNotEmpty) {
          newAddress = freshAddresses.lastWhere(
            (a) =>
                a['name']?.toString() == name &&
                a['mobile']?.toString() == mobile &&
                a['houseNo']?.toString() == houseNo,
            orElse: () => freshAddresses.last,
          );
        }

        setState(() {
          _savedAddresses = freshAddresses;
          _selectedPickupAddress =
              newAddress ??
              (freshAddresses.isNotEmpty ? freshAddresses.last : null);
          _showAddAddress = false;
          _showAddressSelection = true;
          _addressNameController.clear();
          _addressMobileController.clear();
          _addressHouseController.clear();
          _addressStreetController.clear();
          _addressCityController.clear();
          _addressStateController.clear();
          _addressPincodeController.clear();
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Address saved! "${name}" added to your addresses.',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );
      } catch (_) {
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
          _addressNameController.clear();
          _addressMobileController.clear();
          _addressHouseController.clear();
          _addressStreetController.clear();
          _addressCityController.clear();
          _addressStateController.clear();
          _addressPincodeController.clear();
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Address saved! "${name}" added to your addresses.',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );
      }

      if (!mounted) return;
    } finally {
      if (mounted) {
        setState(() => _isSavingAddress = false);
      }
    }
  }

  Map<String, dynamic> _buildGpsAddress() {
    final user = context.read<AuthViewModel>().loggedInUser;
    return {
      'name': _addressNameController.text.trim().isNotEmpty
          ? _addressNameController.text.trim()
          : (user?.name ?? ''),
      'mobile': _addressMobileController.text.trim().isNotEmpty
          ? _addressMobileController.text.trim()
          : (user?.mobile ?? ''),
      'houseNo': '',
      'street': _fetchedAddress.trim().isNotEmpty
          ? _fetchedAddress.trim()
          : _addressStreetController.text.trim(),
      'city': _addressCityController.text.trim(),
      'state': _addressStateController.text.trim(),
      'pincode': _addressPincodeController.text.trim(),
      'address': _fetchedAddress.trim(),
      'fullAddress': _fetchedAddress.trim(),
      'addressType': 'GPS',
      'id': '',
      'latitude': _pickupLatitude,
      'longitude': _pickupLongitude,
    };
  }

  String _enquiryAddressText(Map<String, dynamic> address) {
    if (_isCurrentLocationAddress(address) &&
        _fetchedAddress.trim().isNotEmpty) {
      return _fetchedAddress.trim();
    }

    for (final key in const [
      'fullAddress',
      'full_address',
      'address',
      'formattedAddress',
      'formatted_address',
    ]) {
      final value = address[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }

    final parts = <String>[];
    for (final key in const [
      'houseNo',
      'house_no',
      'street',
      'area',
      'locality',
      'city',
      'state',
      'pincode',
      'pinCode',
    ]) {
      final value = address[key]?.toString().trim() ?? '';
      if (value.isNotEmpty && !parts.contains(value)) parts.add(value);
    }
    return parts.join(', ');
  }

  Future<void> _saveEnquiryAndFinish() async {
    if (_isSavingEnquiry) return;

    if (_selectedPickupAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a pickup address before confirming.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedPayoutMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a payout method.')),
      );
      return;
    }

    if (_selectedPayoutMethod == 'bank' && _selectedBankDetail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or add a bank account.')),
      );
      return;
    }

    if (_selectedPayoutMethod == 'upi' &&
        _upiIdController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your UPI ID.')),
      );
      return;
    }

    // Get DB ids for validation
    final addressId = _selectedPickupAddress?['id']?.toString() ?? '';

    // GPS uses the fetched map address; saved selection uses stored fields.
    final addr = _selectedPickupAddress!;
    var addressString = _enquiryAddressText(addr);
    final isCurrentLocationAddress = _isCurrentLocationAddress(addr);

    // Bank Details - optional
    final bank = _selectedBankDetail;
    final bankId = bank?['id']?.toString() ?? '';

    final bankParts = <String>[
      if ((bank?['accountName']?.toString().trim() ?? '').isNotEmpty)
        bank!['accountName'].toString().trim(),
      if ((bank?['bankName']?.toString().trim() ?? '').isNotEmpty)
        bank!['bankName'].toString().trim(),
      if ((bank?['accountNo']?.toString().trim() ?? '').isNotEmpty)
        bank!['accountNo'].toString().trim(),
      if ((bank?['ifscCode']?.toString().trim() ?? '').isNotEmpty)
        bank!['ifscCode'].toString().trim(),
    ];

    final bankString = _selectedPayoutMethod == 'cash'
        ? 'Cash'
        : _selectedPayoutMethod == 'upi'
        ? 'UPI | ${_upiIdController.text.trim()}'
        : 'Bank Account | ${bankParts.join(' | ')}';

    if (isCurrentLocationAddress &&
        (_pickupLatitude.isEmpty || _pickupLongitude.isEmpty)) {
      await _fetchCurrentLocation();
    }

    if (isCurrentLocationAddress &&
        (_pickupLatitude.isEmpty || _pickupLongitude.isEmpty)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not fetch location. Please enable GPS and try again.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final enquiryLatitude = isCurrentLocationAddress ? _pickupLatitude : '';
    final enquiryLongitude = isCurrentLocationAddress ? _pickupLongitude : '';
    if (isCurrentLocationAddress) {
      addressString = _enquiryAddressText(addr);
    }

    if (addressString.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not read pickup address. Please select again.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() => _isSavingEnquiry = true);
    try {
      final user = context.read<AuthViewModel>().loggedInUser;

      final pickupDateTime = _pickupDateTimePayload();
      final bookingType = isInstantPickup ? 'instant' : 'schedule';

      debugPrint(
        'saveEnquiry => addressId=$addressId | bankId=$bankId | addressString=$addressString | bankString=$bankString | pickupDateTime=$pickupDateTime | lat=$enquiryLatitude | lng=$enquiryLongitude',
      );

      final enquiryResponse = await _repo.saveEnquiry(
        modelId: _selectedModelId,
        variantId: _selectedVariantId,
        basePrice: _enquiryBasePrice,
        finalPrice: _totalPrice,
        userId: user?.id ?? '',
        customerName: user?.name ?? '',
        customerMobile: user?.mobile ?? '',
        customerEmail: user?.email ?? '',
        address: addressString,
        bankDetail: bankString,
        latitude: enquiryLatitude,
        longitude: enquiryLongitude,
        pickupDateTime: pickupDateTime,
        bookingType: bookingType,
        answers: _selectedQuestionAnswers(),
        coupon: _appliedCoupon ?? '',
        couponPrice: _couponDiscount,
      );

      debugPrint('saveEnquiry response => $enquiryResponse');

      final rawId =
          enquiryResponse['id'] ??
          enquiryResponse['enquiryId'] ??
          enquiryResponse['enquiry_id'] ??
          (enquiryResponse['data'] is Map
              ? enquiryResponse['data']['id']
              : null);
      final dbId = rawId?.toString() ?? '';
      debugPrint('saveEnquiry DB id => $dbId');

      if (!mounted) return;

      // Notify parent about the new listing
      widget.onFinish?.call(
        _selectedBrand ?? '',
        _selectedModel ?? '',
        _selectedStorage,
        _totalPrice,
        DateFormat('dd / MMMM / yyyy').format(_pickupDateTimeForSave()),
        _formatAddress(_selectedPickupAddress),
        bankString,
        enquiryLatitude,
        enquiryLongitude,
      );

      setState(() {
        if (dbId.isNotEmpty) finalOrderID = dbId;
        _showSuccess = true;
      });
    } catch (e) {
      debugPrint('Save enquiry error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save enquiry: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingEnquiry = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: _showCancelSuccess
              ? _buildCancelSuccessScreen()
              : _showCancelScreen
              ? _buildCancelScreen()
              : (_showSuccess)
              ? _buildSuccessScreen()
              : (_showFinalReview)
              ? _buildFinalReviewScreen()
              : (_showPickupType)
              ? _buildPickupTypeScreen()
              : (_showAddAddress
                    ? _buildAddAddressScreen()
                    : (_showAddressSelection
                          ? _buildAddressSelectionScreen()
                          : (_showCheckout
                                ? _buildCheckoutScreen()
                                : (_showAdminImageQuestion
                                      ? _buildAdminImageQuestionScreen()
                                      : (_showCondition
                                            ? _buildConditionScreen()
                                            : (_showValuation
                                                  ? _buildValuationResult()
                                                  : (_selectedModel != null
                                                        ? _buildDeviceDetails()
                                                        : (_selectedBrand !=
                                                                  null
                                                              ? _buildModelSelection()
                                                              : (_showBrandSelection
                                                                    ? _buildBrandSelection()
                                                                    : _buildSellIntro()))))))))),
        ),
      ),
    );
  }

  Widget _buildSellIntro() {
    final size = MediaQuery.of(context).size;
    return Column(
      key: const ValueKey('intro'),
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                const SizedBox(height: 30),
                const Text(
                  'Sell Smarter.',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.5,
                    color: Color(0xFF0F172A),
                    height: 1.1,
                  ),
                ),
                const Text(
                  'Get Instant Cash.',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6366F1),
                  ),
                ),
                const SizedBox(height: 30),
                Container(
                  height: size.width * 0.75,
                  width: size.width * 0.75,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: size.width * 0.75,
                        height: size.width * 0.75,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFF6366F1).withOpacity(0.20),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      Container(
                        width: size.width * 0.58,
                        height: size.width * 0.58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 25,
                              offset: const Offset(0, 12),
                            ),
                            BoxShadow(
                              color: const Color(0xFF6366F1).withOpacity(0.12),
                              blurRadius: 35,
                              offset: const Offset(0, 18),
                            ),
                          ],
                        ),
                      ),
                      TweenAnimationBuilder(
                        tween: Tween(begin: -8.0, end: 8.0),
                        duration: const Duration(seconds: 3),
                        curve: Curves.easeInOut,
                        builder: (context, value, child) {
                          return Transform.translate(
                            offset: Offset(0, value),
                            child: child,
                          );
                        },
                        child: Lottie.asset(
                          'assets/animation-sell.json',
                          width: size.width * 0.55,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'Turn your old devices into\nreal value in less than 2 minutes.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: ElevatedButton(
            onPressed: () => setState(() => _showBrandSelection = true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 68),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 0,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Get Started',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(width: 10),
                Icon(Icons.arrow_forward_rounded, size: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIntroBadge(IconData icon, Color color, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandSelection() {
    return Column(
      key: const ValueKey('brandSelection'),
      children: [
        _buildStepHeader(
          'Select Brand',
          () => setState(() => _showBrandSelection = false),
        ),
        // earch Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.07),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _brandSearchController,
                  autofocus: false,
                  onChanged: (val) {
                    final query = val.toLowerCase().trim();
                    setState(() {
                      _brandSearchQuery = val;
                      if (query.isEmpty) {
                        _modelSearchResults = [];
                        return;
                      }
                      final results = <Map<String, dynamic>>[];
                      final seen = <String>{};

                      // API models
                      for (final model in _apiModels) {
                        final modelName = model['modelName']?.toString() ?? '';
                        if (modelName.isEmpty) continue;
                        if (modelName.toLowerCase().contains(query) &&
                            !seen.contains(modelName)) {
                          seen.add(modelName);
                          String brandName = '';
                          for (final brand in _apiBrands) {
                            if (brand['id']?.toString() ==
                                model['brandId']?.toString()) {
                              brandName = brand['brandName']?.toString() ?? '';
                              break;
                            }
                          }
                          results.add({
                            'modelName': modelName,
                            'brandName': brandName,
                            'source': 'api',
                          });
                        }
                      }

                      _modelSearchResults = results.take(8).toList();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search model (e.g. Galaxy S22, iPhone 13)...',
                    hintStyle: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    icon: const Icon(Icons.search, color: Color(0xFF4A78A8)),
                    suffixIcon: _brandSearchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.close,
                              size: 18,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              _brandSearchController.clear();
                              setState(() {
                                _brandSearchQuery = '';
                                _modelSearchResults = [];
                              });
                            },
                          )
                        : null,
                  ),
                ),
              ),
              // Model Search
              if (_modelSearchResults.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.10),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: _modelSearchResults.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: Colors.grey.shade100),
                    itemBuilder: (context, i) {
                      final result = _modelSearchResults[i];
                      final modelName = result['modelName'] as String;
                      final brandName = result['brandName'] as String;
                      return ListTile(
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF4A78A8).withOpacity(0.06),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: _buildModelThumbnail(modelName, size: 32),
                          ),
                        ),
                        title: Text(
                          modelName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: brandName.isNotEmpty
                            ? Text(
                                brandName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              )
                            : null,
                        trailing: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: Color(0xFF94A3B8),
                        ),
                        onTap: () {
                          if (brandName.isNotEmpty) {
                            _selectBrand(brandName);
                          }
                          _brandSearchController.clear();
                          setState(() {
                            _brandSearchQuery = '';
                            _modelSearchResults = [];
                          });
                          Future.delayed(const Duration(milliseconds: 80), () {
                            if (mounted) _selectModel(modelName);
                          });
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        // Brand Grid
        Expanded(
          child:
              (_isLoadingSellData && _displayBrands.isEmpty) ||
                  (_displayBrands.isNotEmpty && !_sellBrandImagesReady)
              ? const Center(child: CircularProgressIndicator())
              : _displayBrands.isEmpty
              ? _buildApiDataMessage(
                  _sellDataErrorMessage ??
                      'No brands are available right now. Please try again.',
                  onRetry: _loadSellData,
                )
              : _modelSearchResults.isNotEmpty
              ? const SizedBox.shrink() // search results dikhne par grid hide karo
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1,
                  ),
                  itemCount: _displayBrands.length,
                  itemBuilder: (context, index) {
                    final brandName = _displayBrands[index]['name']!;
                    return GestureDetector(
                      onTap: () {
                        _selectBrand(brandName);
                        _brandSearchController.clear();
                        setState(() {
                          _brandSearchQuery = '';
                          _modelSearchResults = [];
                        });
                      },
                      child: _buildBrandItem(
                        _displayBrands[index]['asset']!,
                        brandName,
                        imageUrl: _displayBrands[index]['imageUrl'],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildApiDataMessage(String message, {VoidCallback? onRetry}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF475569),
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF4267B2),
                  side: const BorderSide(color: Color(0xFF4267B2)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Map<String, String>> get _displayBrands {
    final query = _brandSearchQuery.toLowerCase().trim();
    final sourceBrands = _apiBrands;

    Set<String> matchedBrandIdsByModel = {};
    if (query.isNotEmpty && _apiModels.isNotEmpty) {
      for (final model in _apiModels) {
        final modelName = model['modelName']?.toString().toLowerCase() ?? '';
        if (modelName.contains(query)) {
          final brandId = model['brandId']?.toString() ?? '';
          if (brandId.isNotEmpty) matchedBrandIdsByModel.add(brandId);
        }
      }
    }

    final result = sourceBrands
        .map((brand) {
          final name = brand['brandName']?.toString() ?? '';
          if (name.isEmpty) return null;

          // Filter by query
          if (query.isNotEmpty) {
            final brandId = brand['id']?.toString() ?? '';
            final brandMatches = name.toLowerCase().contains(query);
            final modelMatches = matchedBrandIdsByModel.contains(brandId);
            if (!brandMatches && !modelMatches) return null;
          }

          final imageUrl = _brandImageUrl(brand);
          return {
            'name': name,
            'asset': _brandAssetForName(name),
            if (imageUrl != null) 'imageUrl': imageUrl,
          };
        })
        .whereType<Map<String, String>>()
        .toList();

    return result;
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

      if (looksLikeImage) {
        return _absoluteMediaUrl(rawValue);
      }
    }

    return null;
  }

  String _absoluteMediaUrl(String value) {
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return Uri.encodeFull(value.replaceAll('\\', '/'));
    }

    var cleanPath = value.replaceAll('\\', '/').trim();
    cleanPath = cleanPath.startsWith('/') ? cleanPath.substring(1) : cleanPath;
    cleanPath = cleanPath.replaceFirst(RegExp(r'^(cashify/)?public/'), '');
    return Uri.encodeFull('${ApiConstants.MEDIA_BASE_URL}$cleanPath');
  }

  void _warmDeviceImages({
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

  Future<void> _prepareSellBrandImages(
    Iterable<Map<String, dynamic>> brands,
  ) async {
    final urls = brands
        .map(_brandImageUrl)
        .whereType<String>()
        .where((url) => url.trim().isNotEmpty)
        .take(24)
        .toList();

    if (urls.isEmpty || !mounted) return;

    final futures = urls.map((url) async {
      if (_isSvgUrl(url)) return;
      try {
        await precacheImage(CachedNetworkImageProvider(url), context);
        _preloadedImageUrls.add(url);
      } catch (error) {
        debugPrint('Sell brand image prepare failed => $url | $error');
      }
    });

    await Future.any([
      Future.wait(futures),
      Future<void>.delayed(const Duration(milliseconds: 2500)),
    ]);
  }

  Future<void> _prepareModelImagesForBrand(String brandName) async {
    final normalizedBrandName = _normalizeBrandName(brandName);
    String? brandId;

    for (final brand in _apiBrands) {
      if (_normalizeBrandName(brand['brandName']?.toString()) ==
          normalizedBrandName) {
        brandId = brand['id']?.toString();
        break;
      }
    }

    if (brandId == null) {
      if (mounted) setState(() => _modelImagesReady = true);
      return;
    }

    final models = _apiModels.where(
      (model) => model['brandId']?.toString() == brandId,
    );
    await _prepareModelImages(models);
  }

  Future<void> _prepareModelImages(
    Iterable<Map<String, dynamic>> models,
  ) async {
    final urls = models
        .map(_modelImageUrl)
        .whereType<String>()
        .where((url) => url.trim().isNotEmpty)
        .take(16)
        .toList();

    if (urls.isEmpty || !mounted) {
      if (mounted) setState(() => _modelImagesReady = true);
      return;
    }

    final futures = urls.map((url) async {
      if (_isSvgUrl(url)) return;
      try {
        await precacheImage(CachedNetworkImageProvider(url), context);
        _preloadedImageUrls.add(url);
      } catch (error) {
        debugPrint('Model image prepare failed => $url | $error');
      }
    });

    await Future.any([
      Future.wait(futures),
      Future<void>.delayed(const Duration(milliseconds: 2200)),
    ]);

    if (mounted) setState(() => _modelImagesReady = true);
  }

  void _warmDeviceImagesForBrand(String brandName) {
    if (!mounted) return;
    final normalizedBrandName = _normalizeBrandName(brandName);
    String? brandId;

    for (final brand in _apiBrands) {
      if (_normalizeBrandName(brand['brandName']?.toString()) ==
          normalizedBrandName) {
        brandId = brand['id']?.toString();
        break;
      }
    }

    if (brandId == null) return;
    final brandModels = _apiModels
        .where((model) => model['brandId']?.toString() == brandId)
        .take(48);
    _warmDeviceImages(models: brandModels);
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
        debugPrint('Image preload failed => $url | $error');
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
          debugPrint('Svg image load failed => $url | $error');
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
        debugPrint('Image load failed => $url | $error');
        return errorPlaceholder ?? placeholder;
      },
    );
  }

  Map<String, dynamic>? _modelForName(String? name) {
    if (name == null || name.isEmpty) return null;

    final brandId = _selectedBrandId;
    for (final model in _apiModels) {
      final modelName = model['modelName']?.toString();
      final modelBrandId = model['brandId']?.toString();
      if (modelName == name && (brandId == null || modelBrandId == brandId)) {
        return model;
      }
    }

    for (final model in _apiModels) {
      if (model['modelName']?.toString() == name) return model;
    }

    return null;
  }

  String? _modelImageUrlByName(String? name) {
    final model = _modelForName(name);
    if (model == null) return null;

    return _modelImageUrl(model);
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

  Widget _buildDeviceImage({
    double? height,
    double? width,
    BoxFit fit = BoxFit.contain,
    double iconSize = 60,
  }) {
    final imageUrl = _modelImageUrlByName(_selectedModel);

    if (imageUrl == null) {
      return _buildFallbackDeviceImage(
        height: height,
        width: width,
        fit: fit,
        iconSize: iconSize,
      );
    }

    final placeholder = _buildModelImageSkeleton(size: iconSize);
    return _buildNetworkMedia(
      url: imageUrl,
      placeholder: placeholder,
      height: height,
      width: width,
      fit: fit,
    );
  }

  Widget _buildFallbackDeviceImage({
    double? height,
    double? width,
    BoxFit fit = BoxFit.contain,
    double iconSize = 60,
  }) {
    return Image.asset(
      'assets/iphone_normal.png',
      height: height,
      width: width,
      fit: fit,
      errorBuilder: (context, error, stackTrace) =>
          Icon(Icons.phone_android, size: iconSize, color: Colors.grey),
    );
  }

  Widget _buildModelThumbnail(String name, {double size = 80}) {
    final imageUrl = _modelImageUrlByName(name);

    Widget placeholder() => _buildModelImageSkeleton(size: size);

    if (imageUrl == null) return placeholder();

    return SizedBox(
      height: size,
      width: size,
      child: _buildNetworkMedia(
        url: imageUrl,
        placeholder: placeholder(),
        height: size,
        width: size,
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildModelImageSkeleton({double size = 80}) {
    final phoneHeight = size * 0.72;
    final phoneWidth = size * 0.48;
    return SizedBox(
      height: size,
      width: size,
      child: Center(
        child: Container(
          height: phoneHeight,
          width: phoneWidth,
          decoration: BoxDecoration(
            color: const Color(0xFFE8EEF5),
            borderRadius: BorderRadius.circular(size * 0.11),
          ),
          child: Stack(
            children: [
              Positioned(
                top: phoneHeight * 0.12,
                left: phoneWidth * 0.18,
                right: phoneWidth * 0.18,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD5DFEA),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              Positioned(
                left: phoneWidth * 0.18,
                right: phoneWidth * 0.18,
                bottom: phoneHeight * 0.10,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD5DFEA),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModelSelection() {
    final allModels = _currentAvailableModels;
    final series = _currentBrandSeries;
    final query = _modelListSearchQuery.trim();
    final models = query.isEmpty
        ? allModels
        : allModels
              .where((model) => _matchesModelSearch(model, query))
              .toList();

    return Column(
      key: const ValueKey('modelSelection'),
      children: [
        _buildStepHeader('$_selectedBrand Models', () => _handleSystemBack()),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: TextField(
            controller: _modelListSearchController,
            onChanged: (value) => setState(() => _modelListSearchQuery = value),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => FocusScope.of(context).unfocus(),
            decoration: InputDecoration(
              hintText: 'Search model...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _modelListSearchQuery.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _modelListSearchController.clear();
                        setState(() => _modelListSearchQuery = '');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF4267B2)),
              ),
            ),
          ),
        ),
        Expanded(
          child: _isLoadingSeriesModels
              ? const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(0xFF4267B2),
                  ),
                )
              : allModels.isNotEmpty && !_modelImagesReady
              ? const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(0xFF4267B2),
                  ),
                )
              : allModels.isEmpty && _isCheckingBrandModels
              ? const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(0xFF4267B2),
                  ),
                )
              : allModels.isEmpty && series.isEmpty
              ? _buildApiDataMessage(
                  _sellDataErrorMessage ?? _emptyModelMessage,
                  onRetry: _selectedSeriesId == null
                      ? _loadSellData
                      : () => _selectSeries(_selectedSeriesId),
                )
              : models.isEmpty && allModels.isNotEmpty
              ? const Center(
                  child: Text(
                    'No matching models found.',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  children: [
                    if (series.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Choose By Series',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (_selectedSeriesId != null)
                              TextButton(
                                onPressed: () => _selectSeries(null),
                                style: TextButton.styleFrom(
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 6,
                                  ),
                                ),
                                child: const Text(
                                  'View All',
                                  style: TextStyle(
                                    color: Color(0xFF4267B2),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 50,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 4,
                          ),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minWidth: constraints.maxWidth,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      for (
                                        var index = 0;
                                        index < series.length;
                                        index++
                                      ) ...[
                                        if (index > 0) const SizedBox(width: 8),
                                        _buildSeriesCard(
                                          series[index]['id']?.toString(),
                                          _seriesName(series[index]),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                    ],
                    if (models.isEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 80, 24, 0),
                        child: _buildApiDataMessage(
                          _sellDataErrorMessage ?? _emptyModelMessage,
                          onRetry: _selectedSeriesId == null
                              ? _loadSellData
                              : () => _selectSeries(_selectedSeriesId),
                        ),
                      )
                    else ...[
                      _buildSectionTitle(
                        _selectedSeriesName.isEmpty
                            ? 'All Models'
                            : '$_selectedSeriesName Models',
                      ),
                      const SizedBox(height: 14),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            const columns = 4;
                            const spacing = 4.0;
                            final itemWidth =
                                (constraints.maxWidth -
                                    (spacing * (columns - 1))) /
                                columns;

                            return Wrap(
                              spacing: spacing,
                              runSpacing: 12,
                              children: models
                                  .map(
                                    (model) => SizedBox(
                                      width: itemWidth,
                                      child: _buildModelGridItem(model),
                                    ),
                                  )
                                  .toList(),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildSeriesCard(String? seriesId, String label) {
    final isSelected = _selectedSeriesId == seriesId;
    final showClose = isSelected && seriesId != null;
    final labelStyle = TextStyle(
      color: isSelected ? Colors.white : const Color(0xFF334155),
      fontSize: 14,
      fontWeight: FontWeight.w800,
    );
    final labelPainter = TextPainter(
      text: TextSpan(text: label, style: labelStyle),
      maxLines: 1,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final chipWidth = labelPainter.width + (showClose ? 57 : 30);

    return GestureDetector(
      onTap: () => _selectSeries(isSelected ? null : seriesId),
      child: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: chipWidth,
            height: 42,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF4267B2) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF4267B2)
                    : const Color(0xFFCBD5E1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              style: labelStyle,
            ),
          ),
          if (showClose)
            Positioned(
              top: 3,
              right: 4,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 11,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool _matchesModelSearch(String modelName, String query) {
    final normalizedQuery = _normalizeModelSearchText(query);
    if (normalizedQuery.isEmpty) return true;

    final searchableText = _normalizeModelSearchText(
      '${_selectedBrand ?? ''} $modelName',
    );
    final queryTokens = normalizedQuery.split(' ');
    if (queryTokens.every(searchableText.contains)) return true;

    return searchableText
        .replaceAll(' ', '')
        .contains(normalizedQuery.replaceAll(' ', ''));
  }

  String _normalizeModelSearchText(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  Widget _buildDeviceDetails() {
    final models = _currentAvailableModels;
    if (_selectedModel != null &&
        models.isNotEmpty &&
        !models.contains(_selectedModel)) {
      _selectedModel = models.first;
    }
    final storageOptions = _currentAvailableStorageOptions;
    if (storageOptions.isEmpty) {
      return Column(
        key: const ValueKey('deviceDetailsUnavailable'),
        children: [
          _buildStepHeader(
            _selectedModel ?? 'Device Details',
            () => setState(() => _selectedModel = null),
          ),
          Expanded(
            child: _buildApiDataMessage(
              _sellDataErrorMessage ??
                  'Storage variants are not available for this model right now.',
              onRetry: _loadSellData,
            ),
          ),
        ],
      );
    }
    if (!storageOptions.contains(_selectedStorage)) {
      _selectedStorage = storageOptions.first;
    }

    return Column(
      key: const ValueKey('deviceDetails'),
      children: [
        _buildStepHeader(
          _selectedModel ?? 'Device Details',
          () => setState(() => _selectedModel = null),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxHeight < 520;
              final imageAreaHeight = isCompact ? 185.0 : 210.0;
              final deviceImageHeight = isCompact ? 150.0 : 185.0;
              final labelGap = isCompact ? 14.0 : 20.0;

              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: imageAreaHeight,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Center(
                            child: _buildDeviceImage(
                              height: deviceImageHeight,
                              iconSize: isCompact ? 72 : 88,
                            ),
                          ),
                          Positioned(
                            left: 0,
                            child: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.grey.shade300,
                              size: 24,
                            ),
                          ),
                          Positioned(
                            right: 0,
                            child: Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: Colors.grey.shade300,
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Center(
                      child: Column(
                        children: [
                          Text(
                            _selectedModel ?? 'Device Details',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: isCompact ? 22 : 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: labelGap),
                    const Text(
                      'Model',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedModel,
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded),
                          items: models.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              _selectModel(val);
                            }
                          },
                        ),
                      ),
                    ),
                    if (_isLoadingQuestions) ...[
                      const SizedBox(height: 6),
                      const Text(
                        'Loading model questions...',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                    SizedBox(height: isCompact ? 14 : 18),
                    const Text(
                      'Storage',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: storageOptions
                          .map(
                            (storage) => [
                              _buildOptionButton(
                                storage,
                                _selectedStorage == storage,
                                (v) => setState(() => _selectedStorage = v),
                              ),
                              if (storage != storageOptions.last)
                                const SizedBox(width: 12),
                            ],
                          )
                          .expand((widgets) => widgets)
                          .toList(),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: ElevatedButton(
            onPressed: () => setState(() => _showValuation = true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A78A8),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Calculate Value',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildValuationResult() {
    String modelName = _selectedModel ?? "";
    String brandName = _selectedBrand ?? "";
    String fullName = modelName.contains(brandName)
        ? modelName
        : "$brandName $modelName";

    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            color: Colors.black.withOpacity(0.5),
            child: _buildDeviceDetails(),
          ),
        ),

        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.82,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Container(
                        height: 80,
                        width: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _buildDeviceImage(iconSize: 32),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fullName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '($_selectedStorage)',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Selected Device',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _showValuation = false),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.edit_outlined,
                            color: Colors.blue.shade700,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    () {
                      final base = _selectedVariantBasePrice;
                      return '\u20b9 ${_formatPrice(base)}';
                    }(),
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Text(
                    'Estimated resale value based on market place',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => _showPriceExplanation(context),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF334155),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.white,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Price Calculation Explained',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text(
                        'Estimation Accuracy: ',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _estimationAccuracyLabel,
                        style: TextStyle(
                          color: _estimationAccuracyColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: _estimationAccuracyValue,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade300,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _estimationAccuracyColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: _buildSmallBenefit(
                          'Instant\nPayment',
                          Icons.monetization_on_rounded,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSmallBenefit(
                          'Free\nPickup',
                          Icons.local_shipping_rounded,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSmallBenefit(
                          'No Hidden\nCharges',
                          Icons.block_flipped,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  ElevatedButton(
                    onPressed: () {
                      if (_adminImageQuestions.isNotEmpty) {
                        setState(() {
                          _adminImageQuestionIndex = 0;
                          _showAdminImageQuestion = true;
                        });
                      } else {
                        _calculateExactPrice();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A78A8),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 58),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Get Exact Value',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showPriceExplanation(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              // CONTENT SECTION
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Valuation Process',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1E293B),
                            letterSpacing: -0.5,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: CircleAvatar(
                            radius: 15,
                            backgroundColor: Colors.grey.shade100,
                            child: const Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    const Text(
                      "How we calculate your price:",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4A78A8),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Our AI-driven price engine uses advanced algorithms to analyze real-time market data from multiple secondary marketplaces. We take into account several professional factors to offer you the most competitive price possible.",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Info Points
                    _buildInfoPoint(
                      Icons.trending_up_rounded,
                      "Market Demand",
                      "Live tracking of global and local resale trends ensures up-to-date pricing.",
                    ),
                    _buildInfoPoint(
                      Icons.settings_suggest_rounded,
                      "Device Specifications",
                      "Price is tailored specifically to your RAM, Storage, and model-specific hardware features.",
                    ),
                    _buildInfoPoint(
                      Icons.check_circle_outline_rounded,
                      "Condition Logic",
                      "Our system applies precision logic based on the physical and functional condition you report.",
                    ),
                    _buildInfoPoint(
                      Icons.verified_rounded,
                      "Zero Hidden Fees",
                      "The price you see is the price you get, with all costs already factored in.",
                    ),

                    const SizedBox(height: 24),

                    // Bottom Note
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A78A8).withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF4A78A8).withOpacity(0.1),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.lightbulb_outline_rounded,
                            color: Color(0xFF4A78A8),
                            size: 20,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Note: The exact final value is subject to physical verification of the device by our agent at the time of pickup.",
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF4A78A8),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoPoint(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF1E293B), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConditionScreen() {
    String modelName = _selectedModel ?? "";
    String brandName = _selectedBrand ?? "";
    String fullName = modelName.contains(brandName)
        ? modelName
        : "$brandName $modelName";
    final sequenceQuestions = _adminImageQuestions;
    final canContinue = !_isLoadingQuestions;

    return Column(
      key: const ValueKey('condition'),
      children: [
        _buildStepHeader(
          'Device Condition',
          () => setState(() => _showCondition = false),
        ),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Device Info Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      _buildDeviceImage(height: 80, width: 80, iconSize: 60),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fullName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '$_selectedStorage',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                if (_isLoadingQuestions)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (sequenceQuestions.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: const Text(
                      'No condition questions are configured for this model.',
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: const Text(
                      'Continue to answer selected condition details.',
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          color: Colors.white,
          child: ElevatedButton(
            onPressed: canContinue
                ? () {
                    if (sequenceQuestions.isNotEmpty) {
                      setState(() {
                        _adminImageQuestionIndex = 0;
                        _showAdminImageQuestion = true;
                      });
                    } else {
                      _calculateExactPrice();
                    }
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A78A8),
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade300,
              disabledForegroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Continue',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDefectsScreen() {
    final List<Map<String, dynamic>> defectOptions = [
      {
        'title': 'Broken / Scratch on device screen',
        'image': const Icon(
          Icons.image_outlined,
          size: 34,
          color: Color(0xFF94A3B8),
        ),
      },
      {
        'title': 'Dead Spot / Visible line and discoloration',
        'image': const Icon(
          Icons.image_outlined,
          size: 34,
          color: Color(0xFF94A3B8),
        ),
      },
      {
        'title': 'Scratch / Dent on device body',
        'image': const Icon(
          Icons.image_outlined,
          size: 34,
          color: Color(0xFF94A3B8),
        ),
      },
      {
        'title': 'Device panel missing button',
        'image': const Icon(
          Icons.image_outlined,
          size: 34,
          color: Color(0xFF94A3B8),
        ),
      },
    ];

    return Column(
      key: const ValueKey('defects'),
      children: [
        _buildStepHeader(
          'Select defects',
          () => setState(() => _showDefects = false),
        ),
        const Padding(
          padding: EdgeInsets.all(20.0),
          child: Text(
            'Select screen / body defects that are applicable!',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              mainAxisExtent: 64,
            ),
            itemCount: defectOptions.length,
            itemBuilder: (context, index) {
              final option = defectOptions[index];
              final isSelected = _selectedDefects.contains(option['title']);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedDefects.remove(option['title']);
                    } else {
                      _selectedDefects.add(option['title']);
                    }
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF4A78A8)
                          : Colors.grey.shade200,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Expanded(child: Center(child: option['image'])),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 3,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF4A78A8)
                              : Colors.grey.shade200,
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(5),
                          ),
                        ),
                        child: Text(
                          option['title'],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: ElevatedButton(
            onPressed: () => setState(() => _showScreenCondition = true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A78A8),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Continue',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScreenPhysicalConditionScreen() {
    final List<Map<String, dynamic>> conditionOptions = [
      {
        'title': 'More than 2 Scratches',
        'image': const Icon(
          Icons.image_outlined,
          size: 38,
          color: Color(0xFF94A3B8),
        ),
      },
      {
        'title': '1-2 Scratches',
        'image': const Icon(
          Icons.image_outlined,
          size: 38,
          color: Color(0xFF94A3B8),
        ),
      },
      {
        'title': 'No Scratches',
        'image': const Icon(
          Icons.image_outlined,
          size: 38,
          color: Color(0xFF94A3B8),
        ),
      },
      {
        'title': 'Screen Cracked Glass Broken',
        'image': const Icon(
          Icons.image_outlined,
          size: 38,
          color: Color(0xFF94A3B8),
        ),
      },
    ];

    return Column(
      key: const ValueKey('screenCondition'),
      children: [
        _buildStepHeader(
          'Screen condition',
          () => setState(() => _showScreenCondition = false),
        ),
        const Padding(
          padding: EdgeInsets.all(20.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Screen Physical Condition',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              mainAxisExtent: 72,
            ),
            itemCount: conditionOptions.length,
            itemBuilder: (context, index) {
              final option = conditionOptions[index];
              final isSelected = _selectedPhysicalCondition == option['title'];
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedPhysicalCondition = isSelected
                        ? null
                        : option['title'];
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF4A78A8)
                          : Colors.grey.shade200,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Expanded(child: Center(child: option['image'])),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF4A78A8)
                              : Colors.grey.shade200,
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(8),
                          ),
                        ),
                        child: Text(
                          option['title'],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: ElevatedButton(
            onPressed: () => setState(() => _showDiscoloration = true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A78A8),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Continue',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDiscolorationScreen() {
    final List<Map<String, dynamic>> options = [
      {
        'title': 'Major Discoloration',
        'image': const Icon(
          Icons.image_outlined,
          size: 38,
          color: Color(0xFF94A3B8),
        ),
      },
      {
        'title': 'Minor Discoloration',
        'image': const Icon(
          Icons.image_outlined,
          size: 38,
          color: Color(0xFF94A3B8),
        ),
      },
      {
        'title': 'No Discoloration',
        'image': const Icon(
          Icons.image_outlined,
          size: 38,
          color: Color(0xFF94A3B8),
        ),
      },
    ];

    return Column(
      key: const ValueKey('discolorationScreen'),
      children: [
        _buildStepHeader(
          'Screen Condition',
          () => setState(() => _showDiscoloration = false),
        ),
        const Padding(
          padding: EdgeInsets.all(20.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Discoloration on Screen',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              mainAxisExtent: 72,
            ),
            itemCount: options.length,
            itemBuilder: (context, index) {
              final option = options[index];
              final isSelected = _selectedDiscoloration == option['title'];

              return _buildGridItem(
                option['title'],
                option['image'],
                isSelected,
                () => setState(
                  () => _selectedDiscoloration = isSelected
                      ? null
                      : option['title'],
                ),
              );
            },
          ),
        ),
        _buildContinueButton(() => setState(() => _showDentsCondition = true)),
      ],
    );
  }

  Widget _buildDentsConditionScreen() {
    final List<Map<String, dynamic>> options = [
      {
        'title': 'Major dents or more than 2',
        'image': const Icon(
          Icons.image_outlined,
          size: 38,
          color: Color(0xFF94A3B8),
        ),
      },
      {
        'title': '1-2 minor dents',
        'image': const Icon(
          Icons.image_outlined,
          size: 38,
          color: Color(0xFF94A3B8),
        ),
      },
      {
        'title': 'No Dents',
        'image': const Icon(
          Icons.image_outlined,
          size: 38,
          color: Color(0xFF94A3B8),
        ),
      },
    ];

    return Column(
      key: const ValueKey('dentsCondition'),
      children: [
        _buildStepHeader(
          'Body condition',
          () => setState(() => _showDentsCondition = false),
        ),
        const Padding(
          padding: EdgeInsets.all(20.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Dents on device body',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              mainAxisExtent: 72,
            ),
            itemCount: options.length,
            itemBuilder: (context, index) {
              final option = options[index];
              final isSelected = _selectedDentsCondition == option['title'];

              return _buildGridItem(
                option['title'],
                option['image'],
                isSelected,
                () {
                  setState(() {
                    _selectedDentsCondition = isSelected
                        ? null
                        : option['title'];
                  });
                },
              );
            },
          ),
        ),
        _buildContinueButton(
          () => setState(() => _showBackPanelCondition = true),
        ),
      ],
    );
  }

  Widget _buildBackPanelConditionScreen() {
    final List<Map<String, dynamic>> options = [
      {
        'title': 'Cracked / broken side or back panel',
        'image': const Icon(
          Icons.image_outlined,
          size: 38,
          color: Color(0xFF94A3B8),
        ),
      },
      {
        'title': 'Missing side or back panel',
        'image': const Icon(
          Icons.image_outlined,
          size: 38,
          color: Color(0xFF94A3B8),
        ),
      },
      {
        'title': 'No defect on side or back panel',
        'image': const Icon(
          Icons.image_outlined,
          size: 38,
          color: Color(0xFF94A3B8),
        ),
      },
    ];

    return Column(
      key: const ValueKey('backPanelCondition'),
      children: [
        _buildStepHeader(
          'Back Panel',
          () => setState(() => _showBackPanelCondition = false),
        ),
        const Padding(
          padding: EdgeInsets.all(20.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Device Side / Back Panel Condition',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              mainAxisExtent: 72,
            ),
            itemCount: options.length,
            itemBuilder: (context, index) {
              final option = options[index];
              final isSelected = _selectedBackPanelCondition == option['title'];
              return _buildGridItem(
                option['title'],
                option['image'],
                isSelected,
                () {
                  setState(() {
                    _selectedBackPanelCondition = isSelected
                        ? null
                        : option['title'];
                  });
                },
              );
            },
          ),
        ),
        _buildContinueButton(() => setState(() => _showBentCondition = true)),
      ],
    );
  }

  Widget _buildBentConditionScreen() {
    final List<Map<String, dynamic>> options = [
      {
        'title': 'Bent Curved Panel',
        'image': const Icon(
          Icons.image_outlined,
          size: 38,
          color: Color(0xFF94A3B8),
        ),
      },
      {
        'title': 'Loose screen ( Gap in screen and body )',
        'image': const Icon(
          Icons.image_outlined,
          size: 38,
          color: Color(0xFF94A3B8),
        ),
      },
      {
        'title': 'No defect on side or back panel',
        'image': const Icon(
          Icons.image_outlined,
          size: 38,
          color: Color(0xFF94A3B8),
        ),
      },
    ];

    return Column(
      key: const ValueKey('bentCondition'),
      children: [
        _buildStepHeader(
          'Bent/Loose',
          () => setState(() => _showBentCondition = false),
        ),
        const Padding(
          padding: EdgeInsets.all(20.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Device Bent / Screen Loose',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              mainAxisExtent: 72,
            ),
            itemCount: options.length,
            itemBuilder: (context, index) {
              final option = options[index];
              final isSelected = _selectedBentCondition == option['title'];
              return _buildGridItem(
                option['title'],
                option['image'],
                isSelected,
                () {
                  setState(() {
                    _selectedBentCondition = isSelected
                        ? null
                        : option['title'];
                  });
                },
              );
            },
          ),
        ),
        _buildContinueButton(
          () => setState(() => _showFunctionalCondition = true),
        ),
      ],
    );
  }

  Widget _buildFunctionalProblemsScreen() {
    final List<Map<String, dynamic>> options = [
      {
        'title': 'Front Camera Not Working',
        'image': const Icon(
          Icons.image_outlined,
          size: 38,
          color: Color(0xFF94A3B8),
        ),
      },
      {
        'title': 'Back Camera Not Working',
        'image': const Icon(
          Icons.image_outlined,
          size: 38,
          color: Color(0xFF94A3B8),
        ),
      },
      {
        'title': 'Volume Button not Working',
        'image': const Icon(
          Icons.image_outlined,
          size: 38,
          color: Color(0xFF94A3B8),
        ),
      },
      {
        'title': 'Finger Touch Not Working',
        'image': const Icon(
          Icons.image_outlined,
          size: 38,
          color: Color(0xFF94A3B8),
        ),
      },
      {
        'title': 'Wifi not working',
        'image': const Icon(
          Icons.image_outlined,
          size: 38,
          color: Color(0xFF94A3B8),
        ),
      },
      {
        'title': 'Speaker Faulty',
        'image': const Icon(
          Icons.image_outlined,
          size: 38,
          color: Color(0xFF94A3B8),
        ),
      },
    ];

    return Column(
      key: const ValueKey('functionalCondition'),
      children: [
        _buildStepHeader(
          'Functional Problems',
          () => setState(() => _showFunctionalCondition = false),
        ),
        const Padding(
          padding: EdgeInsets.all(20.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Functional or Physical Problems',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              mainAxisExtent: 72,
            ),
            itemCount: options.length,
            itemBuilder: (context, index) {
              final option = options[index];
              final isSelected = _selectedFunctionalProblems.contains(
                option['title'],
              );
              return _buildGridItem(
                option['title'],
                option['image'],
                isSelected,
                () {
                  setState(() {
                    if (isSelected) {
                      _selectedFunctionalProblems.remove(option['title']);
                    } else {
                      _selectedFunctionalProblems.add(option['title']);
                    }
                  });
                },
              );
            },
          ),
        ),
        _buildContinueButton(
          () => setState(() => _showAccessoriesCondition = true),
        ),
      ],
    );
  }

  Widget _buildAccessoriesScreen() {
    final List<Map<String, dynamic>> options = [
      {
        'title': 'Original Charger of Device',
        'image': const Icon(
          Icons.image_outlined,
          size: 38,
          color: Color(0xFF94A3B8),
        ),
      },
      {
        'title': 'Original Box with same IMEI',
        'image': const Icon(
          Icons.image_outlined,
          size: 38,
          color: Color(0xFF94A3B8),
        ),
      },
    ];

    return Column(
      key: const ValueKey('accessoriesCondition'),
      children: [
        _buildStepHeader(
          'Accessories',
          () => setState(() => _showAccessoriesCondition = false),
        ),
        const Padding(
          padding: EdgeInsets.all(20.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Do you have the following?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              mainAxisExtent: 72,
            ),
            itemCount: options.length,
            itemBuilder: (context, index) {
              final option = options[index];
              final isSelected = _selectedAccessories.contains(option['title']);
              return _buildGridItem(
                option['title'],
                option['image'],
                isSelected,
                () {
                  setState(() {
                    if (isSelected) {
                      _selectedAccessories.remove(option['title']);
                    } else {
                      _selectedAccessories.add(option['title']);
                    }
                  });
                },
              );
            },
          ),
        ),
        _buildContinueButton(_calculateExactPrice),
      ],
    );
  }

  Widget _buildCheckoutScreen() {
    String modelName = _selectedModel ?? "";
    String brandName = _selectedBrand ?? "";
    String fullName = modelName.contains(brandName)
        ? modelName
        : "$brandName $modelName";
    final isLoggedIn = context.watch<AuthViewModel>().loggedInUser != null;
    final checkoutPriceText = _checkoutPriceText(isLoggedIn);

    return Column(
      key: const ValueKey('checkout'),
      children: [
        _buildStepHeader(
          'Checkout',
          () => setState(() => _showCheckout = false),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Summary Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 86,
                            width: 86,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: _buildDeviceImage(
                                fit: BoxFit.contain,
                                iconSize: 50,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  fullName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '( $_selectedStorage )',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Selling price:',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      checkoutPriceText,
                                      style: TextStyle(
                                        color: isLoggedIn
                                            ? const Color(0xFFE11D48)
                                            : const Color(0xFF64748B),
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => _resetState(),
                                      child: const Text(
                                        'Recalculate',
                                        style: TextStyle(
                                          color: Color(0xFF2563EB),
                                          decoration: TextDecoration.underline,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: _buildCheckoutBenefit(
                              'Instant\nPayment',
                              Icons.wallet_giftcard_rounded,
                              const Color(0xFFF59E0B),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildCheckoutBenefit(
                              'Free\nPickup',
                              Icons.local_shipping_outlined,
                              const Color(0xFF3B82F6),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildCheckoutBenefit(
                              'No Hidden\nCharges',
                              Icons.explore_outlined,
                              const Color(0xFFEF4444),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (!isLoggedIn) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.lock_outline_rounded,
                                color: Color(0xFF2563EB),
                                size: 20,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Login to unlock your exact final offer and continue pickup.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF1E40AF),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ] else ...[
                        _buildPayoutMethodSection(),
                        const SizedBox(height: 12),
                      ],
                      ElevatedButton(
                        onPressed: _handleLockedCheckoutAction,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4A78A8),
                          minimumSize: const Size(double.infinity, 52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          isLoggedIn ? 'Sell Now' : 'Login to View Price',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Coupon Container
                GestureDetector(
                  onTap: _appliedCoupon == null
                      ? () => _showCouponSheet()
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: _appliedCoupon != null
                            ? const Color(0xFF10B981)
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.percent_rounded,
                          color: _appliedCoupon != null
                              ? const Color(0xFF10B981)
                              : const Color(0xFF64748B),
                          size: 20,
                        ),
                        const SizedBox(width: 10),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _appliedCoupon != null
                                    ? 'Coupon Applied: $_appliedCoupon'
                                    : 'Apply Coupons',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: _appliedCoupon != null
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFF1E293B),
                                ),
                              ),
                              if (_appliedCoupon != null)
                                Text(
                                  'You got \u20b9$_couponDiscount!',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF10B981),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                        ),

                        //  REMOVE BUTTON
                        if (_appliedCoupon != null)
                          GestureDetector(
                            onTap: _removeCoupon,
                            child: const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Icon(Icons.close, color: Colors.red),
                            ),
                          )
                        else
                          Icon(
                            Icons.chevron_right_rounded,
                            color: const Color(0xFF94A3B8),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Text(
                    'FAQs',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _buildCheckoutFaqSection(),
                const SizedBox(height: 96),
              ],
            ),
          ),
        ),
        // Bottom Price Bar
        Container(
          padding: EdgeInsets.fromLTRB(
            18,
            12,
            18,
            18 + MediaQuery.of(context).padding.bottom,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      checkoutPriceText,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: isLoggedIn
                            ? const Color(0xFF0F172A)
                            : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    GestureDetector(
                      onTap: _handleViewBreakupAction,
                      child: Text(
                        isLoggedIn ? 'View Breakup' : 'Login to unlock',
                        style: const TextStyle(
                          color: Color(0xFFE11D48),
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: _handleLockedCheckoutAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A78A8),
                  minimumSize: const Size(150, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  isLoggedIn ? 'Sell Now' : 'Login',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showCouponSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Apply Coupon',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TextField(
                  controller: _couponController,
                  decoration: InputDecoration(
                    hintText: 'Enter coupon code',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    suffixIcon: TextButton(
                      onPressed: () {
                        String code = _couponController.text
                            .trim()
                            .toUpperCase();

                        //  Empty check
                        if (code.isEmpty) {
                          Navigator.pop(context);

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter coupon code'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }

                        final coupon = _findActiveCoupon(code);

                        if (coupon != null) {
                          final couponName = _couponName(coupon);
                          final couponPrice = _couponPrice(coupon);
                          setState(() {
                            _appliedCoupon = couponName;
                            _couponDiscount = couponPrice;
                          });

                          Navigator.pop(context);

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Coupon $couponName applied'),
                              backgroundColor: const Color(0xFF10B981),
                            ),
                          );
                        } else {
                          Navigator.pop(context);

                          _couponController.clear();
                          FocusScope.of(context).unfocus();

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Invalid coupon code'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      child: const Text(
                        'APPLY',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF4A78A8),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                'Available Offers',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 16),
              if (_apiCoupons.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No active coupons available right now.',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                ..._apiCoupons.expand(
                  (coupon) => [
                    _buildCouponItem(coupon),
                    const SizedBox(height: 12),
                  ],
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCouponItem(Map<String, dynamic> coupon) {
    final code = _couponName(coupon);
    final price = _couponPrice(coupon);

    return GestureDetector(
      onTap: () {
        _couponController.text = code;
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF3B82F6).withOpacity(0.3),
                ),
              ),
              child: Text(
                code,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF3B82F6),
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    code,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'Get extra \u20b9$price',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _removeCoupon() {
    setState(() {
      _appliedCoupon = null;
      _couponDiscount = 0;
      _couponController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Coupon removed'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _handleLockedCheckoutAction() {
    if (context.read<AuthViewModel>().loggedInUser != null) {
      if (!_validatePayoutSelection()) return;
      _showPriceBreakup(context);
      return;
    }

    _showSellLoginSheet();
  }

  void _handleViewBreakupAction() {
    if (context.read<AuthViewModel>().loggedInUser == null) {
      _showSellLoginSheet();
      return;
    }

    _showPriceBreakup(context);
  }

  bool _validatePayoutSelection() {
    if (_selectedPayoutMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a payout method.')),
      );
      return false;
    }

    if (_selectedPayoutMethod == 'bank' && _selectedBankDetail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or add a bank account.')),
      );
      return false;
    }

    if (_selectedPayoutMethod == 'upi' &&
        _upiIdController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your UPI ID.')),
      );
      return false;
    }

    return true;
  }

  Future<void> _handleSellLogin(StateSetter sheetSetState) async {
    final mobile = _sellLoginMobileController.text.trim();
    final password = _sellLoginPasswordController.text.trim();

    if (mobile.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter mobile and password.')),
      );
      return;
    }

    if (mobile.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mobile number must be 10 digits.')),
      );
      return;
    }

    sheetSetState(() => _isSellLoginLoading = true);
    setState(() => _isSellLoginLoading = true);

    final vm = context.read<AuthViewModel>();
    final success = await vm.login(mobile: mobile, password: password);

    if (!mounted) return;

    sheetSetState(() => _isSellLoginLoading = false);
    setState(() => _isSellLoginLoading = false);

    if (!success) {
      final message = vm.errorMessage ?? 'Login failed.';
      if (_looksLikeMissingAccount(message)) {
        Navigator.pop(context);
        _showSellCreateAccountSheet();
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
      return;
    }

    final user = vm.loggedInUser;
    _addressNameController.text = user?.name ?? '';
    _addressMobileController.text = user?.mobile ?? '';
    _sellLoginPasswordController.clear();
    Navigator.pop(context);
    await _loadSellData();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Login successful. Final price unlocked.')),
    );
  }

  void _showSellLoginSheet() {
    bool obscurePassword = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, sheetSetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Login to unlock final price',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _isSellLoginLoading
                              ? null
                              : () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Your selections are saved. Login now to see the exact offer and continue pickup.',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _sellLoginMobileController,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      decoration: InputDecoration(
                        counterText: '',
                        labelText: 'Mobile number',
                        prefixIcon: const Icon(Icons.phone_android_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _sellLoginPasswordController,
                      obscureText: obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          onPressed: () => sheetSetState(
                            () => obscurePassword = !obscurePassword,
                          ),
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton(
                      onPressed: _isSellLoginLoading
                          ? null
                          : () => _handleSellLogin(sheetSetState),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4A78A8),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isSellLoginLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Login & View Price',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: TextButton(
                        onPressed: _isSellLoginLoading
                            ? null
                            : () {
                                Navigator.pop(context);
                                _openSignupFromSell();
                              },
                        child: const Text(
                          'New here? Create Account',
                          style: TextStyle(
                            color: Color(0xFF4A78A8),
                            fontWeight: FontWeight.w900,
                          ),
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

  bool _looksLikeMissingAccount(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('not found') ||
        normalized.contains('not registered') ||
        normalized.contains('no user') ||
        normalized.contains('user does not exist') ||
        normalized.contains('account does not exist') ||
        normalized.contains('id not found') ||
        normalized.contains('user id');
  }

  void _openSignupFromSell() {
    final mobile = _sellLoginMobileController.text.trim();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SignUpScreen(
          initialMobile: mobile,
          returnToPreviousOnSuccess: true,
        ),
      ),
    ).then((created) async {
      if (!mounted) return;

      final user = context.read<AuthViewModel>().loggedInUser;
      if (user != null) {
        _addressNameController.text = user.name;
        _addressMobileController.text = user.mobile;
        _bankAccountNameController.text = user.name;
      }

      await _loadSellData();

      if (!mounted || created != true) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created. Final price unlocked.')),
      );
    });
  }

  void _showSellCreateAccountSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 52,
              width: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.person_add_alt_1_rounded,
                color: Color(0xFF4F46E5),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Create your account',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'No account was found for this mobile number. Create one and your selling progress will stay ready.',
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 22),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _openSignupFromSell();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Create Account',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPriceBreakup(BuildContext context) {
    if (context.read<AuthViewModel>().loggedInUser == null) {
      _showSellLoginSheet();
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final bottomPadding = MediaQuery.of(context).padding.bottom;
        final baseDeviceValue = _enquiryBasePrice > 0
            ? _enquiryBasePrice
            : _calculatedBasePrice;
        final conditionAdjustment = _calculatedBasePrice - baseDeviceValue;

        return Container(
          padding: EdgeInsets.fromLTRB(24, 12, 24, 20 + bottomPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.receipt_long_outlined,
                      color: Color(0xFF4A78A8),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Price Breakup',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          [_selectedModel, _selectedStorage]
                              .whereType<String>()
                              .where((e) => e.isNotEmpty)
                              .join(' • '),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Close',
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _buildBreakupRow(
                'Base Device Value',
                '\u20b9 ${_formatPrice(baseDeviceValue)}',
              ),
              const SizedBox(height: 14),
              _buildBreakupRow(
                'Condition Adjustment',
                conditionAdjustment == 0
                    ? 'No deduction'
                    : '${conditionAdjustment > 0 ? '+' : '-'} \u20b9 ${_formatPrice(conditionAdjustment.abs())}',
                valueColor: conditionAdjustment >= 0
                    ? const Color(0xFF10B981)
                    : const Color(0xFFE11D48),
              ),
              if (_appliedCoupon != null) ...[
                const SizedBox(height: 14),
                _buildBreakupRow(
                  'Coupon Bonus',
                  '+ \u20b9 ${_formatPrice(_couponDiscount)}',
                  valueColor: const Color(0xFF10B981),
                ),
              ],
              const SizedBox(height: 18),
              const Divider(color: Color(0xFFE2E8F0)),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Final Offer',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    '\u20b9 ${_formatPrice(_totalPrice)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '\u20b9 ${_formatPrice(_totalPrice)}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      if (!_validatePayoutSelection()) return;
                      _openAddressSelectionScreen();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A78A8),
                      minimumSize: const Size(160, 54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Continue',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBreakupRow(
    String label,
    String value, {
    String? originalPrice,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.black54,
            fontWeight: FontWeight.w500,
          ),
        ),
        Row(
          children: [
            if (originalPrice != null)
              Text(
                originalPrice,
                style: TextStyle(
                  color: Colors.grey,
                  decoration: TextDecoration.lineThrough,
                  fontSize: 12,
                ),
              ),
            if (originalPrice != null) const SizedBox(width: 8),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: valueColor ?? Colors.black,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCheckoutBenefit(String title, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
            ),
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildFAQTile(String title, String answer) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 4),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
            ),
          ),
          trailing: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xFF94A3B8),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
              child: Text(
                answer,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckoutFaqSection() {
    if (_isLoadingCheckoutFaqs) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFF4A78A8),
          ),
        ),
      );
    }

    if (_checkoutFaqs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: Text(
            _checkoutFaqErrorMessage ?? 'FAQs are not available right now.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    final visibleFaqs = _checkoutFaqs.take(_visibleCheckoutFaqCount).toList();
    final hasMore = _visibleCheckoutFaqCount < _checkoutFaqs.length;

    return Column(
      children: [
        ...visibleFaqs.map((faq) => _buildFAQTile(faq.question, faq.answer)),
        if (hasMore) ...[
          const SizedBox(height: 20),
          Center(
            child: TextButton(
              onPressed: () {
                setState(() {
                  _visibleCheckoutFaqCount = _checkoutFaqs.length;
                });
              },
              child: const Text(
                'Load More FAQs',
                style: TextStyle(
                  color: Color(0xFF4A78A8),
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

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
    final double bottomNavReserve = 0 + MediaQuery.of(context).padding.bottom;
    final double bottomSheetHeight = _savedAddresses.isNotEmpty ? 260 : 220;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Map
          if (_isFetchingLocation || !locationReady)
            Positioned.fill(
              bottom: bottomNavReserve + bottomSheetHeight - 20,
              child: Container(
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
              ),
            )
          else
            Positioned.fill(
              bottom: bottomNavReserve + bottomSheetHeight - 20,
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: LatLng(lat, lng),
                  initialZoom: 16.2,
                  maxZoom: 19,
                  minZoom: 5,
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
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.selorize.app',
                    retinaMode: RetinaMode.isHighDensity(context),
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(lat, lng),
                        width: 58,
                        height: 58,
                        alignment: Alignment.topCenter,
                        child: const Icon(
                          Icons.location_pin,
                          color: Color(0xFF4267B2),
                          size: 46,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // 2. Header
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _handleSystemBack,
                    child: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black12, blurRadius: 8),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 17,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      "Address & Pickup",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(width: 38),
                ],
              ),
            ),
          ),

          // 3. Search Bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 50,
            left: 14,
            right: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 46,
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
                              padding: EdgeInsets.all(13),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF4267B2),
                                ),
                              ),
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
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
                      itemCount: _searchResults.length > 5
                          ? 5
                          : _searchResults.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: Colors.grey.shade100),
                      itemBuilder: (context, i) {
                        final r = _searchResults[i];
                        return ListTile(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          leading: const Icon(
                            Icons.location_on_outlined,
                            color: Color(0xFF4267B2),
                            size: 19,
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
            top: MediaQuery.of(context).padding.top + 108,
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
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
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
            bottom: bottomNavReserve,
            left: 0,
            right: 0,
            child: Container(
              height: bottomSheetHeight,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
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
                  // Handle
                  Center(
                    child: Container(
                      width: 35,
                      height: 3,
                      margin: const EdgeInsets.only(bottom: 4),
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
                      fontSize: 15,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),

                  if (_fetchedAddress.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedPickupAddress = _buildGpsAddress();
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        margin: const EdgeInsets.only(bottom: 4),
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
                              padding: const EdgeInsets.all(7),
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
                            const SizedBox(width: 10),
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
                                          fontSize: 11,
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
                                  const SizedBox(height: 2),
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
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 10,
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

                  if (_savedAddresses.isNotEmpty) ...[
                    const Text(
                      'Saved Addresses',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildModernAddressSelector(),
                    const SizedBox(height: 4),
                  ],

                  // Confirm Button
                  ElevatedButton(
                    onPressed: _isFetchingLocation
                        ? null
                        : _confirmPickupAddress,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4267B2),
                      disabledBackgroundColor: Colors.grey.shade300,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 40),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
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
                              Text(
                                'Fetching Location...',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          )
                        : const Text(
                            "Confirm & Proceed",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          _showAddressSelection = false;
                          _showAddAddress = true;
                        });
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF4267B2),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        minimumSize: Size.zero,
                        fixedSize: const Size.fromHeight(26),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      child: const Text(
                        'Add Address Manually',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
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
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: _handleSystemBack,
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
                      color: Colors.black.withOpacity(0.03),
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
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
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
        color: const Color(0xFF6366F1).withOpacity(0.1),
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
      await _reverseGeocode(position.latitude, position.longitude);
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isEmpty) {
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
      final state = place.administrativeArea ?? '';
      final pincode = place.postalCode ?? '';
      final placemarkArea =
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
      final area = _fetchedAddress.trim().isNotEmpty
          ? _fetchedAddress.trim()
          : placemarkArea;

      if (!mounted) return;
      setState(() {
        _addressCityController.text = city;
        _addressStateController.text = state;
        _addressPincodeController.text = pincode;
        if (_addressStreetController.text.trim().isEmpty && area.isNotEmpty) {
          _addressStreetController.text = area;
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

  Widget _buildPickupSlotOption(String slot) {
    final isSelected = _selectedPickupSlot == slot;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedPickupSlot = slot),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF4267B2) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF4267B2)
                  : const Color(0xFFE2E8F0),
            ),
          ),
          child: Text(
            slot,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF1E293B),
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

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
          onPressed: _handleSystemBack,
        ),
        title: const Text(
          "Pickup Scheduling",
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
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
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
                                          color: Colors.black.withOpacity(0.05),
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
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ]
                                    : [],
                              ),
                              child: Text(
                                "Instant",
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
                  const SizedBox(height: 18),

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
                  const SizedBox(height: 10),

                  // DATE SELECTION LOGIC
                  if (!isInstantPickup)
                    Container(
                      padding: const EdgeInsets.all(14),
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
                          const SizedBox(width: 12),
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
                            onPressed: _pickPickupDate,
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
                      padding: const EdgeInsets.all(14),
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
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              "Instant Pickup: Our agent will arrive within 3 hours.",
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

                  if (!isInstantPickup) ...[
                    const SizedBox(height: 14),
                    const Text(
                      "Select Pickup Slot",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildPickupSlotOption('10 AM - 3 PM'),
                        const SizedBox(width: 10),
                        _buildPickupSlotOption('3 PM - 8 PM'),
                      ],
                    ),
                  ],

                  const SizedBox(height: 16),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
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
                        const SizedBox(height: 10),
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
                              _pickupArrivalLabel(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
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
                            const Text(
                              "FREE",
                              style: TextStyle(
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

          Container(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () => setState(() => _showFinalReview = true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4267B2),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 54),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                "Confirm",
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

  Widget _buildGridItem(
    String title,
    Widget iconWidget,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF4A78A8) : Colors.grey.shade200,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Transform.scale(scale: 0.8, child: iconWidget),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF4A78A8)
                    : Colors.grey.shade200,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(5),
                ),
              ),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContinueButton(VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: ElevatedButton(
        onPressed: _isCalculatingPrice ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4A78A8),
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 60),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isCalculatingPrice
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Continue',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  Widget _buildAdminImageQuestionScreen() {
    final questions = _adminImageQuestions;
    if (questions.isEmpty) {
      return const SizedBox.shrink();
    }
    final safeQuestionIndex = _adminImageQuestionIndex.clamp(
      0,
      questions.length - 1,
    );
    final question = questions[safeQuestionIndex];

    final questionId = _questionId(question);
    final isCheckbox = _questionType(question) == 'Checkbox';
    final selectedOptionId = _selectedAdminQuestionOptions[questionId];
    final selectedSet = _selectedCheckboxQuestionOptions[questionId] ?? {};
    final options = _questionOptions(question);
    final hasOptionImages = options.any(
      (option) => _optionImageUrl(option) != null,
    );
    return Column(
      key: ValueKey('adminImageQuestion_$questionId'),
      children: [
        _buildStepHeader(_questionTitle(question), () => _handleSystemBack()),
        const SizedBox(height: 14),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: hasOptionImages ? 3 : 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 10,
              mainAxisExtent: hasOptionImages ? 170 : 54,
            ),
            itemCount: options.length,
            itemBuilder: (context, index) {
              final option = options[index];
              final optionId = _optionId(option);
              final isSelected = isCheckbox
                  ? selectedSet.contains(optionId)
                  : selectedOptionId == optionId;

              void onTap() {
                setState(() {
                  if (isCheckbox) {
                    final current = Set<String>.from(
                      _selectedCheckboxQuestionOptions[questionId] ?? {},
                    );
                    if (isSelected) {
                      current.remove(optionId);
                    } else {
                      current.add(optionId);
                    }
                    _selectedCheckboxQuestionOptions[questionId] = current;
                  } else {
                    if (isSelected) {
                      _selectedAdminQuestionOptions.remove(questionId);
                    } else {
                      _selectedAdminQuestionOptions[questionId] = optionId;
                    }
                  }
                });
              }

              return hasOptionImages
                  ? _buildAdminImageOptionCard(option, isSelected, onTap)
                  : _buildAdminTextOptionCard(option, isSelected, onTap);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: ElevatedButton(
            onPressed: () {
              if (_adminImageQuestionIndex < questions.length - 1) {
                setState(() => _adminImageQuestionIndex++);
              } else {
                _calculateExactPrice();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A78A8),
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade300,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              _adminImageQuestionIndex < questions.length - 1
                  ? 'Continue'
                  : 'Continue',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdminTextOptionCard(
    Map<String, dynamic> option,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE8F1FB) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF4A78A8)
                : const Color(0xFFD7E0EA),
            width: isSelected ? 2 : 1.2,
          ),
        ),
        child: Text(
          _optionLabel(option),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isSelected
                ? const Color(0xFF315F91)
                : const Color(0xFF334155),
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildAdminImageOptionCard(
    Map<String, dynamic> option,
    bool isSelected,
    VoidCallback onTap,
  ) {
    final imageUrl = _optionImageUrl(option);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF4A78A8) : Colors.grey.shade200,
            width: isSelected ? 2.2 : 1.5,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: imageUrl == null
                    ? const Icon(
                        Icons.image_outlined,
                        size: 48,
                        color: Color(0xFF94A3B8),
                      )
                    : SizedBox(
                        width: 76,
                        height: 86,
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (_, error, ___) {
                            debugPrint(
                              'Option image load failed => $imageUrl | $error',
                            );
                            return const Icon(
                              Icons.image_not_supported_outlined,
                              size: 34,
                              color: Color(0xFF94A3B8),
                            );
                          },
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(5, 4, 5, 10),
              child: Text(
                _optionLabel(option),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? const Color(0xFF315F91)
                      : const Color(0xFF1E293B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminQuestionCard(Map<String, dynamic> question) {
    final questionId = _questionId(question);
    final type = _questionType(question);
    final options = _questionOptions(question);
    final isCheckbox = type == 'Checkbox';
    final hasTwoOptions = options.length == 2;

    final selectedSet = _selectedCheckboxQuestionOptions[questionId] ?? {};
    final selectedOptionId = _selectedAdminQuestionOptions[questionId];

    Widget optionChip(Map<String, dynamic> option, {bool expanded = false}) {
      final optionId = _optionId(option);
      final optionLabel = _optionLabel(option);
      final isSelected = isCheckbox
          ? selectedSet.contains(optionId)
          : selectedOptionId == optionId;

      final chip = GestureDetector(
        onTap: () {
          setState(() {
            if (isCheckbox) {
              final current = Set<String>.from(
                _selectedCheckboxQuestionOptions[questionId] ?? {},
              );
              if (isSelected) {
                current.remove(optionId);
              } else {
                current.add(optionId);
              }
              _selectedCheckboxQuestionOptions[questionId] = current;
            } else {
              if (isSelected) {
                _selectedAdminQuestionOptions.remove(questionId);
              } else {
                _selectedAdminQuestionOptions[questionId] = optionId;
              }
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: expanded
              ? const BoxConstraints(minHeight: 34)
              : BoxConstraints(minWidth: hasTwoOptions ? 112 : 88),
          padding: EdgeInsets.symmetric(
            horizontal: expanded ? 8 : (hasTwoOptions ? 14 : 10),
            vertical: expanded ? 9 : (hasTwoOptions ? 10 : 7),
          ),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF4A78A8) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF4A78A8)
                  : Colors.grey.shade300,
            ),
          ),
          child: Text(
            optionLabel,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      );

      return expanded ? Expanded(child: chip) : chip;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _questionTitle(question),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          if (hasTwoOptions)
            Row(
              children: [
                optionChip(options[0], expanded: true),
                const SizedBox(width: 10),
                optionChip(options[1], expanded: true),
              ],
            )
          else
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: options.map(optionChip).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(
    String question,
    bool? currentValue,
    Function(bool?) onChanged, {
    String? description,
  }) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          if (description != null) ...[
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(currentValue == true ? null : true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: currentValue == true
                          ? const Color(0xFF4A78A8)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: currentValue == true
                            ? Colors.transparent
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'Yes',
                        style: TextStyle(
                          color: currentValue == true
                              ? Colors.white
                              : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(currentValue == false ? null : false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: currentValue == false
                          ? const Color(0xFF4A78A8)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: currentValue == false
                            ? Colors.transparent
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'No',
                        style: TextStyle(
                          color: currentValue == false
                              ? Colors.white
                              : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallBenefit(String title, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.orange.shade800, size: 28),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionButton(
    String label,
    bool isSelected,
    Function(String) onSelect,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: () => onSelect(label),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF4A78A8) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.transparent : Colors.grey.shade300,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepHeader(String title, VoidCallback _) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: _handleSystemBack,
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
          ],
        ),
        child: TextField(
          controller: _brandSearchController,
          onChanged: (val) {
            setState(() => _brandSearchQuery = val);
          },
          decoration: InputDecoration(
            hintText: 'Search brand or model (e.g. Samsung Galaxy S22)...',
            border: InputBorder.none,
            icon: const Icon(Icons.search),
            suffixIcon: _brandSearchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                    onPressed: () {
                      _brandSearchController.clear();
                      setState(() => _brandSearchQuery = '');
                    },
                  )
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildBrandItem(String assetPath, String name, {String? imageUrl}) {
    bool isSelected = _selectedBrand == name;
    final fallback = Center(
      child: Text(
        _brandInitials(name),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFF334155),
          fontSize: 14,
          fontWeight: FontWeight.w900,
        ),
      ),
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isSelected ? Colors.white : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? const Color(0xFF4A78A8) : const Color(0xFFE2E8F0),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: const Color(0xFF4A78A8).withOpacity(0.15),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ]
            : [],
      ),
      child: Container(
        padding: const EdgeInsets.all(10),
        child: Center(
          child: imageUrl == null
              ? fallback
              : _buildNetworkMedia(
                  url: imageUrl,
                  placeholder: _buildBrandImageSkeleton(),
                  errorPlaceholder: fallback,
                  fit: BoxFit.contain,
                ),
        ),
      ),
    );
  }

  Widget _buildBrandImageSkeleton() {
    return Center(
      child: Container(
        height: 26,
        width: 58,
        decoration: BoxDecoration(
          color: const Color(0xFFE8EEF5),
          borderRadius: BorderRadius.circular(8),
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

  Widget _buildSectionTitle(String title) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24),
    child: Text(
      title,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
    ),
  );

  Widget _buildTrendingCard(String name) => GestureDetector(
    onTap: () => _selectModel(name),
    child: Container(
      width: 140,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildModelThumbnail(name, size: 80),
          const SizedBox(height: 12),
          Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );

  Widget _buildModelTile(String name) => GestureDetector(
    onTap: () => _selectModel(name),
    child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          SizedBox(
            height: 42,
            width: 42,
            child: _buildModelThumbnail(name, size: 38),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
        ],
      ),
    ),
  );

  Widget _buildModelGridItem(String name) => GestureDetector(
    onTap: () => _selectModel(name),
    child: SizedBox(
      height: 110,
      child: Container(
        padding: const EdgeInsets.fromLTRB(3, 6, 3, 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            SizedBox(
              height: 52,
              width: double.infinity,
              child: Center(child: _buildModelThumbnail(name, size: 50)),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 38,
              child: Center(
                child: Text(
                  name,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E293B),
                    height: 1.1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildFinalReviewScreen() {
    String fullName = "${_selectedBrand ?? ''} ${_selectedModel ?? ''}";
    final priceScoreBase = _enquiryBasePrice > 0
        ? _enquiryBasePrice
        : (_calculatedBasePrice > 0 ? _calculatedBasePrice : _totalPrice);
    final valuePercentage = priceScoreBase > 0
        ? (_totalPrice / priceScoreBase).clamp(0.08, 1.0).toDouble()
        : 0.08;
    final valueScoreLabel = valuePercentage >= 0.85
        ? 'Excellent Deal!'
        : valuePercentage >= 0.65
        ? 'Good Value'
        : valuePercentage >= 0.45
        ? 'Fair Price'
        : 'Low Value';
    final valueScoreColor = valuePercentage >= 0.85
        ? Colors.green
        : valuePercentage >= 0.65
        ? const Color(0xFF4267B2)
        : valuePercentage >= 0.45
        ? Colors.orange
        : Colors.redAccent;

    return Column(
      children: [
        _buildStepHeader(
          "Final Review",
          () => setState(() => _showFinalReview = false),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: [
                // DEVICE SUMMARY CARD
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Order Summary",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _row("Device Model", fullName),
                      _row("Specs", "$_selectedStorage"),
                      _row(
                        "Condition",
                        _selectedPhysicalCondition ?? "Standard",
                      ),
                      _row(
                        "Pickup Mode",
                        isInstantPickup ? "Instant" : "Scheduled",
                      ),
                      _row("Pickup Time", _pickupReviewLabel()),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Divider(height: 1, thickness: 1),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Net Payable Amount",
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            Text(
                              "\u20b9 ${_totalPrice.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => "${m[1]},")}",
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 20,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // DEVICE VALUE SCORE CARD
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Device Value Score",
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Stack(
                        children: [
                          Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(seconds: 1),
                            height: 8,
                            width:
                                MediaQuery.of(context).size.width *
                                0.75 *
                                valuePercentage,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFF87171),
                                  Color(0xFFFB923C),
                                  Color(0xFF4ADE80),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Fair Price",
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          Text(
                            valueScoreLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: valueScoreColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Divider(),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildMiniBadge(
                            Icons.verified_user,
                            "Safe",
                            Colors.blue,
                          ),
                          _buildMiniBadge(
                            Icons.flash_on,
                            "Instant",
                            Colors.orange,
                          ),
                          _buildMiniBadge(
                            Icons.shield,
                            "Assured",
                            Colors.green,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),

        // FIXED BOTTOM BUTTONS
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: ElevatedButton(
            onPressed: _isSavingEnquiry ? null : _saveEnquiryAndFinish,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E293B),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 58),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              elevation: 6,
              shadowColor: const Color(0xFF1E293B).withOpacity(0.3),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isSavingEnquiry) ...[
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Text(
                  _isSavingEnquiry
                      ? "Saving Enquiry..."
                      : "Confirm & Schedule Pickup",
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (!_isSavingEnquiry) ...[
                  const SizedBox(width: 10),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                ],
              ],
            ),
          ),
        ),
        TextButton(
          onPressed: () => setState(() => _showFinalReview = false),
          child: const Text(
            "Edit Order Details",
            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildMiniBadge(IconData icon, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _row(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildSuccessScreen() {
    return Stack(
      children: [
        Column(
          children: [
            _buildStepHeader("Order Placed", () {
              setState(() {
                _showSuccess = false;
              });
            }),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    // Logo Success
                    SizedBox(
                      height: 200,
                      child: Center(
                        child: Lottie.asset(
                          'assets/confirm_order.json',
                          width: 170,
                          height: 170,
                          fit: BoxFit.contain,
                          repeat: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Order Confirmed!",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Order ID: ${finalOrderID}",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Order place confirmed",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Track Order
                    ElevatedButton(
                      onPressed: () {
                        _resetState();
                        widget.onNavigateToListings?.call();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4A78A8),
                        minimumSize: const Size(double.infinity, 60),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        "Track Order",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () => setState(() => _showCancelScreen = true),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 60),
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        "Cancel Pickup",
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: Lottie.asset(
              'assets/effects.json',
              fit: BoxFit.cover,
              repeat: true,
            ),
          ),
        ),
      ],
    );
  }

  String? _selectedCancelReason;
  final TextEditingController _feedbackController = TextEditingController();

  Widget _buildCancelSuccessScreen() {
    return Container(
      key: const ValueKey('cancelSuccess'),
      color: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    Container(
                      width: 110,
                      height: 110,
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
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Icon(
                            Icons.cancel_rounded,
                            color: Colors.red.shade500,
                            size: 52,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      "Order Cancelled",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1E293B),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Your listing has been cancelled successfully.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.blueGrey.shade400,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Order ID
                    Container(
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
                          Text(
                            "Order ID: ${finalOrderID}",
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

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
                        border: Border.all(
                          color: Colors.red.shade100,
                          width: 1.5,
                        ),
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
                                  color: Colors.red.shade100.withOpacity(0.5),
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
                    const SizedBox(height: 28),

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
                              "You can relist your device anytime. Your cancelled order will appear in the Cancelled tab of your Listings.",
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
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 36),
              child: Column(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      _resetState();
                      widget.onReset?.call();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E293B),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 60),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      "Back to Home",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton(
                    onPressed: () {
                      _resetState();
                      widget.onNavigateToCancelledListings?.call();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF4A78A8),
                      side: const BorderSide(
                        color: Color(0xFF4A78A8),
                        width: 1.5,
                      ),
                      minimumSize: const Size(double.infinity, 60),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text(
                      "View Cancelled Listings",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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
          _buildStepHeader(
            "Cancel Pickup",
            () => setState(() => _showCancelScreen = false),
          ),
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

                  // Reason Selection Chips
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
                                      ).withOpacity(0.3),
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
                  const SizedBox(height: 12),
                  const SizedBox(height: 40),

                  // --- Action Button ---
                  ElevatedButton(
                    onPressed:
                        _selectedCancelReason == null ||
                            (_selectedCancelReason == 'Other' &&
                                _otherCancelReasonController.text
                                    .trim()
                                    .isEmpty)
                        ? null
                        : () {
                            if (DateTime.now().hour >= 14) {
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
                      onPressed: () =>
                          setState(() => _showCancelScreen = false),
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
    bool isCancelling = false;

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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
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
                    child: Icon(
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

                // Stylish Data Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC), // Ultra light grey/blue
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      _dialogRow("Order ID", "#$finalOrderID"),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                      ),
                      _dialogRow(
                        "Estimated Price",
                        "\u20b9 ${_formatPrice(_enquiryBasePrice)}",
                        valueColor: Colors.green.shade600,
                      ),
                      const SizedBox(height: 8),
                      _dialogRow(
                        "Final Offer Price",
                        "\u20b9 ${_totalPrice.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => "${m[1]},")}",
                        isBold: true,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A78A8),
                    minimumSize: const Size(double.infinity, 58),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
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

                StatefulBuilder(
                  builder: (ctx2, setBtn) {
                    return TextButton(
                      onPressed: isCancelling
                          ? null
                          : () async {
                              setBtn(() => isCancelling = true);
                              final reason = _selectedCancelReason == 'Other'
                                  ? _otherCancelReasonController.text.trim()
                                  : _selectedCancelReason!;
                              try {
                                await _repo.cancelEnquiry(
                                  id: finalOrderID,
                                  cancelReason: reason,
                                );
                              } catch (e) {
                                debugPrint('cancelEnquiry sell error: $e');
                              }
                              if (!mounted) return;
                              Navigator.pop(context);
                              widget.onCancelListing?.call(
                                finalOrderID,
                                reason,
                              );
                              setState(() {
                                _confirmedCancelReason = reason;
                                _showCancelScreen = false;
                                _showSuccess = false;
                                _showCancelSuccess = true;
                                _selectedCancelReason = null;
                                _otherCancelReasonController.clear();
                              });
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
                              "Yes, Cancel Order",
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
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
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.blueGrey.shade600,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
            color: valueColor ?? const Color(0xFF1E293B),
          ),
        ),
      ],
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
                  "12:00PM",
                  style: TextStyle(
                    color: Color(0xFF4A78A8),
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 32),
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
              const SizedBox(height: 6),
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
                subtitle: "Fastest response (ID: ${finalOrderID})",
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
              backgroundColor: color.withOpacity(0.1),
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

  Widget _buildModernBadge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}
