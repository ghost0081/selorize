import '../user_model.dart';

class OtpResponse {
  final String otp;
  final String message;
  final String userId;
  final UserModel? user;

  const OtpResponse({
    required this.otp,
    required this.message,
    this.userId = '',
    this.user,
  });
}
