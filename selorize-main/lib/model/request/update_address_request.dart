class UpdateAddressRequest {
  final String id;
  final String userId;
  final String name;
  final String mobile;
  final String pincode;
  final String city;
  final String state;
  final String houseNo;
  final String street;
  final String addressType;

  const UpdateAddressRequest({
    required this.id,
    required this.userId,
    required this.name,
    required this.mobile,
    required this.pincode,
    required this.city,
    required this.state,
    required this.houseNo,
    required this.street,
    required this.addressType,
  });

  Map<String, String> toJson() {
    return {
      "tableName": "address",
      "act": "edit",
      "id": id,
      "userId": userId,
      "name": name,
      "mobile": mobile,
      "pincode": pincode,
      "city": city,
      "state": state,
      "houseNo": houseNo,
      "street": street,
      "addressType": addressType,
    };
  }
}
