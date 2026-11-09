import 'dart:typed_data';
import 'dart:convert';

import 'package:dio/dio.dart';

class FakeApi implements HttpClientAdapter {
  FakeApi(this.respond);
  final Future<ResponseBody> Function(RequestOptions) respond;

  static ResponseBody json(Object? data, [int status = 200]) =>
      ResponseBody.fromString(
        jsonEncode(data),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => respond(options);

  @override
  void close({bool force = false}) {}
}
