class UpdateFcmTokenRequest {
  final String id;
  final String fcmToken;

  const UpdateFcmTokenRequest({required this.id, required this.fcmToken});

  Map<String, String> toJson() {
    return {
      "tableName": "users",
      "act": "edit",
      "id": id,
      "fcmToken": fcmToken,
    };
  }
}
