import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../error/failures.dart';
import 'session_manager.dart';

/// Cliente HTTP para la API REST de Macsa CMMS.
class ApiClient {
  ApiClient({
    String? baseUrl,
    http.Client? httpClient,
    SessionManager? sessionManager,
  }) : _baseUrl = baseUrl ?? defaultBaseUrl,
       _httpClient = httpClient ?? http.Client(),
       _sessionManager = sessionManager ?? SessionManager.instance;

  final String _baseUrl;
  final http.Client _httpClient;
  final SessionManager _sessionManager;

  static String get defaultBaseUrl {
    if (kIsWeb) return 'http://localhost:3000/api';
    return 'http://192.168.1.33:3000/api';
  }

  String get baseUrl => _baseUrl;

  Map<String, String> _buildHeaders({Map<String, String>? extraHeaders}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final token = _sessionManager.token;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }
    return headers;
  }

  Uri _buildUri(String path, [Map<String, dynamic>? queryParameters]) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final urlString = '$_baseUrl$cleanPath';
    final uri = Uri.parse(urlString);

    if (queryParameters == null || queryParameters.isEmpty) {
      return uri;
    }

    final queryMap = <String, String>{};
    for (final entry in queryParameters.entries) {
      if (entry.value != null) {
        if (entry.value is DateTime) {
          queryMap[entry.key] = (entry.value as DateTime).toIso8601String();
        } else {
          queryMap[entry.key] = entry.value.toString();
        }
      }
    }

    return uri.replace(queryParameters: queryMap);
  }

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(path, queryParameters);
    try {
      final response = await _httpClient.get(
        uri,
        headers: _buildHeaders(extraHeaders: headers),
      );
      return _handleResponse(response);
    } on SocketException catch (_) {
      throw const ServerFailure(
        message: 'No se pudo establecer conexión con el servidor de la API.',
      );
    } on Failure {
      rethrow;
    } catch (e) {
      throw ServerFailure(message: 'Error de red: ${e.toString()}');
    }
  }

  Future<dynamic> post(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(path, queryParameters);
    try {
      final response = await _httpClient.post(
        uri,
        headers: _buildHeaders(extraHeaders: headers),
        body: body != null ? jsonEncode(body) : null,
      );
      return _handleResponse(response);
    } on SocketException catch (_) {
      throw const ServerFailure(
        message: 'No se pudo establecer conexión con el servidor de la API.',
      );
    } on Failure {
      rethrow;
    } catch (e) {
      throw ServerFailure(message: 'Error de red: ${e.toString()}');
    }
  }

  Future<dynamic> put(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(path, queryParameters);
    try {
      final response = await _httpClient.put(
        uri,
        headers: _buildHeaders(extraHeaders: headers),
        body: body != null ? jsonEncode(body) : null,
      );
      return _handleResponse(response);
    } on SocketException catch (_) {
      throw const ServerFailure(
        message: 'No se pudo establecer conexión con el servidor de la API.',
      );
    } on Failure {
      rethrow;
    } catch (e) {
      throw ServerFailure(message: 'Error de red: ${e.toString()}');
    }
  }

  Future<dynamic> patch(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(path, queryParameters);
    try {
      final response = await _httpClient.patch(
        uri,
        headers: _buildHeaders(extraHeaders: headers),
        body: body != null ? jsonEncode(body) : null,
      );
      return _handleResponse(response);
    } on SocketException catch (_) {
      throw const ServerFailure(
        message: 'No se pudo establecer conexión con el servidor de la API.',
      );
    } on Failure {
      rethrow;
    } catch (e) {
      throw ServerFailure(message: 'Error de red: ${e.toString()}');
    }
  }

  Future<dynamic> delete(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(path, queryParameters);
    try {
      final response = await _httpClient.delete(
        uri,
        headers: _buildHeaders(extraHeaders: headers),
        body: body != null ? jsonEncode(body) : null,
      );
      return _handleResponse(response);
    } on SocketException catch (_) {
      throw const ServerFailure(
        message: 'No se pudo establecer conexión con el servidor de la API.',
      );
    } on Failure {
      rethrow;
    } catch (e) {
      throw ServerFailure(message: 'Error de red: ${e.toString()}');
    }
  }

  dynamic _handleResponse(http.Response response) {
    dynamic decodedBody;
    if (response.body.isNotEmpty) {
      try {
        decodedBody = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        decodedBody = response.body;
      }
    }

    final statusCode = response.statusCode;
    if (statusCode >= 200 && statusCode < 300) {
      return decodedBody;
    }

    String errorMessage = 'Error en el servidor ($statusCode)';
    if (decodedBody is Map<String, dynamic>) {
      errorMessage =
          decodedBody['message']?.toString() ??
          decodedBody['error']?.toString() ??
          errorMessage;

      if (decodedBody['errors'] is List) {
        final errList = (decodedBody['errors'] as List)
            .map((e) => e is Map ? (e['msg'] ?? e['message']) : e.toString())
            .whereType<String>()
            .toList();
        if (errList.isNotEmpty) {
          errorMessage = errList.join('. ');
        }
      }
    }

    if (statusCode == 401) {
      throw UnauthorizedFailure(message: errorMessage);
    } else if (statusCode == 403 || statusCode == 423) {
      throw ValidationFailure(message: errorMessage);
    } else if (statusCode == 404) {
      throw ValidationFailure(message: errorMessage);
    } else if (statusCode == 409) {
      throw ValidationFailure(message: errorMessage);
    } else if (statusCode == 400 || statusCode == 422) {
      throw ValidationFailure(message: errorMessage);
    } else {
      throw ServerFailure(message: errorMessage);
    }
  }
}
