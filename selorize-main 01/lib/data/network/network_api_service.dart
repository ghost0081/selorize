import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:selorize/data/exception/api_exceptions.dart';
import 'base_api_service.dart';

class NetworkApiService extends BaseApiService {
  final Map<String, String> _postHeaders = {
    "Content-Type": "application/x-www-form-urlencoded",
    "Accept": "application/json",
    "Cache-Control": "no-cache",
  };

  final Map<String, String> _getHeaders = {
    "Accept": "application/json",
    "Cache-Control": "no-cache",
  };

  @override
  Future<dynamic> getGetApiRequest(String url) async {
    return _requestWithRetry(
      () => http
          .get(Uri.parse(url), headers: _getHeaders)
          .timeout(const Duration(seconds: 20)),
    );
  }

  @override
  Future<dynamic> getPostApiRequest(String url, dynamic data) async {
    final body = _toFormEncoded(data);

    debugPrint("POST -> $url");
    debugPrint("FORM BODY -> $body");

    return _requestWithRetry(
      () => http
          .post(Uri.parse(url), headers: _postHeaders, body: body)
          .timeout(const Duration(seconds: 20)),
    );
  }

  Future<dynamic> _requestWithRetry(
    Future<http.Response> Function() request,
  ) async {
    Object? lastError;

    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final response = await request();
        if (response.statusCode >= 500 && attempt < 2) {
          await Future<void>.delayed(
            Duration(milliseconds: 450 * (attempt + 1)),
          );
          continue;
        }
        return returnResponse(response);
      } on SocketException catch (e) {
        lastError = e;
      } on TimeoutException catch (e) {
        lastError = e;
      } on http.ClientException catch (e) {
        lastError = e;
      } on HttpException catch (e) {
        lastError = e;
      } catch (e) {
        if (e is ApiException) rethrow;
        lastError = e;
      }

      if (attempt < 2) {
        await Future<void>.delayed(Duration(milliseconds: 450 * (attempt + 1)));
      }
    }

    if (lastError is SocketException) {
      throw FetchDataException("No internet connection.");
    }
    if (lastError is TimeoutException) {
      throw FetchDataException("Request timed out. Please try again.");
    }
    if (lastError is HttpException) {
      throw FetchDataException("HTTP error occurred.");
    }
    if (lastError is http.ClientException) {
      throw FetchDataException(
        "Network connection was interrupted. Please try again.",
      );
    }

    throw FetchDataException("Unexpected error: ${lastError.toString()}");
  }

  String _toFormEncoded(dynamic data) {
    if (data is Map) {
      final parts = <String>[];

      for (final entry in data.entries) {
        final key = entry.key.toString();
        final value = entry.value;

        if (value is Iterable && value is! String) {
          for (final item in value) {
            parts.add(
              '${Uri.encodeComponent(key)}=${Uri.encodeComponent(item?.toString() ?? '')}',
            );
          }
        } else {
          parts.add(
            '${Uri.encodeComponent(key)}=${Uri.encodeComponent(value?.toString() ?? '')}',
          );
        }
      }

      return parts.join('&');
    }
    return data?.toString() ?? '';
  }

  String _stripDebugBar(String body) {
    body = body.trim();

    if (body.startsWith('{') || body.startsWith('[')) {
      final closingIndex = _findJsonClosingIndex(body);
      if (closingIndex != -1) return body.substring(0, closingIndex + 1);
    }

    return body;
  }

  int _findJsonClosingIndex(String body) {
    final stack = <String>[];
    var inString = false;
    var escaped = false;

    for (var i = 0; i < body.length; i++) {
      final char = body[i];

      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (char == '\\') {
          escaped = true;
        } else if (char == '"') {
          inString = false;
        }
        continue;
      }

      if (char == '"') {
        inString = true;
      } else if (char == '{') {
        stack.add('}');
      } else if (char == '[') {
        stack.add(']');
      } else if ((char == '}' || char == ']') && stack.isNotEmpty) {
        final expected = stack.removeLast();
        if (char != expected) return -1;
        if (stack.isEmpty) return i;
      }
    }

    return -1;
  }

  dynamic _safeDecode(String rawBody) {
    if (rawBody.trim().isEmpty) {
      throw BadRequestException("Empty response from server.");
    }
    final cleaned = _stripDebugBar(rawBody);
    debugPrint("CLEANED BODY: $cleaned");
    try {
      return jsonDecode(cleaned);
    } catch (_) {
      throw BadRequestException("Could not parse server response.");
    }
  }

  String _message(
    dynamic decoded, {
    String fallback = 'Something went wrong.',
  }) {
    if (decoded is Map) {
      return decoded['message']?.toString() ??
          decoded['error']?.toString() ??
          decoded['msg']?.toString() ??
          fallback;
    }
    return fallback;
  }

  dynamic returnResponse(http.Response response) {
    debugPrint("STATUS: ${response.statusCode}  URL: ${response.request?.url}");

    final rawBody = utf8.decode(response.bodyBytes);

    debugPrint("RAW: ${rawBody.substring(0, rawBody.length.clamp(0, 400))}");

    final decoded = _safeDecode(rawBody);

    final innerStatus = decoded is Map
        ? (decoded['status']?.toString() ?? '')
        : '';

    switch (response.statusCode) {
      case 200:
      case 201:
        if (innerStatus == '400' ||
            innerStatus == '404' ||
            innerStatus == 'error' ||
            innerStatus == 'false') {
          throw BadRequestException(_message(decoded));
        }
        return decoded;

      case 400:
      case 404:
        throw BadRequestException(_message(decoded));

      case 401:
      case 403:
        throw UnauthorisedException("Unauthorised. Please login again.");

      case 500:
        throw ApiInternalException(
          _message(decoded, fallback: "Server error. Please try again later."),
        );

      default:
        throw FetchDataException(
          "Unexpected error. Status: ${response.statusCode}",
        );
    }
  }
}
