# mimusic

Flutter-приложение MiMusic — локальный плеер и UI под будущий сервер. Подробный контекст разработки: `project-context.local.md` (локально, не в git).

## Getting Started

```bash
flutter pub get
flutter run
```

### API (Ktor на ПК)

- При **Run из Android Studio** базовый URL и `adb reverse` подставляются из **`android/app/build.gradle.kts`**; на эмуляторе хост корректируется в **`MainActivity`** (см. `lib/core/network/api_config.dart`).
- **Wi‑Fi:** в **`android/local.properties`** добавь `flutter.apiBaseUrl=http://<IP_ПК>:8080`.
- Вручную: `flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8080` (после `adb reverse tcp:8080 tcp:8080` на USB).

Подробнее: в родительском каталоге репозитория — **`md/DEV_ANDROID_USB_AND_POSTGRES.md`**.

Общая документация Flutter: [docs.flutter.dev](https://docs.flutter.dev/).

---

## Планы по клиенту (roadmap)

### Совместное прослушивание: убрать «плейлисты комнаты» (`selectedPlaylists`)

Сейчас в коде есть поле **`selectedPlaylists`** в `ListeningRoomSession` и UI выбора плейлистов на экране создания комнаты (`listening_room_page.dart` и др.). На бэкенде **не планируется** отдельная сущность «плейлисты, прикреплённые к colisten-сессии» — это слишком затратно в разработке и поддержке.

**Намерение:** удалить эту механику на фронте: оставить только **очередь треков** в комнате и настройки прав / видимость. Упростить вызовы `ListeningRoomSession.instance.start(...)` (убрать параметр и состояние `selectedPlaylists`), подчистить виджеты выбора плейлистов для режима комнаты.

Детали целевой модели без этой таблицы: `md/BACKEND_CLIENT_ALIGNMENT.md` §1.7.4.
