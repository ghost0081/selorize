class EnquiryAnswerRequest {
  final String questionTitle;
  final String optionLabel;
  final String priceModifier;

  const EnquiryAnswerRequest({
    required this.questionTitle,
    required this.optionLabel,
    required this.priceModifier,
  });

  factory EnquiryAnswerRequest.fromMap(Map<String, dynamic> map) {
    return EnquiryAnswerRequest(
      questionTitle: map['questionTitle']?.toString() ?? '',
      optionLabel: map['optionLabel']?.toString() ?? '',
      priceModifier: map['priceModifier']?.toString() ?? '',
    );
  }
}

class SaveEnquiryRequest {
  final String modelId;
  final String variantId;
  final int basePrice;
  final int finalPrice;
  final String userId;
  final String customerName;
  final String customerMobile;
  final String customerEmail;
  final String address;
  final String bankDetail;
  final String latitude;
  final String longitude;
  final String pickupDateTime;
  final String bookingType;
  final List<EnquiryAnswerRequest> answers;
  final String coupon;
  final int couponPrice;

  const SaveEnquiryRequest({
    required this.modelId,
    required this.variantId,
    required this.basePrice,
    required this.finalPrice,
    required this.userId,
    required this.customerName,
    required this.customerMobile,
    required this.customerEmail,
    required this.address,
    required this.bankDetail,
    required this.latitude,
    required this.longitude,
    required this.pickupDateTime,
    required this.bookingType,
    required this.answers,
    this.coupon = '',
    this.couponPrice = 0,
  });

  Map<String, dynamic> toJson() {
    final payload = <String, dynamic>{
      "modelId": modelId.toString(),
      "variantId": variantId.toString(),
      "basePrice": basePrice.toString(),
      "finalPrice": finalPrice.toString(),
      "userId": userId.toString(),
      "customerName": customerName,
      "customerMobile": customerMobile,
      "customerEmail": customerEmail,
      "address": address,
      "bankDetail": bankDetail,
      "latitude": latitude,
      "longitude": longitude,
      "longtitude": longitude,
      "pickupDateTime": pickupDateTime,
      "bookingType": bookingType,
      "coupon": coupon,
      "couponPrice": couponPrice.toString(),
    };

    for (var index = 0; index < answers.length; index++) {
      final answer = answers[index];
      payload["answers[$index][questionTitle]"] = answer.questionTitle;
      payload["answers[$index][optionLabel]"] = answer.optionLabel;
      payload["answers[$index][priceModifier]"] = answer.priceModifier;
    }

    return payload;
  }
}
