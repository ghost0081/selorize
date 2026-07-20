class SaveBankDetailsRequest {
  final String userId;
  final String accountName;
  final String bankName;
  final String accountNo;
  final String ifscCode;

  const SaveBankDetailsRequest({
    required this.userId,
    required this.accountName,
    required this.bankName,
    required this.accountNo,
    required this.ifscCode,
  });

  Map<String, String> toJson() {
    return {
      "tableName": "bankDetail",
      "act": "add",
      "userId": userId,
      "accountName": accountName,
      "bankName": bankName,
      "accountNo": accountNo,
      "ifscCode": ifscCode,
    };
  }
}

class UpdateBankDetailRequest {
  final String id;
  final String userId;
  final String accountName;
  final String bankName;
  final String accountNo;
  final String ifscCode;

  const UpdateBankDetailRequest({
    required this.id,
    required this.userId,
    required this.accountName,
    required this.bankName,
    required this.accountNo,
    required this.ifscCode,
  });

  Map<String, String> toJson() {
    return {
      "tableName": "bankDetail",
      "act": "edit",
      "id": id,
      "userId": userId,
      "accountName": accountName,
      "bankName": bankName,
      "accountNo": accountNo,
      "ifscCode": ifscCode,
    };
  }
}
