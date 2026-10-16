import 'package:flutter_test/flutter_test.dart';
import 'package:selorize/model/request/api_requests.dart';
import 'package:selorize/model/response/api_responses.dart';

void main() {
  test('price request keeps all selected option ids', () {
    final request = PriceCalculationRequest(
      modelId: '7',
      variantId: '16',
      selectedOptions: const ['61', '81'],
    ).toJson();

    expect(request['modelId'], '7');
    expect(request['variantId'], '16');
    expect(request['selectedOptions[]'], const ['61', '81']);
  });

  test('price response reads API data values', () {
    final result = PriceCalculationResult.fromJson({
      'status': 200,
      'data': {'basePrice': '4000', 'finalPrice': '3500'},
    });

    expect(result.basePrice, 4000);
    expect(result.finalPrice, 3500);
  });
}
