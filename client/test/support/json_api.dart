import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

class JsonApi implements HttpClientAdapter {
  JsonApi(this.respond);

  final Object? Function(RequestOptions, Map<String, dynamic>?) respond;
  final requests = <(RequestOptions, Map<String, dynamic>?)>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final bytes = await requestStream?.expand((bytes) => bytes).toList();
    final body = bytes == null || bytes.isEmpty
        ? null
        : jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    requests.add((options, body));
    return ResponseBody.fromString(
      jsonEncode(respond(options, body)),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
