import 'authenticated_dio.dart';

class PushApi {
  Future<void> registerToken(String token, {String platform = 'android'}) async {
    final dio = await createAuthenticatedDio();
    await dio.post<void>(
      '/push/register',
      data: {'token': token, 'platform': platform},
    );
  }

  Future<void> unregisterToken(String token) async {
    final dio = await createAuthenticatedDio();
    await dio.post<void>(
      '/push/unregister',
      data: {'token': token},
    );
  }
}
