import 'package:flutter/foundation.dart';
import 'package:selorize/data/network/network_api_service.dart';
import 'package:selorize/model/request/api_requests.dart';
import 'package:selorize/model/response/api_responses.dart';
import 'package:selorize/res/api_constants.dart';

import '../model/user_model.dart';

class AuthRepository {
  final NetworkApiService _apiService = NetworkApiService();

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
    required String password,
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
        password: password,
        createdAt: createdAt,
      ).toJson(),
    );

    return UserModel.fromJson(_extractUserJson(response));
  }

  Future<Map<String, dynamic>> login({
    required String mobile,
    required String password,
  }) async {
    final response = await _apiService.getPostApiRequest(
      ApiConstants.LOGIN,
      LoginRequest(mobile: mobile, password: password).toJson(),
    );

    return Map<String, dynamic>.from(response);
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
      for (final mapping in mappings) {
        final questionId =
            mapping['questionId']?.toString() ??
            mapping['question_id']?.toString() ??
            '';
        final sequence = int.tryParse(mapping['sequence']?.toString() ?? '');
        if (questionId.isNotEmpty && sequence != null) {
          sequenceByQuestionId[questionId] = sequence;
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
      }

      final indexedQuestions = parsedQuestions.asMap().entries.toList();
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
    final idKeys = ['id', 'user_id', 'userId', 'userid'];

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
