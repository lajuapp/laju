import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../config/env_config.dart';

class ApiResponse<T> {
  final int statusCode;
  final T? data;
  final dynamic rawJson;
  final String? errorMessage;
  final bool isSuccess;

  const ApiResponse({
    required this.statusCode,
    this.data,
    this.rawJson,
    this.errorMessage,
    required this.isSuccess,
  });

  factory ApiResponse.success(int statusCode, T? data, [dynamic rawJson]) {
    return ApiResponse(
      statusCode: statusCode,
      data: data,
      rawJson: rawJson,
      isSuccess: true,
    );
  }

  factory ApiResponse.error(int statusCode, String message, [dynamic rawJson]) {
    return ApiResponse(
      statusCode: statusCode,
      errorMessage: message,
      rawJson: rawJson,
      isSuccess: false,
    );
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final dynamic details;

  ApiException({
    required this.statusCode,
    required this.message,
    this.details,
  });

  @override
  String toString() => 'ApiException [$statusCode]: $message';
}

class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);

  @override
  String toString() => 'NetworkException: $message';
}

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  final HttpClient _httpClient = HttpClient()
    ..connectionTimeout = const Duration(seconds: 15)
    ..badCertificateCallback = (cert, host, port) => true;

  String? _authToken;
  String? _deviceId;
  String? _userId;

  String? get authToken => _authToken;
  String? get deviceId => _deviceId;
  String? get userId => _userId;

  void Function(String reason)? onAccountSuspended;
  void Function()? onUnauthorized;
  void Function(String token)? onAuthChanged;
  void Function()? onAuthCleared;

  void setAuth({
    required String token,
    String? deviceId,
    String? userId,
  }) {
    _authToken = token;
    if (deviceId != null) _deviceId = deviceId;
    if (userId != null) _userId = userId;
    onAuthChanged?.call(token);
  }

  void clearAuth() {
    _authToken = null;
    _deviceId = null;
    _userId = null;
    onAuthCleared?.call();
  }

  /// Check if the backend API is currently reachable
  Future<bool> isBackendReachable() async {
    try {
      final base = EnvConfig.instance.apiBaseUrl;
      final uri = Uri.parse('$base/health');
      final request = await _httpClient.getUrl(uri).timeout(const Duration(seconds: 2));
      final response = await request.close().timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Uri _buildUri(String path, [Map<String, String>? queryParams]) {
    final base = EnvConfig.instance.apiBaseUrl;
    final normalizedBase = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final fullUrl = '$normalizedBase$normalizedPath';

    final uri = Uri.parse(fullUrl);
    if (queryParams != null && queryParams.isNotEmpty) {
      return uri.replace(queryParameters: {
        ...uri.queryParameters,
        ...queryParams,
      });
    }
    return uri;
  }

  void _applyHeaders(HttpClientRequest request) {
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8');
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');

    if (_authToken != null && _authToken!.isNotEmpty) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_authToken');
    }
    if (_deviceId != null && _deviceId!.isNotEmpty) {
      request.headers.set('x-device-id', _deviceId!);
    }
  }

  Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, String>? queryParams,
    T Function(dynamic json)? fromJson,
    Duration? timeout,
  }) async {
    return _sendRequest<T>('GET', path, queryParams: queryParams, fromJson: fromJson, timeoutOverride: timeout);
  }

  Future<ApiResponse<T>> post<T>(
    String path, {
    dynamic body,
    Map<String, String>? queryParams,
    T Function(dynamic json)? fromJson,
    Duration? timeout,
  }) async {
    return _sendRequest<T>('POST', path, body: body, queryParams: queryParams, fromJson: fromJson, timeoutOverride: timeout);
  }

  Future<ApiResponse<T>> patch<T>(
    String path, {
    dynamic body,
    Map<String, String>? queryParams,
    T Function(dynamic json)? fromJson,
    Duration? timeout,
  }) async {
    return _sendRequest<T>('PATCH', path, body: body, queryParams: queryParams, fromJson: fromJson, timeoutOverride: timeout);
  }

  Future<ApiResponse<T>> delete<T>(
    String path, {
    dynamic body,
    Map<String, String>? queryParams,
    T Function(dynamic json)? fromJson,
    Duration? timeout,
  }) async {
    return _sendRequest<T>('DELETE', path, body: body, queryParams: queryParams, fromJson: fromJson, timeoutOverride: timeout);
  }

  Future<ApiResponse<T>> _sendRequest<T>(
    String method,
    String path, {
    dynamic body,
    Map<String, String>? queryParams,
    T Function(dynamic json)? fromJson,
    Duration? timeoutOverride,
  }) async {
    final uri = _buildUri(path, queryParams);
    final timeout = timeoutOverride ?? EnvConfig.instance.apiTimeout;

    try {
      final HttpClientRequest request;
      switch (method.toUpperCase()) {
        case 'GET':
          request = await _httpClient.getUrl(uri).timeout(timeout);
          break;
        case 'POST':
          request = await _httpClient.postUrl(uri).timeout(timeout);
          break;
        case 'PATCH':
          request = await _httpClient.patchUrl(uri).timeout(timeout);
          break;
        case 'DELETE':
          request = await _httpClient.deleteUrl(uri).timeout(timeout);
          break;
        default:
          throw ArgumentError('Unsupported HTTP method: $method');
      }

      _applyHeaders(request);

      if (body != null) {
        final encodedBody = utf8.encode(jsonEncode(body));
        request.add(encodedBody);
      }

      final response = await request.close().timeout(timeout);
      final responseBody = await utf8.decodeStream(response).timeout(timeout);

      dynamic parsedJson;
      if (responseBody.isNotEmpty) {
        try {
          parsedJson = jsonDecode(responseBody);
        } catch (_) {
          parsedJson = responseBody;
        }
      }

      final statusCode = response.statusCode;
      final isSuccess = statusCode >= 200 && statusCode < 300;

      if (isSuccess) {
        T? parsedData;
        if (fromJson != null && parsedJson != null) {
          parsedData = fromJson(parsedJson);
        } else if (parsedJson is T) {
          parsedData = parsedJson;
        }
        return ApiResponse.success(statusCode, parsedData, parsedJson);
      } else {
        if (statusCode == 401) {
          onUnauthorized?.call();
        }
        String errorMsg = 'HTTP error $statusCode';
        if (parsedJson is Map<String, dynamic>) {
          if (statusCode == 403 && parsedJson['error'] == 'ACCOUNT_SUSPENDED') {
            final reason = parsedJson['reason']?.toString() ?? 'Pelanggaran ketentuan layanan';
            onAccountSuspended?.call(reason);
          }
          if (parsedJson['message'] != null) {
            if (parsedJson['message'] is List) {
              errorMsg = (parsedJson['message'] as List).join(', ');
            } else {
              errorMsg = parsedJson['message'].toString();
            }
          } else if (parsedJson['error'] != null) {
            errorMsg = parsedJson['error'].toString();
          }
        }
        return ApiResponse.error(statusCode, errorMsg, parsedJson);
      }
    } on SocketException catch (e) {
      debugPrint('[ApiClient] SocketException for $method $uri: ${e.message}');
      return ApiResponse.error(0, 'Cannot connect to backend server at ${uri.host}:${uri.port}');
    } on HttpException catch (e) {
      debugPrint('[ApiClient] HttpException: ${e.message}');
      return ApiResponse.error(0, e.message);
    } catch (e) {
      debugPrint('[ApiClient] Unexpected error for $method $uri: $e');
      return ApiResponse.error(0, e.toString());
    }
  }
}
