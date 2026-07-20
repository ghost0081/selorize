class GoogleRegisterRequest {
  final String name;
  final String email;
  final String mobile;
  final String googleId;
  final String createdAt;

  const GoogleRegisterRequest({
    required this.name,
    required this.email,
    required this.mobile,
    required this.googleId,
    required this.createdAt,
  });

  Map<String, String> toJson() {
    return {
      "tableName": "users",
      "act": "add",
      "name": name,
      "email": email,
      "mobile": mobile,
      "password": googleId,
      "token": googleId,
      "createdAt": createdAt,
    };
  }
}
