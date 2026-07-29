import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/response/api_response.dart';
import '../model/user_model.dart';
import '../repository/auth_repository.dart';
import '../service/fcm_token_service.dart';

enum AuthStep { idle, otpSent, otpVerified }

class AuthViewModel extends ChangeNotifier {
  final AuthRepository _repo = AuthRepository();

  static const String _userIdKey = 'logged_in_user_id';

  ApiResponse<UserModel> _userResponse = ApiResponse.loading();
  ApiResponse<UserModel> get userResponse => _userResponse;

  UserModel? _loggedInUser;
  UserModel? get loggedInUser => _loggedInUser;

  AuthStep _authStep = AuthStep.idle;
  AuthStep get authStep => _authStep;

  String? _receivedOtp;

  String? _forgotOtp;
  String? _forgotUserId;
  String? get forgotUserId => _forgotUserId;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _successMessage;
  String? get successMessage => _successMessage;

  bool _isCheckingSavedUser = true;
  bool get isCheckingSavedUser => _isCheckingSavedUser;

  Future<void> requestOtp(String mobile) async {
    _setLoading(true);
    _clearMessages();

    try {
      final otpResponse = await _repo.requestOtp(mobile);

      if (otpResponse.otp.isEmpty) {
        throw Exception('OTP was not returned by server.');
      }
      _receivedOtp = otpResponse.otp;
      _authStep = AuthStep.otpSent;
      _successMessage = otpResponse.message;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  bool verifyOtp(String otp) {
    _clearMessages();

    if (_receivedOtp == null || _receivedOtp!.isEmpty) {
      _errorMessage = 'Please request OTP first.';
      notifyListeners();
      return false;
    }

    if (otp.trim() != _receivedOtp) {
      _errorMessage = 'Invalid OTP. Please try again.';
      notifyListeners();
      return false;
    }

    _authStep = AuthStep.otpVerified;
    _successMessage = 'OTP verified successfully';
    notifyListeners();
    return true;
  }

  Future<bool> signUp({
    required String mobile,
    required String email,
    required String name,
    required String password,
  }) async {
    _setLoading(true);
    _clearMessages();

    try {
      if (_authStep != AuthStep.otpVerified) {
        throw Exception('Please verify OTP before sign-up.');
      }

      final user = await _repo.signUp(
        mobile: mobile,
        email: email,
        name: name,
        password: password,
      );

      final loggedInUser = user.id.isNotEmpty
          ? user
          : await _loadLoggedInUserFromLogin(
              mobile: mobile,
              password: password,
            );

      _loggedInUser = loggedInUser;
      _userResponse = ApiResponse.completed(loggedInUser);
      _authStep = AuthStep.idle;
      _receivedOtp = null;

      await _saveLogin(loggedInUser);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _userResponse = ApiResponse.error(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> login({required String mobile, required String password}) async {
    _setLoading(true);
    _clearMessages();

    try {
      final user = await _loadLoggedInUserFromLogin(
        mobile: mobile,
        password: password,
      );

      _loggedInUser = user;
      _userResponse = ApiResponse.completed(user);

      await _saveLogin(user);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _userResponse = ApiResponse.error(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchUserDetail(String id) async {
    _userResponse = ApiResponse.loading();
    notifyListeners();

    try {
      final user = await _repo.getUserDetail(id);
      _loggedInUser = user;
      _userResponse = ApiResponse.completed(user);
    } catch (e) {
      _userResponse = ApiResponse.error(e.toString());
    }

    notifyListeners();
  }

  Future<bool> sendForgotOtp(String emailOrMobile) async {
    _setLoading(true);
    _clearMessages();

    try {
      final otpResponse = await _repo.sendForgotOtp(emailOrMobile);

      if (otpResponse.otp.isEmpty) {
        throw Exception('OTP was not returned by server.');
      }

      if (otpResponse.userId.isEmpty) {
        throw Exception('User id was not returned by server.');
      }
      _forgotOtp = otpResponse.otp;
      _forgotUserId = otpResponse.userId;
      _successMessage = otpResponse.message;
      return true;
    } catch (e) {
      _forgotOtp = null;
      _forgotUserId = null;
      _errorMessage = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  bool verifyForgotOtp(String otp) {
    _clearMessages();

    if (_forgotOtp == null || _forgotOtp!.isEmpty) {
      _errorMessage = 'Please request OTP first.';
      notifyListeners();
      return false;
    }

    if (otp.trim() != _forgotOtp) {
      _errorMessage = 'Invalid OTP. Please try again.';
      notifyListeners();
      return false;
    }

    _successMessage = 'OTP verified successfully';
    notifyListeners();
    return true;
  }

  Future<bool> updatePassword({
    required String id,
    required String newPassword,
    required String confirmPassword,
  }) async {
    _setLoading(true);
    _clearMessages();

    try {
      if (newPassword.isEmpty || confirmPassword.isEmpty) {
        throw Exception('Please enter password');
      }

      if (newPassword != confirmPassword) {
        throw Exception('Passwords do not match');
      }

      final message = await _repo.updatePassword(
        id: id,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      );

      _successMessage = message;
      _forgotOtp = null;
      _forgotUserId = null;
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userIdKey);

    _loggedInUser = null;
    _userResponse = ApiResponse.loading();
    _authStep = AuthStep.idle;
    _receivedOtp = null;
    _forgotOtp = null;
    _forgotUserId = null;
    _clearMessages();

    notifyListeners();
  }

  Future<bool> deleteProfile({required String mobile}) async {
    _setLoading(true);
    _clearMessages();

    try {
      final id = _loggedInUser?.id ?? '';
      if (id.isEmpty) {
        throw Exception('User id not found. Please login again.');
      }

      await _repo.deleteProfile(id: id, mobile: mobile);
      await logout();
      _successMessage = 'Profile deleted successfully';
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> saveAddress({
    required String userId,
    required String name,
    required String mobile,
    required String pincode,
    required String city,
    required String state,
    required String houseNo,
    required String street,
    required String addressType,
  }) async {
    _setLoading(true);
    _clearMessages();

    try {
      if (userId.isEmpty) {
        throw Exception('User id not found. Please login again.');
      }

      await _repo.saveAddress(
        userId: userId,
        name: name,
        mobile: mobile,
        pincode: pincode,
        city: city,
        state: state,
        houseNo: houseNo,
        street: street,
        addressType: addressType,
      );

      _successMessage = 'Address saved successfully';
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateAddress({
    required String id,
    required String userId,
    required String name,
    required String mobile,
    required String pincode,
    required String city,
    required String state,
    required String houseNo,
    required String street,
    required String addressType,
  }) async {
    _setLoading(true);
    _clearMessages();

    try {
      if (id.isEmpty) throw Exception('Address id not found.');

      await _repo.updateAddress(
        id: id,
        userId: userId,
        name: name,
        mobile: mobile,
        pincode: pincode,
        city: city,
        state: state,
        houseNo: houseNo,
        street: street,
        addressType: addressType,
      );

      _successMessage = 'Address updated successfully';
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deleteAddress(String id) async {
    _setLoading(true);
    _clearMessages();
    try {
      if (id.isEmpty) throw Exception('Address id not found.');
      await _repo.deleteAddress(id);
      _successMessage = 'Address deleted successfully';
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> saveBankDetails({
    required String userId,
    required String accountName,
    required String bankName,
    required String accountNo,
    required String ifscCode,
  }) async {
    _setLoading(true);
    _clearMessages();

    try {
      if (userId.isEmpty) {
        throw Exception('User id not found. Please login again.');
      }

      await _repo.saveBankDetails(
        userId: userId,
        accountName: accountName,
        bankName: bankName,
        accountNo: accountNo,
        ifscCode: ifscCode,
      );

      _successMessage = 'Bank details saved successfully';
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateBankDetail({
    required String id,
    required String userId,
    required String accountName,
    required String bankName,
    required String accountNo,
    required String ifscCode,
  }) async {
    _setLoading(true);
    _clearMessages();
    try {
      if (id.isEmpty) throw Exception('Bank detail id not found.');
      await _repo.updateBankDetail(
        id: id,
        userId: userId,
        accountName: accountName,
        bankName: bankName,
        accountNo: accountNo,
        ifscCode: ifscCode,
      );
      _successMessage = 'Bank detail updated successfully';
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deleteBankDetail(String id) async {
    _setLoading(true);
    _clearMessages();
    try {
      if (id.isEmpty) throw Exception('Bank detail id not found.');
      await _repo.deleteBankDetail(id);
      _successMessage = 'Bank detail deleted successfully';
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateProfile({
    required String id,
    required String name,
    required String email,
    required String mobile,
    required String gender,
    required String aadharCard,
    String? aadharCardImageBase64,
    String? profileImageBase64,
  }) async {
    _setLoading(true);
    _clearMessages();

    try {
      if (id.isEmpty) {
        throw Exception('User id not found. Please login again.');
      }

      await _repo.updateProfile(
        id: id,
        name: name,
        email: email,
        mobile: mobile,
        gender: gender,
        aadharCard: aadharCard,
        aadharCardImageBase64: aadharCardImageBase64,
        profileImageBase64: profileImageBase64,
      );

      UserModel updatedUser;
      try {
        updatedUser = await _repo.getUserDetail(id);
      } catch (_) {
        updatedUser = UserModel(
          id: id,
          name: name,
          email: email,
          mobile: mobile,
          gender: gender,
          aadharCard: aadharCard,
          profileImage: profileImageBase64 ?? _loggedInUser?.profileImage ?? '',
        );
      }

      _loggedInUser = updatedUser;
      _userResponse = ApiResponse.completed(updatedUser);
      _successMessage = 'Profile updated successfully';
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void updateLocalUser({
    required String name,
    required String email,
    required String mobile,
  }) {
    final currentUser = _loggedInUser;
    if (currentUser == null) return;

    final updatedUser = UserModel(
      id: currentUser.id,
      name: name,
      email: email,
      mobile: mobile,
    );

    _loggedInUser = updatedUser;
    _userResponse = ApiResponse.completed(updatedUser);
    notifyListeners();
  }

  void resetStep() {
    _authStep = AuthStep.idle;
    _receivedOtp = null;
    _forgotOtp = null;
    _forgotUserId = null;
    _clearMessages();
    notifyListeners();
  }

  Future<void> loadSavedUser() async {
    _isCheckingSavedUser = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUserId = prefs.getString(_userIdKey);

      if (savedUserId == null || savedUserId.isEmpty) {
        _loggedInUser = null;
        return;
      }

      final user = await _repo.getUserDetail(savedUserId);
      _loggedInUser = user;
      _userResponse = ApiResponse.completed(user);
      await FcmTokenService.syncLatestToken(user.id);
    } catch (e) {
      _loggedInUser = null;
      _userResponse = ApiResponse.error(e.toString());
    } finally {
      _isCheckingSavedUser = false;
      notifyListeners();
    }
  }

  Future<void> refreshLoggedInUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = _loggedInUser?.id ?? prefs.getString(_userIdKey) ?? '';
      if (userId.isEmpty) return;

      final user = await _repo.getUserDetail(userId);
      _loggedInUser = user;
      _userResponse = ApiResponse.completed(user);
      await FcmTokenService.syncLatestToken(user.id);
      notifyListeners();
    } catch (e) {
      debugPrint('Refresh logged in user error: $e');
    }
  }

  Future<void> _saveLogin(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, user.id);
    await FcmTokenService.syncLatestToken(user.id);
  }

  String _extractUserId(Map<String, dynamic> response) {
    final idKeys = ['id', 'user_id', 'userId', 'userid'];

    String? visit(dynamic value) {
      if (value is Map) {
        for (final key in idKeys) {
          final id = value[key]?.toString();
          if (id != null && id.isNotEmpty) return id;
        }

        for (final nested in value.values) {
          final id = visit(nested);
          if (id != null && id.isNotEmpty) return id;
        }
      } else if (value is List) {
        for (final nested in value) {
          final id = visit(nested);
          if (id != null && id.isNotEmpty) return id;
        }
      }

      return null;
    }

    return visit(response) ?? '';
  }

  Future<UserModel> _loadLoggedInUserFromLogin({
    required String mobile,
    required String password,
  }) async {
    final response = await _repo.login(mobile: mobile, password: password);

    final id = _extractUserId(response);

    if (id.isNotEmpty) {
      return _repo.getUserDetail(id);
    }

    final data = response['data'] ?? response;
    final user = UserModel.fromJson(Map<String, dynamic>.from(data));
    if (user.id.isEmpty) {
      throw Exception('Account not found. Please create an account.');
    }

    return user;
  }

  Future<bool> loginWithGoogle(BuildContext context) async {
    _setLoading(true);
    _clearMessages();

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn.instance;

      await googleSignIn.initialize();

      // Login
      final GoogleSignInAccount googleUser = await googleSignIn.authenticate();

      // Get auth data
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      // Firebase credential
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      // Firebase sign in
      await FirebaseAuth.instance.signInWithCredential(credential);

      final firebaseUser = FirebaseAuth.instance.currentUser;

      if (firebaseUser == null) {
        throw Exception("Firebase login failed");
      }

      final result = await _repo.googleLogin(
        name: firebaseUser.displayName ?? '',
        email: firebaseUser.email ?? '',
        googleId: firebaseUser.uid,
      );

      final data = result['data'];

      final id = _extractUserId(
        data is Map ? Map<String, dynamic>.from(data) : {},
      );

      UserModel user;

      if (id.isNotEmpty) {
        user = await _repo.getUserDetail(id);
      } else {
        final email = firebaseUser.email ?? '';
        final rows = await _repo.getData(
          tableName: 'users',
          filter: {'email': email},
        );

        if (rows.isNotEmpty) {
          final fetchedId = rows.first['id']?.toString() ?? '';
          if (fetchedId.isNotEmpty) {
            user = await _repo.getUserDetail(fetchedId);
          } else {
            throw Exception(
              'User registered but ID not found. Please try again.',
            );
          }
        } else {
          throw Exception('Registration failed. Please try again.');
        }
      }

      _loggedInUser = user;
      _userResponse = ApiResponse.completed(user);

      await _saveLogin(user);

      if (user.mobile.isEmpty && context.mounted) {
        _showMobileInputSheet(context);
      }

      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _userResponse = ApiResponse.error(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void _showMobileInputSheet(BuildContext context) {
    final mobileController = TextEditingController();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 32),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'One last step!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Enter your mobile number for pickup coordination.',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: mobileController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '10-digit mobile number',
                    prefixIcon: const Icon(Icons.phone_android_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: Color(0xFF4A78A8),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final mobile = mobileController.text.trim();
                          if (mobile.length != 10) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please enter valid 10-digit mobile',
                                ),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }
                          setSheet(() => isSaving = true);
                          await updateMobileAfterGoogleLogin(mobile);
                          if (context.mounted) Navigator.pop(context);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Save & Continue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Skip for now',
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> updateMobileAfterGoogleLogin(String mobile) async {
    final id = _loggedInUser?.id ?? '';
    if (id.isEmpty) return;

    try {
      await _repo.updateProfile(
        id: id,
        name: _loggedInUser?.name ?? '',
        email: _loggedInUser?.email ?? '',
        mobile: mobile,
        gender: '',
        aadharCard: '',
        profileImageBase64: _loggedInUser?.profileImage,
      );

      _loggedInUser = UserModel(
        id: id,
        name: _loggedInUser?.name ?? '',
        email: _loggedInUser?.email ?? '',
        mobile: mobile,
        profileImage: _loggedInUser?.profileImage ?? '',
      );
      _userResponse = ApiResponse.completed(_loggedInUser!);
      notifyListeners();
    } catch (e) {
      debugPrint('updateMobile error: $e');
    }
  }

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }

  void _clearMessages() {
    _errorMessage = null;
    _successMessage = null;
  }
}
