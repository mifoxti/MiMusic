import '../cache/remote_image_cache.dart';
import '../network/playlists_api.dart';

/// Сбрасывает HTTP/дисковый кэш [GET /me/avatar] и подгружает свежий файл после upload.
Future<void> refreshCachedMeAvatar({int cacheRevision = 0}) async {
  await RemoteImageCache.instance.evictUrl(meAvatarUrl());
  if (cacheRevision != 0) {
    await RemoteImageCache.instance.evictUrl(meAvatarUrl(cacheRevision: cacheRevision));
  }
  await RemoteImageCache.instance.fileForUrl(
    meAvatarUrl(cacheRevision: cacheRevision),
    requireAuth: true,
    forceRefresh: true,
  );
}
