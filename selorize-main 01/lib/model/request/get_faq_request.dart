class GetFaqRequest {
  final String category;

  const GetFaqRequest({this.category = ''});

  Map<String, String> toJson() {
    return {if (category.isNotEmpty) "category": category};
  }
}
