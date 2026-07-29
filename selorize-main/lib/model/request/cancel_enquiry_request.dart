class CancelEnquiryRequest {
  final String id;
  final String cancelReason;

  const CancelEnquiryRequest({required this.id, required this.cancelReason});

  Map<String, String> toJson() {
    return {
      "tableName": "enquiries",
      "act": "edit",
      "id": id,
      "status": "5",
      "cancelReason": cancelReason,
    };
  }
}
