class UpdateProfileRequest {
  final String id;
  final String name;
  final String email;
  final String mobile;
  final String gender;
  final String aadharCard;
  final String? aadharCardImageBase64;
  final String? profileImageBase64;

  const UpdateProfileRequest({
    required this.id,
    required this.name,
    required this.email,
    required this.mobile,
    required this.gender,
    required this.aadharCard,
    this.aadharCardImageBase64,
    this.profileImageBase64,
  });

  Map<String, String> toJson() {
    final payload = <String, String>{
      "tableName": "users",
      "act": "edit",
      "id": id,
      "name": name,
      "email": email,
      "mobile": mobile,
      "gender": gender,
      "aadharCard": aadharCard,
    };

    if (aadharCardImageBase64 != null && aadharCardImageBase64!.isNotEmpty) {
      payload["folderName"] = "users";
      payload["aadharCardImage"] = aadharCardImageBase64!;
    }

    if (profileImageBase64 != null && profileImageBase64!.isNotEmpty) {
      payload["profileImage"] = profileImageBase64!;
    }

    return payload;
  }
}
