import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:plowth_app/features/auth/auth_session.dart';

void main() {
  group('AuthSession', () {
    tearDown(() {
      AuthSession.dioFactoryOverride = null;
    });

    test('keeps stored tokens when refresh fails offline', () async {
      SharedPreferences.setMockInitialValues({
        AuthSession.accessTokenKey: _buildExpiredJwt(),
        AuthSession.refreshTokenKey: 'refresh-token',
      });
      AuthSession.dioFactoryOverride =
          () =>
              Dio(BaseOptions(baseUrl: 'http://localhost:8000'))
                ..httpClientAdapter = _MockHttpClientAdapter((options) async {
                  throw DioException(
                    requestOptions: options,
                    type: DioExceptionType.connectionError,
                    error: 'offline',
                  );
                });

      await expectLater(
        AuthSession.authorize(Dio()),
        throwsA(
          isA<AuthSessionException>().having(
            (error) => error.message,
            'message',
            contains('offline'),
          ),
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AuthSession.accessTokenKey), isNotNull);
      expect(prefs.getString(AuthSession.refreshTokenKey), 'refresh-token');
    });

    test('clears stored tokens when refresh is rejected', () async {
      SharedPreferences.setMockInitialValues({
        AuthSession.accessTokenKey: _buildExpiredJwt(),
        AuthSession.refreshTokenKey: 'refresh-token',
      });
      AuthSession.dioFactoryOverride =
          () =>
              Dio(BaseOptions(baseUrl: 'http://localhost:8000'))
                ..httpClientAdapter = _MockHttpClientAdapter((options) async {
                  return _jsonResponse({
                    'detail': 'invalid refresh',
                  }, statusCode: 401);
                });

      await expectLater(
        AuthSession.authorize(Dio()),
        throwsA(
          isA<AuthSessionException>().having(
            (error) => error.message,
            'message',
            contains('expired'),
          ),
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AuthSession.accessTokenKey), isNull);
      expect(prefs.getString(AuthSession.refreshTokenKey), isNull);
    });
  });
}

String _buildExpiredJwt() {
  final header = base64Url
      .encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})))
      .replaceAll('=', '');
  final payload = base64Url
      .encode(
        utf8.encode(
          jsonEncode({
            'sub': 'user-1',
            'exp':
                DateTime.now()
                    .toUtc()
                    .subtract(const Duration(minutes: 5))
                    .millisecondsSinceEpoch ~/
                1000,
          }),
        ),
      )
      .replaceAll('=', '');
  return '$header.$payload.signature';
}

ResponseBody _jsonResponse(
  Map<String, Object?> payload, {
  int statusCode = 200,
}) {
  return ResponseBody.fromString(
    jsonEncode(payload),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

class _MockHttpClientAdapter implements HttpClientAdapter {
  _MockHttpClientAdapter(this._handler);

  final Future<ResponseBody> Function(RequestOptions options) _handler;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return _handler(options);
  }
}
