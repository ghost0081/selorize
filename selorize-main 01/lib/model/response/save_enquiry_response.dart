class SaveEnquiryResponse {
  final Map<String, dynamic> raw;
  final String id;
  final String message;

  const SaveEnquiryResponse({
    required this.raw,
    required this.id,
    required this.message,
  });

  factory SaveEnquiryResponse.fromJson(Map<String, dynamic> json) {
    return SaveEnquiryResponse(
      raw: json,
      id: _extractId(json),
      message: json['message']?.toString() ?? '',
    );
  }

  static String _extractId(Map<String, dynamic> json) {
    const keys = ['id', 'enquiryId', 'enquiry_id'];

    String? visit(dynamic value) {
      if (value is Map) {
        for (final key in keys) {
          final id = value[key]?.toString();
          if (id != null && id.isNotEmpty) return id;
        }

        for (final nested in value.values) {
          final id = visit(nested);
          if (id != null && id.isNotEmpty) return id;
        }
      } else if (value is List) {
        for (final nested in value) {
          final id = visit(nested);
          if (id != null && id.isNotEmpty) return id;
        }
      }

      return null;
    }

    return visit(json) ?? '';
  }
}
