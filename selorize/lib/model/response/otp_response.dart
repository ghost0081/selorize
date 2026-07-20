class OtpResponse {
  final String otp;
  final String message;
  final String userId;

  const OtpResponse({
    required this.otp,
    required this.message,
    this.userId = '',
  });
}
