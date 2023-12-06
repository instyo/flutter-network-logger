import 'package:dio/dio.dart' as dio;

import '../network_event.dart';
import '../network_logger.dart';

class DioNetworkLogger extends dio.Interceptor {
  final NetworkEventList eventList;
  final _requests = <dio.RequestOptions, NetworkEvent>{};

  DioNetworkLogger({NetworkEventList? eventList})
      : this.eventList = eventList ?? NetworkLogger.instance;

  @override
  Future<void> onRequest(
      dio.RequestOptions options, dio.RequestInterceptorHandler handler) async {
    super.onRequest(options, handler);
    eventList.add(_requests[options] = NetworkEvent.now(
      request: options.toRequest(),
      error: null,
      response: null,
    ));
    return Future.value(options);
  }

  @override
  void onResponse(
    dio.Response response,
    dio.ResponseInterceptorHandler handler,
  ) {
    super.onResponse(response, handler);
    var event = _requests[response.requestOptions];
    if (event != null) {
      _requests.remove(response.requestOptions);
      eventList.updated(event..response = response.toResponse());
    } else {
      eventList.add(NetworkEvent.now(
        request: response.requestOptions.toRequest(),
        response: response.toResponse(),
      ));
    }
  }

  @override
  void onError(dio.DioException err, dio.ErrorInterceptorHandler handler) {
    super.onError(err, handler);
    var event = _requests[err.requestOptions];
    if (event != null) {
      _requests.remove(err.requestOptions);
      eventList.updated(event..error = err.toNetworkError());
    } else {
      eventList.add(NetworkEvent.now(
        request: err.requestOptions.toRequest(),
        response: err.response?.toResponse(),
        error: err.toNetworkError(),
      ));
    }
  }
}

extension _RequestOptionsX on dio.RequestOptions {
  Request toRequest() => Request(
        baseUrl: baseUrl,
        uri: uri.toString(),
        path: path,
        queryParameters: queryParameters,
        data: data,
        method: method,
        headers: headers,
      );
}

extension _ResponseX on dio.Response {
  Response toResponse() => Response(
        data: data,
        statusCode: statusCode ?? -1,
        statusMessage: statusMessage ?? 'unkown',
        headers: Headers(
          headers.map.entries.fold<List<MapEntry<String, String>>>(
            [],
            (p, e) => p..addAll(e.value.map((v) => MapEntry(e.key, v))),
          ),
        ),
      );
}

extension _DioErrorX on dio.DioException {
  NetworkError toNetworkError() => NetworkError(
        message: message ?? 'Unknown error',
        data: response?.data,
        statusCode: response?.statusCode ?? 0,
        statusMessage: response?.statusMessage ?? "",
      );
}
