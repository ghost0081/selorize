class ApiException implements Exception {
  final String? message;
  final String? prefix;

  ApiException([this.message, this.prefix]);

  @override
  String toString() => "${prefix ?? ''}${message ?? ''}";
}

class FetchDataException extends ApiException {
  FetchDataException([String? message])
      : super(message, "Communication Error: ");
}

class BadRequestException extends ApiException {
  BadRequestException([String? message])
      : super(message, "");
}

class UnauthorisedException extends ApiException {
  UnauthorisedException([String? message])
      : super(message, "Unauthorised: ");
}

class InvalidInputException extends ApiException {
  InvalidInputException([String? message])
      : super(message, "Invalid Input: ");
}

class ApiNotRespondingException extends ApiException {
  ApiNotRespondingException([String? message])
      : super(message, "API Not Responding: ");
}

class ApiInternalException extends ApiException {
  ApiInternalException([String? message])
      : super(message, "Server Error: ");
}