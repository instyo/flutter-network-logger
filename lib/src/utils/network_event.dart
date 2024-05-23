import 'package:intl/intl.dart';

/// Network event log entry.

enum LogNetworkStatus { loading, success, error }

class NetworkEvent {
  NetworkEvent({
    this.request,
    this.response,
    this.error,
    this.timestamp,
    this.timeRequest,
  });

  NetworkEvent.now({
    this.request,
    this.response,
    this.error,
    this.timeRequest,
  }) : timestamp = DateTime.now();

  Request? request;
  Response? response;
  NetworkError? error;
  DateTime? timestamp;
  num? timeRequest;

  String get dateFormat =>
      DateFormat("dd LLLL yyyy HH:mm:ss").format(timestamp ?? DateTime.now());

  LogNetworkStatus get status => error != null
      ? LogNetworkStatus.error
      : response == null
          ? LogNetworkStatus.loading
          : LogNetworkStatus.success;
}

/// Used for storing [Request] and [Response] headers.
class Headers {
  Headers(
    Iterable<MapEntry<String, String>> entries,
  ) : entries = entries.toList();

  Headers.fromMap(
    Map<String, String> map,
  ) : entries = map.entries as List<MapEntry<String, String>>;

  final List<MapEntry<String, String>> entries;

  bool get isNotEmpty => entries.isNotEmpty;
  bool get isEmpty => entries.isEmpty;

  Iterable<T> map<T>(T Function(String key, String value) cb) =>
      entries.map((e) => cb(e.key, e.value));
}

/// Http request details.
class Request {
  Request({
    required this.baseUrl,
    required this.uri,
    required this.method,
    this.headers,
    required this.path,
    this.queryParameters,
    this.data,
  });

  final String baseUrl;
  final String uri;
  final String method;
  final Map<String, dynamic>? headers;
  final dynamic data;
  final String path;
  final Map<String, dynamic>? queryParameters;

  String get authorizationToken =>
      (headers?["authorization"] != null) ? headers!["authorization"] : "";
}

/// Http response details.
class Response {
  Response({
    required this.headers,
    required this.statusCode,
    required this.statusMessage,
    this.data,
  });

  final Headers headers;
  final int statusCode;
  final String statusMessage;
  final dynamic data;
}

/// Network error details.
class NetworkError {
  NetworkError({
    required this.message,
    required this.data,
    required this.statusCode,
    required this.statusMessage,
  });

  final String message;

  final dynamic data;

  final int statusCode;

  final String statusMessage;

  @override
  String toString() => message;
}
