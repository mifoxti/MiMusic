import 'package:flutter/foundation.dart';

import 'listening_history_entry.dart';

/// История прослушиваний. Сейчас — in-memory; позже заменить на реализацию с API + кэшем.
abstract class ListeningHistoryRepository extends ChangeNotifier {
  List<ListeningHistoryEntry> get entries;

  void recordPlayback({
    required String playablePath,
    required String title,
    String? artist,
    String? coverAssetPath,
    DateTime? playedAt,
  });

  void clear();
}
