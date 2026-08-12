import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:selorize/data/network/network_api_service.dart';
import 'package:selorize/model/request/api_requests.dart';
import 'package:selorize/model/response/api_responses.dart';
import 'package:selorize/res/api_constants.dart';

import '../model/user_model.dart';
import '../service/device_data_cache.dart';

class AuthRepository {
  final NetworkApiService _apiService = NetworkApiService();
  static final Map<String, List<Map<String, dynamic>>> _getDataCache = {};
  static final Map<String, Future<List<Map<String, dynamic>>>>
  _getDataInFlight = {};

  Future<OtpResponse> requestOtp(String mobile) async {
    final response = await _apiService.getPostApiRequest(
      ApiConstants.SIGNUP_OTP,
      OtpRequest(mobile: mobile).toJson(),
    );

    return OtpResponse(
      otp: response['otp']?.toString() ?? '',
      message: response['message']?.toString() ?? 'OTP sent successfully',
      userId: _extractUserId(Map<String, dynamic>.from(response)),
    );
  }

  Future<OtpResponse> sendForgotOtp(String emailOrMobile) async {
    final response = await _apiService.getPostApiRequest(
      ApiConstants.FORGOT,
      ForgotOtpRequest(emailOrMobile: emailOrMobile).toJson(),
    );

    return OtpResponse(
      otp: response['otp']?.toString() ?? '',
      message: response['message']?.toString() ?? 'OTP sent successfully',
      userId: _extractUserId(Map<String, dynamic>.from(response)),
    );
  }

  Future<UserModel> signUp({
    required String mobile,
    required String email,
    required String name,
  }) async {
    final now = DateTime.now();
    final createdAt =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    final response = await _apiService.getPostApiRequest(
      ApiConstants.SIGNUP,
      SignUpRequest(
        mobile: mobile,
        email: email,
        name: name,
        createdAt: createdAt,
      ).toJson(),
    );

    final responseMap = Map<String, dynamic>.from(response);
    final userId = _extractUserId(responseMap);

    if (userId.isNotEmpty) {
      return getUserDetail(userId);
    }

    return UserModel.fromJson(_extractUserJson(response));
  }

  Future<OtpResponse> requestLoginOtp(String mobile) async {
    final response = await _apiService.getPostApiRequest(
      ApiConstants.LOGIN_OTP,
      {'mobile': mobile},
    );

    final rawMap = Map<String, dynamic>.from(response);
    
    // Attempt to extract user data from the response. The backend might send it at the root or under 'data' or 'user'
    UserModel? userModel;
    try {
      if (rawMap.containsKey('data') && rawMap['data'] != null) {
        userModel = UserModel.fromJson(_extractUserJson(rawMap['data']));
      } else if (rawMap.containsKey('user') && rawMap['user'] != null) {
        userModel = UserModel.fromJson(_extractUserJson(rawMap['user']));
      } else if (rawMap.containsKey('id')) {
        // Flat response
        userModel = UserModel.fromJson(_extractUserJson(rawMap));
      }
    } catch (e) {
      debugPrint("Error extracting user data from login OTP: $e");
    }

    return OtpResponse(
      otp: rawMap['otp']?.toString() ?? '',
      message: rawMap['message']?.toString() ?? 'OTP sent successfully',
      userId: _extractUserId(rawMap),
      user: userModel,
    );
  }

  Future<String> updatePassword({
    required String id,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final response = await _apiService.getPostApiRequest(
      ApiConstants.UPDATE_PASSWORD,
      UpdatePasswordRequest(
        id: id,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      ).toJson(),
    );

    return response['message']?.toString() ?? 'Password updated successfully';
  }

  Future<UserModel> getUserDetail(String id) async {
    final response = await _apiService.getPostApiRequest(
      ApiConstants.USER_DETAIL,
      UserDetailRequest(id: id).toJson(),
    );

    return UserModel.fromJson(_extractUserJson(response));
  }

  Future<Map<String, dynamic>> updateProfile({
    required String id,
    required String name,
    required String email,
    required String mobile,
    required String gender,
    required String aadharCard,
    String? aadharCardImageBase64,
    String? profileImageBase64,
  }) async {
    final payload = UpdateProfileRequest(
      id: id,
      name: name,
      email: email,
      mobile: mobile,
      gender: gender,
      aadharCard: aadharCard,
      aadharCardImageBase64: aadharCardImageBase64,
      profileImageBase64: profileImageBase64,
    ).toJson();

    debugPrint('updateProfile payload keys => ${payload.keys.toList()}');

    final response = await _apiService.getPostApiRequest(
      ApiConstants.CREATE_FUNCTION,
      payload,
    );

    return Map<String, dynamic>.from(response);
  }

  Future<Map<String, dynamic>> updateFcmToken({
    required String id,
    required String fcmToken,
  }) async {
    final payload = UpdateFcmTokenRequest(id: id, fcmToken: fcmToken).toJson();

    debugPrint('updateFcmToken payload => userId=$id');

    final response = await _apiService.getPostApiRequest(
      ApiConstants.CREATE_FUNCTION,
      payload,
    );

    return Map<String, dynamic>.from(response);
  }

  Future<Map<String, dynamic>> deleteProfile({
    required String id,
    required String mobile,
  }) async {
    final payload = DeleteProfileRequest(id: id, mobile: mobile).toJson();

    debugPrint('deleteProfile payload => $payload');

    final response = await _apiService.getPostApiRequest(
      ApiConstants.CREATE_FUNCTION,
      payload,
    );

    return Map<String, dynamic>.from(response);
  }

  Future<Map<String, dynamic>> saveAddress({
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
    final payload = SaveAddressRequest(
      userId: userId,
      name: name,
      mobile: mobile,
      pincode: pincode,
      city: city,
      state: state,
      houseNo: houseNo,
      street: street,
      addressType: addressType,
    ).toJson();

    debugPrint('saveAddress payload => $payload');

    final response = await _apiService.getPostApiRequest(
      ApiConstants.CREATE_FUNCTION,
      payload,
    );

    return Map<String, dynamic>.from(response);
  }

  Future<Map<String, dynamic>> saveBankDetails({
    required String userId,
    required String accountName,
    required String bankName,
    required String accountNo,
    required String ifscCode,
  }) async {
    final payload = SaveBankDetailsRequest(
      userId: userId,
      accountName: accountName,
      bankName: bankName,
      accountNo: accountNo,
      ifscCode: ifscCode,
    ).toJson();

    debugPrint('saveBankDetails payload => $payload');

    final response = await _apiService.getPostApiRequest(
      ApiConstants.CREATE_FUNCTION,
      payload,
    );

    return Map<String, dynamic>.from(response);
  }

  Future<List<Map<String, dynamic>>> getData({
    required String tableName,
    Map<String, dynamic> filter = const {},
  }) async {
    final cacheKey = _getDataCacheKey(tableName, filter);
    final existingRequest = _getDataInFlight[cacheKey];
    if (existingRequest != null) {
      try {
        return await existingRequest;
      } catch (e) {
        final cachedRows = _getDataCache[cacheKey];
        if (cachedRows != null && cachedRows.isNotEmpty) {
          debugPrint(
            'Using cached in-flight rows for $cacheKey after error: $e',
          );
          return List<Map<String, dynamic>>.from(cachedRows);
        }
        final persistentRows = await _loadPersistentGetDataCache(
          tableName,
          filter,
        );
        if (persistentRows.isNotEmpty) return persistentRows;
        rethrow;
      }
    }

    final request = _fetchDataRows(tableName: tableName, filter: filter);
    _getDataInFlight[cacheKey] = request;

    try {
      final rows = await request;
      if (rows.isNotEmpty) {
        _getDataCache[cacheKey] = List<Map<String, dynamic>>.from(rows);
        _savePersistentGetDataCache(tableName, filter, rows);
      }
      return rows;
    } catch (e) {
      final cachedRows = _getDataCache[cacheKey];
      if (cachedRows != null && cachedRows.isNotEmpty) {
        debugPrint('Using cached getData rows for $cacheKey after error: $e');
        return List<Map<String, dynamic>>.from(cachedRows);
      }
      final persistentRows = await _loadPersistentGetDataCache(
        tableName,
        filter,
      );
      if (persistentRows.isNotEmpty) return persistentRows;
      rethrow;
    } finally {
      _getDataInFlight.remove(cacheKey);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchDataRows({
    required String tableName,
    required Map<String, dynamic> filter,
  }) async {
    final response = await _apiService.getPostApiRequest(
      ApiConstants.GET_DATA,
      GetDataRequest(tableName: tableName, filter: filter).toJson(),
    );

    debugPrint("RAW RESPONSE for $tableName => $response");

    final rows = response['message'] ?? response['data'] ?? [];

    if (rows is List) {
      return rows
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    }

    return <Map<String, dynamic>>[];
  }

  String _getDataCacheKey(String tableName, Map<String, dynamic> filter) {
    final normalizedFilter = Map<String, dynamic>.from(filter);
    final sortedKeys =
        normalizedFilter.keys.map((key) => key.toString()).toList()..sort();
    final sortedFilter = <String, dynamic>{};
    for (final key in sortedKeys) {
      sortedFilter[key] = normalizedFilter[key];
    }
    return '$tableName:${jsonEncode(sortedFilter)}';
  }

  bool _canPersistGetData(String tableName, Map<String, dynamic> filter) {
    if (filter.isNotEmpty) return false;
    return tableName == 'brand' ||
        tableName == 'series' ||
        tableName == 'model' ||
        tableName == 'modelVariant';
  }

  Future<List<Map<String, dynamic>>> _loadPersistentGetDataCache(
    String tableName,
    Map<String, dynamic> filter,
  ) async {
    if (!_canPersistGetData(tableName, filter)) return <Map<String, dynamic>>[];

    final rows = await DeviceDataCache.loadTable(tableName);
    if (rows.isNotEmpty) {
      _getDataCache[_getDataCacheKey(tableName, filter)] =
          List<Map<String, dynamic>>.from(rows);
      debugPrint('Using persistent getData rows for $tableName');
    }
    return rows;
  }

  void _savePersistentGetDataCache(
    String tableName,
    Map<String, dynamic> filter,
    List<Map<String, dynamic>> rows,
  ) {
    if (!_canPersistGetData(tableName, filter)) return;
    unawaited(DeviceDataCache.saveTable(tableName, rows));
  }

  Future<Map<String, String>> getSupportContact() async {
    final rows = await getData(tableName: 'contact');
    if (rows.isEmpty) return <String, String>{};

    final row = rows.first;
    return {
      'mobile': row['mobile']?.toString().trim() ?? '',
      'whatsapp': row['whatsapp']?.toString().trim() ?? '',
      'email': row['email']?.toString().trim() ?? '',
    };
  }

  Future<List<FaqItem>> getFaq({String category = ''}) async {
    final response = await _apiService.getPostApiRequest(
      ApiConstants.GET_FAQ,
      GetFaqRequest(category: category).toJson(),
    );

    debugPrint("RAW RESPONSE for faq => $response");

    final rows = response is Map
        ? (response['data'] is List
              ? response['data']
              : response['faq'] is List
              ? response['faq']
              : response['message'] is List
              ? response['message']
              : [])
        : response;

    if (rows is List) {
      final faqs = rows
          .whereType<Map>()
          .map((row) => FaqItem.fromJson(Map<String, dynamic>.from(row)))
          .where((faq) => faq.question.isNotEmpty && faq.answer.isNotEmpty)
          .where((faq) => faq.isActive)
          .toList();

      faqs.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return faqs;
    }

    return <FaqItem>[];
  }

  Future<List<Map<String, dynamic>>> getModelQuestions(String modelId) async {
    final results = await Future.wait([
      _apiService.getPostApiRequest(
        ApiConstants.GET_MODEL_QUESTIONS,
        ModelQuestionsRequest(modelId: modelId).toJson(),
      ),
      getData(tableName: 'modelQuestions', filter: {'modelId': modelId}),
    ]);

    final response = results[0] as Map;
    final mappings = results[1] as List<Map<String, dynamic>>;
    final questions = response['message'] ?? response['data'] ?? [];

    if (questions is List) {
      final parsedQuestions = questions
          .whereType<Map>()
          .map((question) => Map<String, dynamic>.from(question))
          .toList();

      final sequenceByQuestionId = <String, int>{};
      final mappedQuestionIds = <String>{};
      final enabledByQuestionId = <String, bool>{};

      for (final mapping in mappings) {
        final questionId =
            mapping['questionId']?.toString() ??
            mapping['question_id']?.toString() ??
            mapping['id']?.toString() ??
            '';
        if (questionId.isNotEmpty) {
          mappedQuestionIds.add(questionId);
          final sequence = int.tryParse(mapping['sequence']?.toString() ?? '');
          if (sequence != null) {
            sequenceByQuestionId[questionId] = sequence;
          }
          final rawStatus =
              mapping['status'] ??
              mapping['enabled'] ??
              mapping['isDefault'] ??
              mapping['is_default'] ??
              mapping['default'] ??
              mapping['active'] ??
              mapping['isSelected'] ??
              mapping['is_selected'];
          if (rawStatus != null) {
            final val = rawStatus.toString().trim().toLowerCase();
            enabledByQuestionId[questionId] =
                val == 'yes' ||
                val == 'y' ||
                val == 'true' ||
                val == '1' ||
                val == 'active' ||
                val == 'enabled' ||
                val == 'selected';
          }
        }
      }

      for (final question in parsedQuestions) {
        final questionId =
            question['id']?.toString() ??
            question['questionId']?.toString() ??
            question['question_id']?.toString() ??
            '';
        final mappedSequence = sequenceByQuestionId[questionId];
        if (mappedSequence != null) {
          question['sequence'] = mappedSequence;
        }
        if (enabledByQuestionId.containsKey(questionId)) {
          question['mappingEnabled'] = enabledByQuestionId[questionId];
        }
      }

      var filteredQuestions = parsedQuestions;
      if (mappedQuestionIds.isNotEmpty) {
        filteredQuestions = parsedQuestions.where((question) {
          final questionId =
              question['id']?.toString() ??
              question['questionId']?.toString() ??
              question['question_id']?.toString() ??
              '';
          if (!mappedQuestionIds.contains(questionId)) return false;
          if (enabledByQuestionId[questionId] == false) return false;
          return true;
        }).toList();
      }

      final indexedQuestions = filteredQuestions.asMap().entries.toList();
      indexedQuestions.sort((a, b) {
        final aSequence = _questionSequence(a.value);
        final bSequence = _questionSequence(b.value);
        final sequenceComparison = aSequence.compareTo(bSequence);
        return sequenceComparison != 0
            ? sequenceComparison
            : a.key.compareTo(b.key);
      });

      return indexedQuestions.map((entry) => entry.value).toList();
    }

    return <Map<String, dynamic>>[];
  }

  int _questionSequence(Map<String, dynamic> question) {
    final rawSequence =
        question['sequence'] ??
        question['sortOrder'] ??
        question['sort_order'] ??
        question['questionSequence'] ??
        question['question_sequence'];
    final sequence = int.tryParse(rawSequence?.toString() ?? '');
    return sequence != null && sequence > 0 ? sequence : 2147483647;
  }

  Future<PriceCalculationResult> calculatePrice({
    required String modelId,
    required String variantId,
    required List<String> selectedOptions,
  }) async {
    debugPrint(
      'calculatePrice payload => modelId: $modelId, variantId: $variantId, selectedOptions[]: $selectedOptions',
    );

    final response = await _apiService.getPostApiRequest(
      ApiConstants.CALCULATE_PRICE,
      PriceCalculationRequest(
        modelId: modelId,
        variantId: variantId,
        selectedOptions: selectedOptions,
      ).toJson(),
    );

    debugPrint('calculatePrice response => $response');
    return PriceCalculationResult.fromJson(Map<String, dynamic>.from(response));
  }

  Future<Map<String, dynamic>> saveEnquiry({
    required String modelId,
    required String variantId,
    required int basePrice,
    required int finalPrice,
    required String userId,
    required String customerName,
    required String customerMobile,
    required String customerEmail,
    required String address,
    required String bankDetail,
    required String latitude,
    required String longitude,
    required String pickupDateTime,
    required String bookingType,
    required List<Map<String, dynamic>> answers,
    String coupon = '',
    int couponPrice = 0,
  }) async {
    final payload = SaveEnquiryRequest(
      modelId: modelId,
      variantId: variantId,
      basePrice: basePrice,
      finalPrice: finalPrice,
      userId: userId,
      customerName: customerName,
      customerMobile: customerMobile,
      customerEmail: customerEmail,
      address: address,
      bankDetail: bankDetail,
      latitude: latitude,
      longitude: longitude,
      pickupDateTime: pickupDateTime,
      bookingType: bookingType,
      answers: answers.map(EnquiryAnswerRequest.fromMap).toList(),
      coupon: coupon,
      couponPrice: couponPrice,
    ).toJson();

    debugPrint('saveEnquiry payload => $payload');
    debugPrint(
      'saveEnquiry latitude=${payload["latitude"]} | longitude=${payload["longitude"]} | longtitude=${payload["longtitude"]}',
    );

    final response = await _apiService.getPostApiRequest(
      ApiConstants.SAVE_ENQUIRY,
      payload,
    );
    return Map<String, dynamic>.from(response);
  }

  Map<String, dynamic> _extractUserJson(dynamic response) {
    final data = response is Map ? response['data'] : null;

    if (data is List && data.isNotEmpty && data.first is Map) {
      return Map<String, dynamic>.from(data.first);
    }

    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    return <String, dynamic>{};
  }

  String _extractUserId(Map<String, dynamic> response) {
    final idKeys = ['id', 'user_id', 'userId', 'userid', 'insertId', 'lastId'];

    String? visit(dynamic value) {
      if (value is Map) {
        for (final key in idKeys) {
          final id = value[key]?.toString();

          if (id != null && id.isNotEmpty) {
            return id;
          }
        }

        for (final nested in value.values) {
          final id = visit(nested);

          if (id != null && id.isNotEmpty) {
            return id;
          }
        }
      } else if (value is List) {
        for (final nested in value) {
          final id = visit(nested);

          if (id != null && id.isNotEmpty) {
            return id;
          }
        }
      }

      return null;
    }

    return visit(response) ?? '';
  }

  Future<Map<String, dynamic>> updateAddress({
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
    final payload = UpdateAddressRequest(
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
    ).toJson();

    final response = await _apiService.getPostApiRequest(
      ApiConstants.CREATE_FUNCTION,
      payload,
    );

    return Map<String, dynamic>.from(response);
  }

  Future<Map<String, dynamic>> updateBankDetail({
    required String id,
    required String userId,
    required String accountName,
    required String bankName,
    required String accountNo,
    required String ifscCode,
  }) async {
    final payload = UpdateBankDetailRequest(
      id: id,
      userId: userId,
      accountName: accountName,
      bankName: bankName,
      accountNo: accountNo,
      ifscCode: ifscCode,
    ).toJson();
    final response = await _apiService.getPostApiRequest(
      ApiConstants.CREATE_FUNCTION,
      payload,
    );
    return Map<String, dynamic>.from(response);
  }

  Future<Map<String, dynamic>> deleteBankDetail(String id) async {
    final payload = DeleteRecordRequest(
      tableName: "bankDetail",
      id: id,
    ).toJson();
    final response = await _apiService.getPostApiRequest(
      ApiConstants.CREATE_FUNCTION,
      payload,
    );
    return Map<String, dynamic>.from(response);
  }

  Future<Map<String, dynamic>> deleteAddress(String id) async {
    final payload = DeleteRecordRequest(tableName: "address", id: id).toJson();
    final response = await _apiService.getPostApiRequest(
      ApiConstants.CREATE_FUNCTION,
      payload,
    );
    return Map<String, dynamic>.from(response);
  }

  Future<Map<String, dynamic>> cancelEnquiry({
    required String id,
    required String cancelReason,
  }) async {
    final payload = CancelEnquiryRequest(
      id: id,
      cancelReason: cancelReason,
    ).toJson();

    debugPrint('cancelEnquiry payload => $payload');

    final response = await _apiService.getPostApiRequest(
      ApiConstants.CREATE_FUNCTION,
      payload,
    );

    return Map<String, dynamic>.from(response);
  }

  Future<Map<String, dynamic>> googleLogin({
    required String name,
    required String email,
    required String googleId,
    String mobile = '',
    String profileImage = '',
  }) async {
    final existing = await _apiService.getPostApiRequest(
      ApiConstants.GET_DATA,
      GetDataRequest(tableName: "users", filter: {"email": email}).toJson(),
    );

    final rows = existing['message'] ?? existing['data'] ?? [];
    final userExists = rows is List && rows.isNotEmpty;

    if (userExists) {
      final user = Map<String, dynamic>.from(
        rows.first is Map ? rows.first : {},
      );
      return {'status': 'login', 'data': user};
    } else {
      final now = DateTime.now();
      final createdAt =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

      final response = await _apiService.getPostApiRequest(
        ApiConstants.CREATE_FUNCTION,
        GoogleRegisterRequest(
          name: name,
          email: email,
          mobile: mobile,
          googleId: googleId,
          createdAt: createdAt,
        ).toJson(),
      );
      return {'status': 'register', 'data': response};
    }
  }

  Future<Map<String, dynamic>> saveTicket({
    required String userId,
    required String issue,
    required String subject,
    required String detail,
  }) async {
    final now = DateTime.now();
    final createdAt =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    final payload = SaveTicketRequest(
      userId: userId,
      issue: issue,
      subject: subject,
      detail: detail,
      createdAt: createdAt,
    ).toJson();

    debugPrint('saveTicket payload => $payload');

    final response = await _apiService.getPostApiRequest(
      ApiConstants.CREATE_FUNCTION,
      payload,
    );

    return Map<String, dynamic>.from(response);
  }
}
