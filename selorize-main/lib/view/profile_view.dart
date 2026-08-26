import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:skeletonizer/skeletonizer.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:selorize/model/response/faq_response.dart';
import 'package:selorize/model/user_model.dart';
import 'package:selorize/repository/auth_repository.dart';
import 'package:selorize/res/api_constants.dart';
import 'package:selorize/view_model/auth_viewmodel.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import './login_view.dart';

enum ProfileView {
  main,
  edit,
  addresses,
  addAddress,
  editAddress,
  bank,
  support,
  ordersTracking,
  myTickets,
  raiseTicket,
  terms,
  paymentRefunds,
  sellDeviceIssues,
  accountProfile,
  privacyPolicy,
  returnRefundPolicy,
  aboutUs,
}

class ProfileScreen extends StatefulWidget {
  final VoidCallback? onNavigateToSell;
  final int resetSignal;
  const ProfileScreen({super.key, this.onNavigateToSell, this.resetSignal = 0});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _InAppPolicyWebView extends StatefulWidget {
  final String url;

  const _InAppPolicyWebView({required this.url});

  @override
  State<_InAppPolicyWebView> createState() => _InAppPolicyWebViewState();
}

class _InAppPolicyWebViewState extends State<_InAppPolicyWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;

  Future<void> _compactPolicyPage() async {
    await _controller.runJavaScript('''
      (function () {
        var style = document.getElementById('selorize-app-policy-style');
        if (!style) {
          style = document.createElement('style');
          style.id = 'selorize-app-policy-style';
          document.head.appendChild(style);
        }
        style.innerHTML = `
          html, body {
            margin: 0 !important;
            padding: 0 !important;
            background: #ffffff !important;
            overflow-y: auto !important;
          }
          .container {
            width: auto !important;
            max-width: none !important;
            margin: 0 !important;
            padding: 22px 24px 32px !important;
            border-radius: 0 !important;
            box-shadow: none !important;
          }
          h1 {
            margin-top: 0 !important;
          }
        `;
        window.scrollTo(0, 0);
      })();
    ''');
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _hasError = false;
              });
            }
          },
          onPageFinished: (_) {
            _compactPolicyPage();
            if (mounted) {
              setState(() => _isLoading = false);
            }
          },
          onWebResourceError: (_) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _hasError = true;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_isLoading)
          const LinearProgressIndicator(
            minHeight: 3,
            color: Color(0xFF4F7FB4),
            backgroundColor: Color(0xFFE2E8F0),
          ),
        if (_hasError)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.wifi_off_rounded,
                  color: Color(0xFF94A3B8),
                  size: 42,
                ),
                const SizedBox(height: 14),
                const Text(
                  'Unable to load this page right now.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Please check your internet connection and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _hasError = false;
                    });
                    _controller.loadRequest(Uri.parse(widget.url));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F7FB4),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Retry',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthRepository _repo = AuthRepository();
  ProfileView _currentView = ProfileView.main;
  final ScrollController _scrollController = ScrollController();
  final _formKey = GlobalKey<FormState>();
  final _addressFormKey = GlobalKey<FormState>();
  final _bankFormKey = GlobalKey<FormState>();
  final _ticketFormKey = GlobalKey<FormState>();

  // Personal Info Controllers
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _aadharController;
  String _selectedGender = 'Male';
  bool _isAadharUploaded = false;
  String? _aadharImageBase64;
  String? _aadharImageName;
  String? _profileImageBase64;
  bool _isSavingProfileImage = false;
  final ImagePicker _imagePicker = ImagePicker();
  String? _lastSyncedUserKey;

  // Address Controllers
  final TextEditingController _addrNameController = TextEditingController();
  final TextEditingController _addrPhoneController = TextEditingController();
  final TextEditingController _addrPincodeController = TextEditingController();
  final TextEditingController _addrStateController = TextEditingController();
  final TextEditingController _addrCityController = TextEditingController();
  final TextEditingController _addrHouseController = TextEditingController();
  final TextEditingController _addrAreaController = TextEditingController();
  String _selectedAddressType = 'Home';
  bool _isDefaultAddress = false;
  bool _isDetectingLocation = false;
  int? _editingAddressIndex;

  // Bank Detail Controllers
  late TextEditingController _accHolderController;
  late TextEditingController _bankNameController;
  late TextEditingController _accNumberController;
  late TextEditingController _ifscController;
  // Bank Detail Controllers ke paas yeh add karo
  String? _editingBankId;
  bool _showBankForm = false;

  // Ticket Controllers
  final TextEditingController _ticketSubjectController =
      TextEditingController();
  final TextEditingController _ticketDescController = TextEditingController();
  final TextEditingController _supportSearchController =
      TextEditingController();
  String _selectedTicketCategory = 'Order Issue';
  String _supportSearchQuery = '';

  // Mock Data
  final List<Map<String, dynamic>> _addresses = [];
  final List<Map<String, dynamic>> _bankAccounts = [];
  bool _isLoadingAddresses = false;
  bool _isLoadingBankDetails = false;
  bool _isLoadingTicket = false;
  bool _isLoadingMyTickets = false;
  bool _isLoadingFaqs = false;
  String? _faqErrorMessage;
  
  List<Map<String, dynamic>> _apiStates = [];
  List<Map<String, dynamic>> _apiCities = [];

  List<String> get _statesList => _apiStates.map((s) => s['name']?.toString() ?? '').toList();
  List<String> get _citiesList => _apiCities.map((c) => c['locationName']?.toString() ?? '').toList();
  bool _isLoadingCities = false;

  final List<Map<String, dynamic>> _myTickets = [];
  List<FaqItem> _faqs = [];

  @override
  void initState() {
    super.initState();

    // ’’ Pull real user data from AuthViewModel ’’’’’’’’’’’’’’’’’’’’’’’’’’’’’’’’
    final user = context.read<AuthViewModel>().loggedInUser;

    _nameController = TextEditingController(text: user?.name ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _phoneController = TextEditingController(text: user?.mobile ?? '');
    _aadharController = TextEditingController(text: user?.aadharCard ?? '');

    // Bank controllers
    _accHolderController = TextEditingController(text: user?.name ?? '');
    _bankNameController = TextEditingController(text: '');
    _accNumberController = TextEditingController(text: '');
    _ifscController = TextEditingController(text: '');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSavedAddresses();
      _loadBankDetails();
      _loadMyTickets();
      _loadFaqs();
      _fetchStates();
    });
  }

  Future<void> _fetchStates() async {
    setState(() => _isLoadingCities = true);
    try {
      final responseData = await _repo.getData(tableName: 'operationalState', filter: {});
      if (mounted) {
        setState(() {
          _apiStates = responseData;
        });
      }
      
      if (_addrStateController.text.isNotEmpty) {
        await _fetchCitiesForState(_addrStateController.text);
      }
    } catch (e) {
      debugPrint("Error fetching states: $e");
    } finally {
      if (mounted) setState(() => _isLoadingCities = false);
    }
  }

  Future<void> _fetchCitiesForState(String stateName) async {
    setState(() => _isLoadingCities = true);
    try {
      final state = _apiStates.firstWhere(
        (s) => (s['name']?.toString() ?? '') == stateName,
        orElse: () => <String, dynamic>{},
      );
      if (state.isEmpty) return;
      
      final stateId = state['id'];
      final responseData = await _repo.getData(tableName: 'locations', filter: {'stateId': stateId});
      
      if (mounted) {
        setState(() {
          _apiCities = responseData;
          if (!_citiesList.contains(_addrCityController.text)) {
            _addrCityController.clear();
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching cities: $e");
    } finally {
      if (mounted) setState(() => _isLoadingCities = false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = context.watch<AuthViewModel>().loggedInUser;
    _syncUserFields(user);
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resetSignal == widget.resetSignal) return;

    setState(() => _currentView = ProfileView.main);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
  }

  void _syncUserFields(UserModel? user) {
    if (user == null) return;

    final userKey =
        '${user.id}|${user.name}|${user.email}|${user.mobile}|${user.profileImage}';
    if (_lastSyncedUserKey == userKey) return;

    _lastSyncedUserKey = userKey;
    _nameController.text = user.name;
    _emailController.text = user.email;
    _phoneController.text = user.mobile;
    _accHolderController.text = user.name;
    _aadharController.text = user.aadharCard;
    _profileImageBase64 = user.profileImage.isNotEmpty
        ? _resolveProfileImageUrl(user.profileImage)
        : null;
    if (user.gender.isNotEmpty) {
      final normalizedGender = user.gender.toLowerCase();
      _selectedGender = normalizedGender == 'female' ? 'Female' : 'Male';
    }
    if (user.aadharCardImage.isNotEmpty) {
      _isAadharUploaded = true;
      _aadharImageName = 'Saved Aadhaar image';
    }

    if (_addresses.isNotEmpty) {
      _addresses[0]['name'] = user.name;
      _addresses[0]['phone'] = user.mobile;
    }
  }

  Future<void> _loadSavedAddresses() async {
    final userId = context.read<AuthViewModel>().loggedInUser?.id ?? '';
    if (userId.isEmpty) return;

    setState(() => _isLoadingAddresses = true);

    try {
      final rows = await _repo.getData(
        tableName: 'address',
        filter: {'userId': userId},
      );

      if (!mounted) return;

      setState(() {
        _addresses
          ..clear()
          ..addAll(rows.map(_addressFromApi));
      });
    } catch (e) {
      debugPrint('Load addresses error: $e');
    } finally {
      if (mounted) setState(() => _isLoadingAddresses = false);
    }
  }

  Map<String, dynamic> _addressFromApi(Map<String, dynamic> row) {
    final houseNo = row['houseNo']?.toString() ?? '';
    final street = row['street']?.toString() ?? '';
    final city = row['city']?.toString() ?? '';
    final state = row['state']?.toString() ?? '';
    final pincode = row['pincode']?.toString() ?? '';
    final addressParts = [
      houseNo,
      street,
      city,
      state,
    ].where((part) => part.trim().isNotEmpty).toList();
    final address = [
      addressParts.join(', '),
      if (pincode.isNotEmpty) pincode,
    ].where((part) => part.trim().isNotEmpty).join(' - ');

    return {
      'id': row['id']?.toString() ?? '',
      'name': row['name']?.toString() ?? '',
      'phone': row['mobile']?.toString() ?? '',
      'type': row['addressType']?.toString() ?? 'Home',
      'address': address,
      'isDefault': false,
      'pincode': pincode,
      'state': state,
      'city': city,
      'house': houseNo,
      'area': street,
    };
  }

  Map<String, dynamic> _bankFromApi(Map<String, dynamic> row) {
    return {
      'id': row['id']?.toString() ?? '',
      'accountName': row['accountName']?.toString() ?? '',
      'bankName': row['bankName']?.toString() ?? '',
      'accountNo': row['accountNo']?.toString() ?? '',
      'ifscCode': row['ifscCode']?.toString() ?? '',
    };
  }

  Future<void> _loadBankDetails() async {
    final userId = context.read<AuthViewModel>().loggedInUser?.id ?? '';
    if (userId.isEmpty) return;

    setState(() => _isLoadingBankDetails = true);

    try {
      final rows = await _repo.getData(
        tableName: 'bankDetail',
        filter: {'userId': userId},
      );

      if (!mounted) return;

      setState(() {
        _bankAccounts
          ..clear()
          ..addAll(rows.map(_bankFromApi));
      });
    } catch (e) {
      debugPrint('Load bank details error: $e');
    } finally {
      if (mounted) setState(() => _isLoadingBankDetails = false);
    }
  }

  Map<String, dynamic> _ticketStatusInfo(dynamic rawStatus) {
    final s = rawStatus?.toString().trim() ?? '0';
    switch (s) {
      case '1':
        return {'label': 'In Progress', 'color': const Color(0xFF3B82F6)};
      case '2':
        return {'label': 'Resolved', 'color': const Color(0xFF10B981)};
      case '0':
      default:
        return {'label': 'Pending', 'color': const Color(0xFFF59E0B)};
    }
  }

  Future<void> _loadMyTickets() async {
    final userId = context.read<AuthViewModel>().loggedInUser?.id ?? '';
    if (userId.isEmpty) return;

    setState(() => _isLoadingMyTickets = true);

    try {
      final rows = await _repo.getData(
        tableName: 'tickets',
        filter: {'userId': userId},
      );

      if (!mounted) return;

      final fetched = rows.map((row) {
        final statusInfo = _ticketStatusInfo(row['status']);
        String rawDate =
            row['createdAt']?.toString() ??
            row['created_at']?.toString() ??
            row['date']?.toString() ??
            '';
        String formattedDate = rawDate;
        if (rawDate.isNotEmpty) {
          try {
            final dt = DateTime.tryParse(rawDate);
            if (dt != null) {
              formattedDate = DateFormat('dd / MMMM / yyyy hh:mm a').format(dt);
            }
          } catch (_) {}
        }

        return {
          'id': row['id']?.toString() ?? '',
          'title': row['subject']?.toString() ?? '',
          'issue': row['issue']?.toString() ?? '',
          'detail': row['detail']?.toString() ?? '',
          'date': formattedDate,
          'status': statusInfo['label'],
          'statusColor': statusInfo['color'],
        };
      }).toList();

      setState(() {
        _myTickets
          ..clear()
          ..addAll(fetched);
      });
    } catch (e) {
      debugPrint('Load tickets error: $e');
    } finally {
      if (mounted) setState(() => _isLoadingMyTickets = false);
    }
  }

  Future<void> _loadFaqs() async {
    setState(() {
      _isLoadingFaqs = true;
      _faqErrorMessage = null;
    });

    try {
      final faqs = await _repo.getFaq();
      if (!mounted) return;

      setState(() {
        _faqs = faqs;
        if (_faqs.isEmpty) {
          _faqErrorMessage = 'FAQs are not available right now.';
        }
      });
    } catch (e) {
      debugPrint('Load FAQ error: $e');
      if (mounted) {
        setState(() {
          _faqErrorMessage =
              'Could not load FAQs. Please check your network and try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingFaqs = false);
    }
  }

  List<Map<String, String>> _faqsForType(String type) {
    final normalizedType = _normalizeFaqText(type);
    return _faqs
        .where((faq) {
          final faqType = _normalizeFaqText(faq.category);
          return faqType == normalizedType;
        })
        .map((faq) {
          return {'q': faq.question, 'a': faq.answer};
        })
        .toList();
  }

  List<FaqItem> _supportSearchResults() {
    final query = _normalizeFaqText(_supportSearchQuery);
    if (query.isEmpty) return <FaqItem>[];

    return _faqs.where((faq) {
      final searchable = _normalizeFaqText(
        '${faq.question} ${faq.answer} ${faq.category}',
      );
      return searchable.contains(query);
    }).toList();
  }

  String _normalizeFaqText(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

  bool get _isLoggedIn => context.read<AuthViewModel>().loggedInUser != null;

  bool _isProtectedView(ProfileView view) {
    return view == ProfileView.edit ||
        view == ProfileView.addresses ||
        view == ProfileView.addAddress ||
        view == ProfileView.editAddress ||
        view == ProfileView.bank ||
        view == ProfileView.myTickets ||
        view == ProfileView.raiseTicket;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _aadharController.dispose();
    _addrNameController.dispose();
    _addrPhoneController.dispose();
    _addrPincodeController.dispose();
    _addrStateController.dispose();
    _addrCityController.dispose();
    _addrHouseController.dispose();
    _addrAreaController.dispose();
    _accHolderController.dispose();
    _bankNameController.dispose();
    _accNumberController.dispose();
    _ifscController.dispose();
    _ticketSubjectController.dispose();
    _ticketDescController.dispose();
    _supportSearchController.dispose();
    super.dispose();
  }

  void _setView(ProfileView view) {
    if (_isProtectedView(view) && !_isLoggedIn) {
      _showLoginRequiredSheet();
      return;
    }

    setState(() {
      _currentView = view;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      if (view == ProfileView.myTickets) {
        _loadMyTickets();
      }
    });
  }

  Future<void> _handleUpdate() async {
    if (!_formKey.currentState!.validate()) return;

    final vm = context.read<AuthViewModel>();
    final userId = vm.loggedInUser?.id ?? '';

    final success = await vm.updateProfile(
      id: userId,
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      mobile: _phoneController.text.trim(),
      gender: _selectedGender.toLowerCase(),
      aadharCard: _aadharController.text.trim(),
      aadharCardImageBase64: _aadharImageBase64,
      profileImageBase64: _profileImageForUpload(),
    );

    if (!mounted) return;

    if (success) {
      _setView(ProfileView.main);
      _showSuccessSnackBar('Profile updated successfully!');
    } else {
      _showErrorSnackBar(vm.errorMessage ?? 'Profile update failed.');
    }
  }

  Future<void> _pickAadharImage() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image == null) return;

      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);

      if (!mounted) return;
      setState(() {
        _aadharImageBase64 = base64Image;
        _aadharImageName = image.name;
        _isAadharUploaded = true;
      });
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Could not pick image: $e');
    }
  }

  Future<void> _pickProfileImage({bool saveImmediately = false}) async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (image == null) return;

      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);

      if (!mounted) return;
      setState(() => _profileImageBase64 = base64Image);

      if (saveImmediately) {
        await _saveProfileImageOnly(base64Image);
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Could not pick profile image: $e');
    }
  }

  Future<void> _saveProfileImageOnly(String profileImageBase64) async {
    final vm = context.read<AuthViewModel>();
    final user = vm.loggedInUser;

    if (user == null || user.id.isEmpty) {
      _showLoginRequiredSheet();
      return;
    }

    setState(() => _isSavingProfileImage = true);

    final success = await vm.updateProfile(
      id: user.id,
      name: _nameController.text.trim().isNotEmpty
          ? _nameController.text.trim()
          : user.name,
      email: _emailController.text.trim().isNotEmpty
          ? _emailController.text.trim()
          : user.email,
      mobile: _phoneController.text.trim().isNotEmpty
          ? _phoneController.text.trim()
          : user.mobile,
      gender: _selectedGender.toLowerCase(),
      aadharCard: _aadharController.text.trim(),
      profileImageBase64: profileImageBase64,
    );

    if (!mounted) return;
    setState(() => _isSavingProfileImage = false);

    if (success) {
      _showSuccessSnackBar('Profile picture updated successfully!');
    } else {
      _showErrorSnackBar(vm.errorMessage ?? 'Profile picture update failed.');
    }
  }

  Future<void> _handleSaveAddress() async {
    if (!_addressFormKey.currentState!.validate()) return;

    final isEdit = _currentView == ProfileView.editAddress;
    final vm = context.read<AuthViewModel>();

    if (!isEdit) {
      final success = await vm.saveAddress(
        userId: vm.loggedInUser?.id ?? '',
        name: _addrNameController.text.trim(),
        mobile: _addrPhoneController.text.trim(),
        pincode: _addrPincodeController.text.trim(),
        city: _addrCityController.text.trim(),
        state: _addrStateController.text.trim(),
        houseNo: _addrHouseController.text.trim(),
        street: _addrAreaController.text.trim(),
        addressType: _selectedAddressType,
      );

      if (!mounted) return;

      if (!success) {
        _showErrorSnackBar(vm.errorMessage ?? 'Address save failed.');
        return;
      }
    } else {
      // ── EDIT ──
      final addressId =
          _addresses[_editingAddressIndex!]['id']?.toString() ?? '';
      final success = await vm.updateAddress(
        id: addressId,
        userId: vm.loggedInUser?.id ?? '',
        name: _addrNameController.text.trim(),
        mobile: _addrPhoneController.text.trim(),
        pincode: _addrPincodeController.text.trim(),
        city: _addrCityController.text.trim(),
        state: _addrStateController.text.trim(),
        houseNo: _addrHouseController.text.trim(),
        street: _addrAreaController.text.trim(),
        addressType: _selectedAddressType,
      );

      if (!mounted) return;

      if (!success) {
        _showErrorSnackBar(vm.errorMessage ?? 'Address update failed.');
        return;
      }
    }

    await _loadSavedAddresses();

    if (!mounted) return;

    setState(() {
      _editingAddressIndex = null;
      _clearAddressFields();
      _currentView = ProfileView.addresses;
    });

    _showSuccessSnackBar(isEdit ? 'Address updated!' : 'Address saved!');
  }

  Future<void> _handleRaiseTicket() async {
    if (_ticketFormKey.currentState!.validate()) {
      final authVM = context.read<AuthViewModel>();
      final userId = authVM.loggedInUser?.id ?? '';

      if (userId.isEmpty) {
        _showErrorSnackBar('Please login to raise a ticket.');
        return;
      }

      setState(() => _isLoadingTicket = true);

      try {
        final response = await _repo.saveTicket(
          userId: userId,
          issue: _selectedTicketCategory,
          subject: _ticketSubjectController.text.trim(),
          detail: _ticketDescController.text.trim(),
        );

        final savedId =
            response['id']?.toString() ??
            response['ticketId']?.toString() ??
            response['ticket_id']?.toString() ??
            '';

        String formattedDate = DateFormat(
          'dd / MMMM / yyyy hh:mm a',
        ).format(DateTime.now());

        setState(() {
          _myTickets.insert(0, {
            'id': savedId.isNotEmpty ? savedId : '...',
            'title': _ticketSubjectController.text.trim(),
            'issue': _selectedTicketCategory,
            'detail': _ticketDescController.text.trim(),
            'date': formattedDate,
            'status': 'Pending',
            'statusColor': const Color(0xFFF59E0B),
          });
          _ticketSubjectController.clear();
          _ticketDescController.clear();
          _currentView = ProfileView.myTickets;
        });

        _showSuccessSnackBar('Ticket raised successfully!');

        _loadMyTickets();
      } catch (e) {
        _showErrorSnackBar('Failed to raise ticket. Please try again.');
      } finally {
        if (mounted) setState(() => _isLoadingTicket = false);
      }
    }
  }

  void _raiseTicketWithCategory(String category) {
    if (!_isLoggedIn) {
      _showLoginRequiredSheet();
      return;
    }

    setState(() {
      _selectedTicketCategory = category;
      _currentView = ProfileView.raiseTicket;
    });
  }

  void _clearAddressFields() {
    _addrNameController.clear();
    _addrPhoneController.clear();
    _addrPincodeController.clear();
    
    final authVm = context.read<AuthViewModel>();
    if (authVm.selectedState != null && authVm.selectedState!.isNotEmpty) {
      _addrStateController.text = authVm.selectedState!;
      _fetchCitiesForState(authVm.selectedState!);
    } else {
      _addrStateController.clear();
    }
    
    if (authVm.selectedCity != null && authVm.selectedCity!.isNotEmpty) {
      _addrCityController.text = authVm.selectedCity!;
    } else {
      _addrCityController.clear();
    }
    
    _addrHouseController.clear();
    _addrAreaController.clear();
    _selectedAddressType = 'Home';
    _isDefaultAddress = false;
  }

  void _startEditingAddress(int index) {
    var addr = _addresses[index];
    setState(() {
      _editingAddressIndex = index;
      _addrNameController.text = addr['name'] ?? '';
      _addrPhoneController.text = addr['phone'] ?? '';
      _addrPincodeController.text = addr['pincode'] ?? '';
      _addrStateController.text = addr['state'] ?? '';
      _addrCityController.text = addr['city'] ?? '';
      _addrHouseController.text = addr['house'] ?? '';
      _addrAreaController.text = addr['area'] ?? '';
      _selectedAddressType = addr['type'] ?? 'Home';
      _isDefaultAddress = addr['isDefault'] ?? false;
      _currentView = ProfileView.editAddress;
    });
  }

  Future<void> _detectCurrentAddress() async {
    if (_isDetectingLocation) return;

    setState(() => _isDetectingLocation = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showErrorSnackBar('Please enable GPS/location service and try again.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showErrorSnackBar('Location permission denied.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 12),
      );
      final details = await _reverseGeocodeAddressDetails(
        position.latitude,
        position.longitude,
      );

      if (details.isEmpty) {
        _showErrorSnackBar('Could not find address for your current location.');
        return;
      }

      if (!mounted) return;
      setState(() {
        _addrCityController.text = details['city'] ?? '';
        _addrStateController.text = details['state'] ?? '';
        _addrPincodeController.text = details['postcode'] ?? '';
        if ((details['house'] ?? '').isNotEmpty) {
          _addrHouseController.text = details['house']!;
        }
        if ((details['area'] ?? '').isNotEmpty) {
          _addrAreaController.text = details['area']!;
        }
      });
    } catch (e) {
      debugPrint('Profile detect location error: $e');
      if (mounted) {
        _showErrorSnackBar(
          'Could not fetch current location. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isDetectingLocation = false);
    }
  }

  Future<Map<String, String>> _reverseGeocodeAddressDetails(
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
        final displayName = data['display_name']?.toString().trim() ?? '';
        return {
          'house': [
            nativeHouse,
            building,
            houseNumber,
          ].where((value) => value.isNotEmpty).join(', '),
          'area': displayName.isNotEmpty
              ? [
                  nativeHouse,
                  displayName,
                ].where((value) => value.isNotEmpty).toSet().join(', ')
              : [
                  road,
                  suburb,
                  district,
                ].where((value) => value.isNotEmpty).toSet().join(', '),
          'city': city,
          'state': addr['state']?.toString() ?? '',
          'postcode': addr['postcode']?.toString() ?? '',
        };
      }
    } catch (e) {
      debugPrint('Profile detailed reverse geocode error: $e');
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
      return {
        'house': [place.name, place.subThoroughfare]
            .where((value) => value != null && value.trim().isNotEmpty)
            .toSet()
            .join(', '),
        'area':
            [
                  place.name,
                  place.subThoroughfare,
                  place.street,
                  place.subLocality,
                  place.thoroughfare,
                ]
                .where((value) => value != null && value.trim().isNotEmpty)
                .toSet()
                .join(', '),
        'city': city,
        'state': place.administrativeArea ?? '',
        'postcode': place.postalCode ?? '',
      };
    } catch (e) {
      debugPrint('Profile placemark fallback error: $e');
      return {};
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              message,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 10,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 10,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _confirmDeleteAddress(int index) {
    String type = _addresses[index]['type'].toString().toLowerCase();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 64,
                  width: 64,
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red.shade400,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Delete address?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Are you sure you want to delete $type address?',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context); // dialog band karo
                          final addressId =
                              _addresses[index]['id']?.toString() ?? '';
                          final vm = context.read<AuthViewModel>();
                          final success = await vm.deleteAddress(addressId);
                          if (!mounted) return;
                          if (success) {
                            await _loadSavedAddresses();
                            _showSuccessSnackBar(
                              'Address deleted successfully!',
                            );
                          } else {
                            _showErrorSnackBar(
                              vm.errorMessage ?? 'Delete failed.',
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade400,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Delete',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleBack() {
    if (_currentView == ProfileView.bank) {
      setState(() {
        _showBankForm = false;
        _editingBankId = null;
        _accHolderController.clear();
        _bankNameController.clear();
        _accNumberController.clear();
        _ifscController.clear();
      });
    }

    if (_currentView == ProfileView.addAddress ||
        _currentView == ProfileView.editAddress) {
      _setView(ProfileView.addresses);
    } else if (_currentView == ProfileView.ordersTracking ||
        _currentView == ProfileView.paymentRefunds ||
        _currentView == ProfileView.sellDeviceIssues ||
        _currentView == ProfileView.accountProfile) {
      _setView(ProfileView.support);
    } else if (_currentView == ProfileView.myTickets) {
      _setView(ProfileView.support);
    } else if (_currentView == ProfileView.raiseTicket) {
      _setView(ProfileView.support);
    } else {
      _setView(ProfileView.main);
    }
  }

  Future<void> _openLoginScreen() async {
    Navigator.pop(context);
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    if (!mounted) return;
    _loadSavedAddresses();
    _loadBankDetails();
    _loadMyTickets();
    setState(() => _currentView = ProfileView.main);
  }

  void _showLoginRequiredSheet() {
    showModalBottomSheet<void>(
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
              height: 54,
              width: 54,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.lock_person_rounded,
                color: Color(0xFF4F46E5),
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Login required',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please login to manage personal info, addresses, bank details, and support tickets.',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 22),
            ElevatedButton(
              onPressed: _openLoginScreen,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 54),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Login / Create Account',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = context.watch<AuthViewModel>().loggedInUser != null;
    final isPolicyView =
        _currentView == ProfileView.terms ||
        _currentView == ProfileView.privacyPolicy ||
        _currentView == ProfileView.returnRefundPolicy ||
        _currentView == ProfileView.aboutUs;

    return WillPopScope(
      onWillPop: () async {
        if (_currentView != ProfileView.main) {
          _handleBack();
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: isPolicyView
            ? _buildContent()
            : SingleChildScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: Column(
                    children: [
                      if (_currentView == ProfileView.main) ...[
                        isLoggedIn ? _buildHeader() : _buildLoggedOutHeader(),
                        const SizedBox(height: 24),
                      ],
                      _buildContent(),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  String _normalizeBase64Image(String value) {
    final image = value.trim();
    final commaIndex = image.indexOf(',');
    if (image.startsWith('data:image') && commaIndex != -1) {
      return image.substring(commaIndex + 1);
    }
    return image;
  }

  String _resolveProfileImageUrl(String value) {
    final v = value.trim();
    if (v.isEmpty) return '';
    if (_isNetworkImageValue(v)) return v;
    final path = v.startsWith('/') ? v.substring(1) : v;
    return '${ApiConstants.MEDIA_BASE_URL}$path';
  }

  ImageProvider _profileImageProvider() {
    final image = _profileImageBase64;
    if (image != null && image.isNotEmpty) {
      if (_isNetworkImageValue(image)) {
        return NetworkImage(image);
      }

      if (!image.contains(' ') && image.contains('/')) {
        return NetworkImage(_resolveProfileImageUrl(image));
      }

      try {
        return MemoryImage(base64Decode(_normalizeBase64Image(image)));
      } catch (_) {
        return const AssetImage('assets/man_1.png');
      }
    }

    return const AssetImage('assets/man_1.png');
  }

  bool _isNetworkImageValue(String value) {
    final image = value.trim().toLowerCase();
    return image.startsWith('http://') || image.startsWith('https://');
  }

  String? _profileImageForUpload() {
    final image = _profileImageBase64;
    if (image == null || image.isEmpty || _isNetworkImageValue(image)) {
      return null;
    }
    return _normalizeBase64Image(image);
  }

  Widget _buildHeader() {
    final profileImage = _profileImageProvider();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 50),
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(36),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withOpacity(0.06),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: _buildProfileSummary(),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(
              child: Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: GestureDetector(
                      onTap: _isSavingProfileImage
                          ? null
                          : () => _pickProfileImage(saveImmediately: true),
                      child: CircleAvatar(
                        radius: 45,
                        backgroundColor: const Color(0xFFF1F5F9),
                        backgroundImage: profileImage,
                        child: _isSavingProfileImage
                            ? Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.35),
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _isSavingProfileImage
                          ? null
                          : () => _pickProfileImage(saveImmediately: true),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 18,
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

  Widget _buildLoggedOutHeader() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 76,
            width: 76,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEEF2FF), Color(0xFFE0F2FE)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.person_outline_rounded,
              color: Color(0xFF4F46E5),
              size: 38,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Login to manage your profile',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Access saved addresses, payout banks, personal info, and support tickets after login.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _showLoginRequiredSheet,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 54),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Login / Create Account',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSummary() {
    final user = context.watch<AuthViewModel>().loggedInUser;

    return Column(
      children: [
        Text(
          user?.name ?? '',
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: (user?.mobile ?? '').isEmpty
              ? () => _setView(ProfileView.edit)
              : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: (user?.mobile ?? '').isEmpty
                  ? const Color(0xFFFFF7ED)
                  : const Color(0xFF6366F1).withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: (user?.mobile ?? '').isEmpty
                  ? Border.all(
                      color: const Color(0xFFF97316).withOpacity(0.4),
                      width: 1,
                    )
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  (user?.mobile ?? '').isEmpty
                      ? Icons.phone_android_rounded
                      : Icons.phone_android_rounded,
                  size: 13,
                  color: (user?.mobile ?? '').isEmpty
                      ? const Color(0xFFF97316)
                      : const Color(0xFF6366F1),
                ),
                const SizedBox(width: 5),
                Text(
                  (user?.mobile ?? '').isEmpty
                      ? 'Add mobile number'
                      : user!.mobile,
                  style: TextStyle(
                    color: (user?.mobile ?? '').isEmpty
                        ? const Color(0xFFF97316)
                        : const Color(0xFF6366F1),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                if ((user?.mobile ?? '').isEmpty) ...[
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 10,
                    color: Color(0xFFF97316),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          user?.email ?? '',
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 18),
        TextButton.icon(
          onPressed: () => _setView(ProfileView.edit),
          icon: const Icon(Icons.edit_rounded, size: 16),
          label: const Text('Edit profile'),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF4F46E5),
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEditFormView() {
    return Column(
      children: [
        _buildSubPageHeader('Personal Info', _handleBack),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('EDIT PERSONAL INFORMATION'),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withOpacity(0.04),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildProfileImagePicker(),
                      const SizedBox(height: 12),
                      _buildModernField(
                        controller: _nameController,
                        label: 'Full Name',
                        icon: Icons.person_outline_rounded,
                      ),
                      const SizedBox(height: 12),
                      _buildModernField(
                        controller: _emailController,
                        label: 'Email Address',
                        icon: Icons.email_outlined,
                      ),
                      const SizedBox(height: 12),
                      _buildModernField(
                        controller: _phoneController,
                        label: 'Mobile Number',
                        icon: Icons.phone_android_rounded,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),
                      _buildGenderSelector(),
                      const SizedBox(height: 12),
                      _buildModernField(
                        controller: _aadharController,
                        label: 'Aadhar Number',
                        icon: Icons.credit_card_rounded,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      _buildAadharUpload(),
                      const SizedBox(height: 20),
                      Consumer<AuthViewModel>(
                        builder: (_, vm, __) => _buildPrimaryButton(
                          vm.isLoading ? 'Saving...' : 'Save Changes',
                          vm.isLoading ? null : _handleUpdate,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileImagePicker() {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: const Color(0xFFF1F5F9),
              backgroundImage: _profileImageProvider(),
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: InkWell(
                onTap: () => _pickProfileImage(),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: () => _pickProfileImage(),
          style: TextButton.styleFrom(
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'Change profile picture',
            style: TextStyle(
              color: Color(0xFF6366F1),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAadharUpload() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cloud_upload_outlined,
                  color: Color(0xFF6366F1),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Upload Aadhar Card',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isAadharUploaded
                          ? (_aadharImageName ?? 'Verification image ready')
                          : 'Front & Back photo (Max 5MB)',
                      style: TextStyle(
                        color: Color(
                          _isAadharUploaded ? 0xFF10B981 : 0xFF94A3B8,
                        ),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _pickAadharImage,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF6366F1),
              elevation: 0,
              side: const BorderSide(color: Color(0xFF6366F1)),
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              _isAadharUploaded ? 'Replace Document' : 'Browse Files',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankAccountCard(Map<String, dynamic> bank) {
    final accountNo = bank['accountNo']?.toString() ?? '';
    final maskedAccount = accountNo.length > 4
        ? '•••• ${accountNo.substring(accountNo.length - 4)}'
        : accountNo;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.account_balance_rounded,
                  color: Color(0xFF6366F1),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bank['bankName']?.toString() ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${bank['accountName'] ?? ''} - $maskedAccount',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'IFSC: ${bank['ifscCode'] ?? ''}',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildSmallIconButton(
                'Edit',
                Icons.edit_rounded,
                const Color(0xFF6366F1),
                () => _startEditingBank(bank),
              ),
              const SizedBox(width: 12),
              _buildSmallIconButton(
                'Delete',
                Icons.delete_outline_rounded,
                Colors.redAccent,
                () => _confirmDeleteBank(bank),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBankDetailsView() {
    return Column(
      children: [
        _buildSubPageHeader('Bank Details', _handleBack),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('SAVED BANK ACCOUNTS'),
              if (_isLoadingBankDetails)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: LinearProgressIndicator(minHeight: 2),
                )
              else if (_bankAccounts.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No bank details added yet',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                ..._bankAccounts.map(_buildBankAccountCard),

              const SizedBox(height: 16),

              if (!_showBankForm && _editingBankId == null)
                GestureDetector(
                  onTap: () => setState(() => _showBankForm = true),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF6366F1).withOpacity(0.3),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_rounded,
                          color: Color(0xFF6366F1),
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Add Another Bank Account',
                          style: TextStyle(
                            color: Color(0xFF6366F1),
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              if (_showBankForm || _editingBankId != null) ...[
                const SizedBox(height: 20),
                _buildSectionTitle(
                  _editingBankId != null
                      ? 'EDIT BANK ACCOUNT'
                      : 'ADD BANK ACCOUNT',
                ),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withOpacity(0.04),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _bankFormKey,
                    child: Column(
                      children: [
                        _buildModernField(
                          controller: _accHolderController,
                          label: 'Account Holder Name',
                          icon: Icons.person_outline_rounded,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Account holder name required'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        _buildModernField(
                          controller: _bankNameController,
                          label: 'Bank Name',
                          icon: Icons.account_balance_rounded,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Bank name required'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        _buildModernField(
                          controller: _accNumberController,
                          label: 'Account Number',
                          icon: Icons.numbers_rounded,
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty)
                              return 'Account number required';
                            if (v.trim().length < 9)
                              return 'Enter valid account number';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildModernField(
                          controller: _ifscController,
                          label: 'IFSC Code',
                          icon: Icons.qr_code_rounded,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty)
                              return 'IFSC code required';
                            final ifscRegex = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');
                            if (!ifscRegex.hasMatch(v.trim().toUpperCase()))
                              return 'Enter valid IFSC (e.g. SBIN0001234)';
                            return null;
                          },
                        ),
                        const SizedBox(height: 32),
                        Row(
                          children: [
                            // Cancel button
                            Expanded(
                              child: TextButton(
                                onPressed: () => setState(() {
                                  _showBankForm = false;
                                  _editingBankId = null;
                                  _accHolderController.clear();
                                  _bankNameController.clear();
                                  _accNumberController.clear();
                                  _ifscController.clear();
                                }),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Save button
                            Expanded(
                              child: Consumer<AuthViewModel>(
                                builder: (_, vm, __) => _buildPrimaryButton(
                                  vm.isLoading
                                      ? 'Saving...'
                                      : _editingBankId != null
                                      ? 'Update'
                                      : 'Save',
                                  vm.isLoading ? null : _handleBankUpdate,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    switch (_currentView) {
      case ProfileView.addresses:
        return _buildManageAddresses();
      case ProfileView.addAddress:
      case ProfileView.editAddress:
        return _buildAddressFormView();
      case ProfileView.edit:
        return _buildEditFormView();
      case ProfileView.bank:
        return _buildBankDetailsView();
      case ProfileView.support:
        return _buildCustomerSupportView();
      case ProfileView.ordersTracking:
        return _buildOrdersTrackingView();
      case ProfileView.paymentRefunds:
        return _buildPaymentRefundsView();
      case ProfileView.sellDeviceIssues:
        return _buildSellDeviceIssuesView();
      case ProfileView.accountProfile:
        return _buildAccountProfileIssuesView();
      case ProfileView.myTickets:
        return _buildMyTicketsView();
      case ProfileView.raiseTicket:
        return _buildRaiseTicketView();
      case ProfileView.terms:
        return _buildPolicyWebView(
          title: 'Terms & Conditions',
          url: ApiConstants.TERMS_URL,
        );
      case ProfileView.privacyPolicy:
        return _buildPolicyWebView(
          title: 'Privacy Policy',
          url: ApiConstants.PRIVACY_POLICY_URL,
        );
      case ProfileView.returnRefundPolicy:
        return _buildPolicyWebView(
          title: 'Return & Refund Policy',
          url: ApiConstants.RETURN_REFUND_POLICY_URL,
        );
      case ProfileView.aboutUs:
        return _buildPolicyWebView(
          title: 'About SeloRize',
          url: ApiConstants.ABOUT_US_URL,
        );
      default:
        return _buildMainMenu();
    }
  }

  Widget _buildPolicyWebView({required String title, required String url}) {
    return Column(
      children: [
        _buildSubPageHeader(title, _handleBack),
        Expanded(
          child: Container(
            width: double.infinity,
            color: Colors.white,
            child: _InAppPolicyWebView(url: url),
          ),
        ),
      ],
    );
  }

  Widget _buildMainMenu() {
    final isLoggedIn = context.watch<AuthViewModel>().loggedInUser != null;

    return Column(
      children: [
        _buildSectionHeader('Account Management'),
        _buildMenuItem(
          Icons.person_outline_rounded,
          'Personal Information',
          isLoggedIn ? 'Identity and profile details' : 'Login required',
          () => _setView(ProfileView.edit),
          locked: !isLoggedIn,
        ),
        _buildMenuItem(
          Icons.location_on_outlined,
          'Manage Address',
          isLoggedIn ? 'Pickup and delivery locations' : 'Login required',
          () => _setView(ProfileView.addresses),
          locked: !isLoggedIn,
        ),
        _buildMenuItem(
          Icons.account_balance_rounded,
          'Bank Details',
          isLoggedIn ? 'Payout methods for your sales' : 'Login required',
          () => _setView(ProfileView.bank),
          locked: !isLoggedIn,
        ),
        const SizedBox(height: 24),
        _buildSectionHeader('Support & Policy'),
        _buildMenuItem(
          Icons.headset_mic_outlined,
          'Customer Support',
          'Get help with your orders',
          () => _setView(ProfileView.support),
        ),
        _buildMenuItem(
          Icons.description_outlined,
          'Terms & Conditions',
          'App usage and service policies',
          () => _setView(ProfileView.terms),
        ),
        _buildMenuItem(
          Icons.privacy_tip_outlined,
          'Privacy Policy',
          'Data security and privacy',
          () => _setView(ProfileView.privacyPolicy),
        ),
        _buildMenuItem(
          Icons.assignment_return_outlined,
          'Return & Refund Policy',
          'Returns, cancellations and refunds',
          () => _setView(ProfileView.returnRefundPolicy),
        ),
        _buildMenuItem(
          Icons.info_outline_rounded,
          'About SeloRize',
          'Learn more about SeloRize',
          () => _setView(ProfileView.aboutUs),
        ),
        const SizedBox(height: 32),
        if (isLoggedIn) ...[
          _buildDeleteProfileButton(),
          const SizedBox(height: 12),
          _buildLogoutButton(),
        ],
      ],
    );
  }

  Widget _buildCustomerSupportView() {
    final isLoggedIn = context.watch<AuthViewModel>().loggedInUser != null;
    final searchResults = _supportSearchResults();
    final hasSearchQuery = _supportSearchQuery.trim().isNotEmpty;

    return Column(
      children: [
        _buildSubPageHeader('CUSTOMER SUPPORT & FAQs', _handleBack),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionTitle('CUSTOMER SUPPORT & FAQs'),
                  TextButton.icon(
                    onPressed: () => _setView(ProfileView.myTickets),
                    icon: Icon(
                      isLoggedIn
                          ? Icons.confirmation_number_outlined
                          : Icons.lock_outline_rounded,
                      size: 18,
                      color: const Color(0xFF6366F1),
                    ),
                    label: Text(
                      isLoggedIn ? 'My Tickets' : 'Login',
                      style: const TextStyle(
                        color: Color(0xFF6366F1),
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withOpacity(0.04),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _supportSearchController,
                  onChanged: (value) =>
                      setState(() => _supportSearchQuery = value),
                  decoration: InputDecoration(
                    hintText: "Search for help.... eg., \"refund\"",
                    hintStyle: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Color(0xFF6366F1),
                      size: 22,
                    ),
                    suffixIcon: _supportSearchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Color(0xFF94A3B8),
                            ),
                            onPressed: () {
                              _supportSearchController.clear();
                              setState(() => _supportSearchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              if (hasSearchQuery) ...[
                _buildSupportSearchResults(searchResults),
                const SizedBox(height: 12),
              ],
              if (!hasSearchQuery) ...[
                _buildSupportCard(
                  title: 'Orders & Tracking',
                  icon: Icons.local_shipping_outlined,
                  iconBg: const Color(0xFFEFF6FF),
                  iconColor: const Color(0xFF3B82F6),
                  onTap: () => _setView(ProfileView.ordersTracking),
                ),
                _buildSupportCard(
                  title: 'Payment & Refunds',
                  icon: Icons.account_balance_wallet_outlined,
                  iconBg: const Color(0xFFFEF2F2),
                  iconColor: const Color(0xFFEF4444),
                  onTap: () => _setView(ProfileView.paymentRefunds),
                ),
                _buildSupportCard(
                  title: 'Sell Device Issues',
                  icon: Icons.phonelink_erase_rounded,
                  iconBg: const Color(0xFFF0FDF4),
                  iconColor: const Color(0xFF10B981),
                  onTap: () => _setView(ProfileView.sellDeviceIssues),
                ),
                _buildSupportCard(
                  title: 'Account & Profile',
                  icon: Icons.person_pin_outlined,
                  iconBg: const Color(0xFFF5F3FF),
                  iconColor: const Color(0xFF8B5CF6),
                  onTap: () => _setView(ProfileView.accountProfile),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () => _setView(ProfileView.raiseTicket),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      isLoggedIn ? 'Contact Us Now' : 'Login to Raise Ticket',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFAQViewTemplate(
    String title,
    List<Map<String, String>> faqs,
    String ticketCategory,
  ) {
    return Column(
      children: [
        _buildSubPageHeader(title, _handleBack),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle(title),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withOpacity(0.04),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: _isLoadingFaqs
                    ? const Padding(
                        padding: EdgeInsets.all(28),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : faqs.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Column(
                            children: [
                              const Icon(
                                Icons.help_outline_rounded,
                                color: Color(0xFF94A3B8),
                                size: 34,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _faqErrorMessage ??
                                    'No FAQs available for this section.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Column(
                        children: faqs.asMap().entries.map((entry) {
                          bool isLast = entry.key == faqs.length - 1;
                          return Column(
                            children: [
                              _buildFAQTile(
                                entry.value['q']!,
                                entry.value['a']!,
                              ),
                              if (!isLast) _buildDivider(),
                            ],
                          );
                        }).toList(),
                      ),
              ),
              const SizedBox(height: 32),
              _buildNeedHelpCard(ticketCategory),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSupportSearchResults(List<FaqItem> results) {
    if (_isLoadingFaqs) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (results.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Text(
          'No matching help articles found.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: results.take(4).map((faq) {
          return ListTile(
            onTap: () {
              _supportSearchController.clear();
              setState(() => _supportSearchQuery = '');
              _setView(_supportViewForFaqType(faq.category));
            },
            title: Text(
              faq.question,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            subtitle: Text(
              faq.category,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFCBD5E1),
            ),
          );
        }).toList(),
      ),
    );
  }

  ProfileView _supportViewForFaqType(String type) {
    final normalized = _normalizeFaqText(type);
    if (normalized == _normalizeFaqText('Orders & Tracking')) {
      return ProfileView.ordersTracking;
    }
    if (normalized == _normalizeFaqText('Payment & Refunds')) {
      return ProfileView.paymentRefunds;
    }
    if (normalized == _normalizeFaqText('Sell Device Issues')) {
      return ProfileView.sellDeviceIssues;
    }
    if (normalized == _normalizeFaqText('Account & Profile')) {
      return ProfileView.accountProfile;
    }
    return ProfileView.support;
  }

  Widget _buildNeedHelpCard(String ticketCategory) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEEF2FF), Color(0xFFFFFFFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Still Need Help ?',
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Our team is available 24/7 to assist you',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          _buildPrimaryButton(
            'Raise a Ticket',
            () => _raiseTicketWithCategory(ticketCategory),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersTrackingView() {
    return _buildFAQViewTemplate(
      'ORDERS & TRACKING',
      _faqsForType('Orders & Tracking'),
      'Order Issue',
    );
  }

  Widget _buildPaymentRefundsView() {
    return _buildFAQViewTemplate(
      'PAYMENT & REFUNDS',
      _faqsForType('Payment & Refunds'),
      'Payment/Refund',
    );
  }

  Widget _buildSellDeviceIssuesView() {
    return _buildFAQViewTemplate(
      'SELL DEVICE ISSUES',
      _faqsForType('Sell Device Issues'),
      'Sell Issue',
    );
  }

  Widget _buildAccountProfileIssuesView() {
    return _buildFAQViewTemplate(
      'ACCOUNT & PROFILE',
      _faqsForType('Account & Profile'),
      'Profile Issue',
    );
  }

  Widget _buildMyTicketsView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSubPageHeader('My Tickets', _handleBack),

        if (_isLoadingMyTickets)
          Skeletonizer(
            enabled: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              child: Column(
                children: List.generate(
                  3,
                  (_) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
          )
        else if (_myTickets.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 16),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.confirmation_number_outlined,
                    size: 64,
                    color: Color(0xFFCBD5E1),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No tickets yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Raise a ticket if you need help',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFFCBD5E1),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: () => _setView(ProfileView.raiseTicket),
                    icon: const Icon(Icons.add_rounded, size: 22),
                    label: const Text(
                      'Raise a Ticket',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6366F1),
                      side: const BorderSide(
                        color: Color(0xFF6366F1),
                        width: 2,
                      ),
                      minimumSize: const Size(200, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('MY TICKETS'),
                ..._myTickets.map(
                  (ticket) => Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withOpacity(0.03),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Ticket #${ticket['id']}',
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: (ticket['statusColor'] as Color)
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                ticket['status'],
                                style: TextStyle(
                                  color: ticket['statusColor'] as Color,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          ticket['title'] ?? '',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ticket['issue'] ?? '',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF6366F1),
                          ),
                        ),
                        if ((ticket['detail'] ?? '').toString().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            ticket['detail'],
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Text(
                          () {
                            final d = ticket['date']?.toString() ?? '';
                            return (d.isEmpty || d == 'null')
                                ? 'Date not available'
                                : d;
                          }(),
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => _setView(ProfileView.raiseTicket),
                  icon: const Icon(Icons.add_rounded, size: 22),
                  label: const Text(
                    'Raise New Ticket',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6366F1),
                    side: const BorderSide(color: Color(0xFF6366F1), width: 2),
                    minimumSize: const Size(double.infinity, 60),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildRaiseTicketView() {
    return Column(
      children: [
        _buildSubPageHeader('Raise a Ticket', _handleBack),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('RAISE A TICKET'),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withOpacity(0.04),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Form(
                  key: _ticketFormKey,
                  child: Column(
                    children: [
                      _buildTicketCategorySelector(),
                      const SizedBox(height: 16),
                      _buildModernField(
                        controller: _ticketSubjectController,
                        label: 'Subject',
                        icon: Icons.subject_rounded,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _ticketDescController,
                        maxLines: 5,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                          fontSize: 15,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Describe your issue',
                          alignLabelWithHint: true,
                          labelStyle: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(bottom: 80),
                            child: Icon(
                              Icons.edit_note_rounded,
                              color: Color(0xFF6366F1),
                              size: 24,
                            ),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFF6366F1),
                              width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.all(18),
                        ),
                        validator: (v) =>
                            v!.isEmpty ? 'Please describe the issue' : null,
                      ),
                      const SizedBox(height: 32),
                      _buildPrimaryButton(
                        _isLoadingTicket ? 'Submitting...' : 'Submit Ticket',
                        _isLoadingTicket ? null : _handleRaiseTicket,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTicketCategorySelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.category_outlined,
            color: Color(0xFF6366F1),
            size: 20,
          ),
          const SizedBox(width: 12),
          const Text(
            'Category',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          DropdownButton<String>(
            value: _selectedTicketCategory,
            underline: const SizedBox(),
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF94A3B8),
            ),
            items:
                [
                      'Order Issue',
                      'Payment/Refund',
                      'Profile Issue',
                      'Sell Issue',
                      'Other',
                    ]
                    .map(
                      (String value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    )
                    .toList(),
            onChanged: (newValue) =>
                setState(() => _selectedTicketCategory = newValue!),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQTile(
    String title,
    String content, {
    bool isExpanded = false,
  }) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: isExpanded,
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: Color(0xFF0F172A),
          ),
        ),
        trailing: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: Color(0xFF94A3B8),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        backgroundColor: isExpanded
            ? const Color(0xFFF1F5F9).withOpacity(0.5)
            : Colors.transparent,
        children: [
          Text(
            content,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 14,
              height: 1.6,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      color: const Color(0xFFF1F5F9),
      thickness: 1,
      indent: 20,
      endIndent: 20,
    );
  }

  Widget _buildSupportCard({
    required String title,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 11),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.03),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 23),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1)),
          ],
        ),
      ),
    );
  }

  Widget _buildManageAddresses() {
    return Column(
      children: [
        _buildSubPageHeader('Saved Addresses', _handleBack),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('SAVED ADDRESSES'),
              if (_isLoadingAddresses)
                Skeletonizer(
                  enabled: true,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: List.generate(
                        2,
                        (_) => Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              else if (_addresses.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No saved addresses yet',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
              else
                ..._addresses.asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildAddressCard(
                      index: entry.key,
                      type: entry.value['type'],
                      address: entry.value['address'],
                      isDefault: entry.value['isDefault'],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  _clearAddressFields();
                  _setView(ProfileView.addAddress);
                },
                icon: const Icon(Icons.add_rounded, size: 22),
                label: const Text(
                  'Add New Address',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF6366F1),
                  side: const BorderSide(color: Color(0xFF6366F1), width: 2),
                  minimumSize: const Size(double.infinity, 60),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAddressFormView() {
    bool isEdit = _currentView == ProfileView.editAddress;
    return Column(
      children: [
        _buildSubPageHeader(
          isEdit ? 'Edit Address' : 'New Address',
          _handleBack,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle(isEdit ? 'EDIT ADDRESS' : 'NEW ADDRESS'),
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
                child: Form(
                  key: _addressFormKey,
                  child: Column(
                    children: [
                      _buildModernField(
                        controller: _addrNameController,
                        label: 'Full Name',
                        icon: Icons.person_outline_rounded,
                      ),
                      const SizedBox(height: 16),
                      _buildModernField(
                        controller: _addrPhoneController,
                        label: 'Mobile Number',
                        icon: Icons.phone_android_rounded,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildModernField(
                              controller: _addrPincodeController,
                              label: 'Pincode',
                              icon: Icons.pin_drop_outlined,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          _buildDetectLocationButton(),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildModernDropdownField(
                              controller: _addrStateController,
                              label: 'State',
                              icon: Icons.map_rounded,
                              items: _statesList,
                              onChanged: (val) {
                                if (val != null) {
                                  _fetchCitiesForState(val);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildModernDropdownField(
                              controller: _addrCityController,
                              label: 'City',
                              icon: Icons.location_city_rounded,
                              items: _citiesList,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildModernField(
                        controller: _addrHouseController,
                        label: 'House No. / Flat No.',
                        icon: Icons.home_work_outlined,
                      ),
                      const SizedBox(height: 16),
                      _buildModernField(
                        controller: _addrAreaController,
                        label: 'Area / Colony / Street',
                        icon: Icons.streetview_rounded,
                      ),
                      const SizedBox(height: 16),
                      if (!isEdit) _buildAddressTypeSelector(),
                      if (isEdit) _buildDefaultToggle(),
                      const SizedBox(height: 32),
                      Consumer<AuthViewModel>(
                        builder: (_, vm, __) => _buildPrimaryButton(
                          vm.isLoading
                              ? 'Saving...'
                              : isEdit
                              ? 'Update Address'
                              : 'Save Address',
                          vm.isLoading ? null : _handleSaveAddress,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetectLocationButton() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: IconButton(
        onPressed: _isDetectingLocation ? null : _detectCurrentAddress,
        icon: _isDetectingLocation
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

  Widget _buildAddressTypeSelector() {
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
            _buildTypeChip('Home', Icons.home_rounded),
            const SizedBox(width: 12),
            _buildTypeChip('Work', Icons.work_rounded),
            const SizedBox(width: 12),
            _buildTypeChip('Other', Icons.more_horiz_rounded),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeChip(String label, IconData icon) {
    bool isSelected = _selectedAddressType == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedAddressType = label),
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

  Widget _buildDefaultToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Set as Default Address',
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          Switch.adaptive(
            value: _isDefaultAddress,
            onChanged: (v) => setState(() => _isDefaultAddress = v),
            activeColor: const Color(0xFF6366F1),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 16),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF94A3B8),
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap, {
    bool locked = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        tileColor: Colors.white,
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: locked ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            icon,
            color: locked ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
            size: 22,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            shape: BoxShape.circle,
          ),
          child: Icon(
            locked ? Icons.lock_outline_rounded : Icons.chevron_right_rounded,
            color: locked ? const Color(0xFF94A3B8) : const Color(0xFFCBD5E1),
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildModernField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        color: Color(0xFF0F172A),
        fontSize: 15,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: Color(0xFF94A3B8),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: Icon(icon, color: const Color(0xFF6366F1), size: 20),
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

  Widget _buildModernDropdownField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required List<String> items,
    void Function(String?)? onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: items.contains(controller.text) ? controller.text : (items.isNotEmpty ? items.first : null),
      onChanged: (val) {
        if (val != null) {
          controller.text = val;
        }
        if (onChanged != null) {
          onChanged(val);
        }
      },
      isExpanded: true,
      items: items.map((e) => DropdownMenuItem(
        value: e,
        child: Text(
          e,
          overflow: TextOverflow.ellipsis,
        ),
      )).toList(),
      style: const TextStyle(
        fontWeight: FontWeight.w500,
        color: Color(0xFF0F172A),
        fontSize: 15,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: Color(0xFF94A3B8),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: Icon(icon, color: const Color(0xFF6366F1), size: 20),
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

  Widget _buildGenderSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.wc_rounded, color: Color(0xFF6366F1), size: 20),
          const SizedBox(width: 12),
          const Text(
            'Gender',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          DropdownButton<String>(
            value: _selectedGender,
            underline: const SizedBox(),
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF94A3B8),
            ),
            items: ['Male', 'Female', 'Other']
                .map(
                  (String value) => DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      value,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        fontSize: 14,
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: (newValue) =>
                setState(() => _selectedGender = newValue!),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton(String label, VoidCallback? onTap) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6366F1),
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 60),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteProfileButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: TextButton(
        onPressed: _confirmDeleteProfile,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFFECACA), width: 1.5),
          ),
          backgroundColor: const Color(0xFFFFF1F2),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_forever_rounded, color: Color(0xFFDC2626)),
            SizedBox(width: 10),
            Text(
              'Delete Profile',
              style: TextStyle(
                color: Color(0xFFDC2626),
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteProfile() async {
    final vm = context.read<AuthViewModel>();
    final user = vm.loggedInUser;

    if (user == null || user.id.isEmpty) {
      _showLoginRequiredSheet();
      return;
    }

    var isDeleting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: const Text(
                'Delete profile?',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              content: const Text(
                'Are you sure you want to delete your profile? You will be logged out after confirmation.',
              ),
              actions: [
                TextButton(
                  onPressed: isDeleting
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('No'),
                ),
                ElevatedButton(
                  onPressed: isDeleting
                      ? null
                      : () async {
                          final timestamp = DateFormat(
                            'yyyy-MM-dd HH:mm:ss',
                          ).format(DateTime.now());
                          final deletedMobile =
                              '${user.mobile} - ( user deleted $timestamp )';

                          setDialogState(() => isDeleting = true);
                          final success = await vm.deleteProfile(
                            mobile: deletedMobile,
                          );

                          if (!mounted) return;

                          if (success) {
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                            setState(() => _currentView = ProfileView.main);
                            _showSuccessSnackBar(
                              'Profile deleted successfully.',
                            );
                          } else {
                            setDialogState(() => isDeleting = false);
                            _showErrorSnackBar(
                              vm.errorMessage ?? 'Profile delete failed.',
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isDeleting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Yes, Delete'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildLogoutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: TextButton(
        onPressed: () async {
          await context.read<AuthViewModel>().logout();

          if (!context.mounted) return;

          setState(() => _currentView = ProfileView.main);
        },
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_rounded, color: Colors.redAccent, size: 22),
            SizedBox(width: 10),
            Text(
              'Sign Out Account',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressCard({
    required int index,
    required String type,
    required String address,
    required bool isDefault,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: isDefault
            ? Border.all(
                color: const Color(0xFF6366F1).withOpacity(0.3),
                width: 2,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.04),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  type == 'Home'
                      ? Icons.home_rounded
                      : type == 'Work'
                      ? Icons.work_rounded
                      : Icons.more_horiz_rounded,
                  color: const Color(0xFF6366F1),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                type,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              if (isDefault)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'DEFAULT',
                    style: TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            address,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13,
              height: 1.6,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildSmallIconButton(
                'Edit',
                Icons.edit_rounded,
                const Color(0xFF6366F1),
                () => _startEditingAddress(index),
              ),
              const SizedBox(width: 12),
              _buildSmallIconButton(
                'Delete',
                Icons.delete_outline_rounded,
                Colors.redAccent,
                () => _confirmDeleteAddress(index),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallIconButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubPageHeader(String title, VoidCallback onBack) {
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        margin: const EdgeInsets.only(top: 10, bottom: 15),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: IconButton(
                onPressed: onBack,
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Edit bank — form mein data fill karo
  void _startEditingBank(Map<String, dynamic> bank) {
    setState(() {
      _showBankForm = false;
      _editingBankId = bank['id']?.toString() ?? '';
      _accHolderController.text = bank['accountName'] ?? '';
      _bankNameController.text = bank['bankName'] ?? '';
      _accNumberController.text = bank['accountNo'] ?? '';
      _ifscController.text = bank['ifscCode'] ?? '';
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _confirmDeleteBank(Map<String, dynamic> bank) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 64,
                  width: 64,
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red.shade400,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Delete bank account?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Are you sure you want to delete ${bank['bankName']} account?',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context); // dialog band karo
                          final vm = context.read<AuthViewModel>();
                          final success = await vm.deleteBankDetail(
                            bank['id']?.toString() ?? '',
                          );
                          if (!mounted) return;
                          if (success) {
                            await _loadBankDetails(); // DB se fresh load
                            _showSuccessSnackBar('Bank account deleted!');
                          } else {
                            _showErrorSnackBar(
                              vm.errorMessage ?? 'Delete failed.',
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade400,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Delete',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleBankUpdate() async {
    if (!_bankFormKey.currentState!.validate()) return;

    final vm = context.read<AuthViewModel>();
    final isEdit = _editingBankId != null && _editingBankId!.isNotEmpty;

    bool success;

    if (isEdit) {
      success = await vm.updateBankDetail(
        id: _editingBankId!,
        userId: vm.loggedInUser?.id ?? '',
        accountName: _accHolderController.text.trim(),
        bankName: _bankNameController.text.trim(),
        accountNo: _accNumberController.text.trim(),
        ifscCode: _ifscController.text.trim(),
      );
    } else {
      success = await vm.saveBankDetails(
        userId: vm.loggedInUser?.id ?? '',
        accountName: _accHolderController.text.trim(),
        bankName: _bankNameController.text.trim(),
        accountNo: _accNumberController.text.trim(),
        ifscCode: _ifscController.text.trim(),
      );
    }

    if (!mounted) return;

    if (!success) {
      _showErrorSnackBar(vm.errorMessage ?? 'Bank details save failed.');
      return;
    }

    setState(() {
      _showBankForm = false;
      _editingBankId = null;
      _accHolderController.text = vm.loggedInUser?.name ?? '';
      _bankNameController.clear();
      _accNumberController.clear();
      _ifscController.clear();
    });

    await _loadBankDetails();
    _showSuccessSnackBar(
      isEdit ? 'Bank details updated!' : 'Bank details saved!',
    );
  }
}
