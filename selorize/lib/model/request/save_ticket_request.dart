class SaveTicketRequest {
  final String userId;
  final String issue;
  final String subject;
  final String detail;
  final String createdAt;

  const SaveTicketRequest({
    required this.userId,
    required this.issue,
    required this.subject,
    required this.detail,
    required this.createdAt,
  });

  Map<String, String> toJson() {
    return {
      "tableName": "tickets",
      "act": "add",
      "userId": userId,
      "issue": issue,
      "subject": subject,
      "detail": detail,
      "status": "0",
      "createdAt": createdAt,
    };
  }
}
