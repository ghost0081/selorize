class ModelQuestionsRequest {
  final String modelId;

  const ModelQuestionsRequest({required this.modelId});

  Map<String, String> toJson() {
    return {"modelId": modelId};
  }
}
