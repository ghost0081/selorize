class PriceCalculationResult {
  final int basePrice;
  final int finalPrice;

  const PriceCalculationResult({
    required this.basePrice,
    required this.finalPrice,
  });

  factory PriceCalculationResult.fromJson(Map<String, dynamic> response) {
    final data = response['data'];
    final basePrice = data is Map ? data['basePrice'] : response['basePrice'];
    final finalPrice = data is Map
        ? data['finalPrice'] ?? data['price'] ?? data['basePrice']
        : response['finalPrice'] ?? response['price'];

    final parsedFinalPrice = int.tryParse(finalPrice?.toString() ?? '') ?? 0;
    final parsedBasePrice =
        int.tryParse(basePrice?.toString() ?? '') ?? parsedFinalPrice;

    return PriceCalculationResult(
      basePrice: parsedBasePrice,
      finalPrice: parsedFinalPrice,
    );
  }
}
