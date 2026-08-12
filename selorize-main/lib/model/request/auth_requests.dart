class LoginRequest {
  final String mobile;
  final String password;

  const LoginRequest({required this.mobile, required this.password});

  Map<String, String> toJson() {
    return {"mobile": mobile, "password": password};
  }
}

class OtpRequest {
  final String mobile;

  const OtpRequest({required this.mobile});

  Map<String, String> toJson() {
    return {"mobile": mobile};
  }
}

class ForgotOtpRequest {
  final String emailOrMobile;

  const ForgotOtpRequest({required this.emailOrMobile});

  Map<String, String> toJson() {
    return {"email": emailOrMobile, "mobile": emailOrMobile};
  }
}

class SignUpRequest {
  final String mobile;
  final String email;
  final String name;
  final String createdAt;

  const SignUpRequest({
    required this.mobile,
    required this.email,
    required this.name,
    required this.createdAt,
  });

  Map<String, String> toJson() {
    return {
      "mobile": mobile,
      "email": email,
      "name": name,
      "created_at": createdAt,
    };
  }
}

class UpdatePasswordRequest {
  final String id;
  final String newPassword;
  final String confirmPassword;

  const UpdatePasswordRequest({
    required this.id,
    required this.newPassword,
    required this.confirmPassword,
  });

  Map<String, String> toJson() {
    return {
      "id": id,
      "newPassword": newPassword,
      "confirmPassword": confirmPassword,
    };
  }
}

class UserDetailRequest {
  final String id;

  const UserDetailRequest({required this.id});

  Map<String, String> toJson() {
    return {"id": id};
  }
}
