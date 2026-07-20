class DeleteProfileRequest {
  final String id;
  final String mobile;

  const DeleteProfileRequest({required this.id, required this.mobile});

  Map<String, String> toJson() {
    return {"tableName": "users", "act": "edit", "id": id, "mobile": mobile};
  }
}
