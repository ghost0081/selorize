class PriceCalculationRequest {
  final String modelId;
  final String variantId;
  final List<String> selectedOptions;

  const PriceCalculationRequest({
    required this.modelId,
    required this.variantId,
    required this.selectedOptions,
  });

  Map<String, dynamic> toJson() {
    return {
      "modelId": modelId,
      "variantId": variantId,
      "selectedOptions[]": selectedOptions,
    };
  }
}
