import 'package:flutter/material.dart';

import '../l10n/app_localization.dart';
import 'offline_download_repository.dart';

void showTrackDownloadSnackBar(
  BuildContext context,
  DownloadTrackResult result,
) {
  final t = switch (result) {
    DownloadTrackResult.success => context.t('download.trackSaved'),
    DownloadTrackResult.alreadyDownloaded => context.t('download.alreadySaved'),
    DownloadTrackResult.inProgress => context.t('download.inProgress'),
    DownloadTrackResult.cacheLimitExceeded => context.t('download.cacheLimit'),
    DownloadTrackResult.notServerTrack => context.t('download.notServerTrack'),
    DownloadTrackResult.failed => context.t('download.failed'),
  };
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(behavior: SnackBarBehavior.floating, content: Text(t)),
  );
}

void showPlaylistDownloadSnackBar(
  BuildContext context,
  DownloadPlaylistResult result,
) {
  final t = switch (result) {
    DownloadPlaylistResult.success => context.t('download.playlistSaved'),
    DownloadPlaylistResult.partial => context.t('download.playlistPartial'),
    DownloadPlaylistResult.cacheLimitExceeded => context.t('download.cacheLimit'),
    DownloadPlaylistResult.failed => context.t('download.failed'),
  };
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(behavior: SnackBarBehavior.floating, content: Text(t)),
  );
}

enum DownloadFavoritesResult {
  success,
  partial,
  cacheLimitExceeded,
  nothingToDownload,
  failed,
}

void showFavoritesDownloadSnackBar(
  BuildContext context,
  DownloadFavoritesResult result,
) {
  final t = switch (result) {
    DownloadFavoritesResult.success => context.t('favorites.downloadAllDone'),
    DownloadFavoritesResult.partial => context.t('download.playlistPartial'),
    DownloadFavoritesResult.cacheLimitExceeded => context.t('download.cacheLimit'),
    DownloadFavoritesResult.nothingToDownload =>
      context.t('favorites.downloadAllNothing'),
    DownloadFavoritesResult.failed => context.t('download.failed'),
  };
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(behavior: SnackBarBehavior.floating, content: Text(t)),
  );
}
