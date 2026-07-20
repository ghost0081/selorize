class FaqItem {
  final String question;
  final String answer;
  final String category;
  final int status;
  final int sortOrder;
  const FaqItem({
    required this.question,
    required this.answer,
    required this.category,
    required this.status,
    required this.sortOrder,
  });
  factory FaqItem.fromJson(Map<String, dynamic> json) {
    return FaqItem(
      question: _value(json, const [
        'question',
        'faqQuestion',
        'faq_question',
        'title',
        'q',
      ]),
      answer: _value(json, const [
        'answer',
        'faqAnswer',
        'faq_answer',
        'description',
        'content',
        'a',
      ]),
      category: _value(json, const [
        'category',
        'faqCategory',
        'faq_category',
        'type',
        'section',
      ]),
      status: int.tryParse(json['status']?.toString() ?? '') ?? 1,
      sortOrder: int.tryParse(json['sortOrder']?.toString() ?? '') ?? 0,
    );
  }
  bool get isActive => status == 1;

  static String _value(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key]?.toString().trim() ?? '';
      if (value.isNotEmpty && value.toLowerCase() != 'null') return value;
    }
    return '';
  }
}
