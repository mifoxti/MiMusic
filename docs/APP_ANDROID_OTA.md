# Android OTA (самообновление)

## Сервер

Каталог: `file_storage/releases/android/` (или `FILE_STORAGE_ROOT/releases/android`).

1. Соберите release APK: `flutter build apk --release`.
2. Положите APK как `latest.apk` (или имя из `apkFileName` в манифесте).
3. Обновите `manifest.json` — версия и при необходимости текст релиза:

```json
{
  "versionName": "1.0.1",
  "versionCode": 2,
  "apkFileName": "latest.apk",
  "releaseNotes": "Исправления и улучшения",
  "mandatory": false,
  "minVersionCode": null
}
```

`versionCode` должен быть **больше**, чем `buildNumber` в `pubspec.yaml` (`version: x.y.z+N`).

SHA-256 APK сервер **считает сам** при запуске (и снова, если файл APK заменили без перезапуска — по дате изменения файла).

## API (без авторизации)

- `GET /app/update/android?versionCode=&versionName=` — JSON с `updateAvailable`, `downloadUrl`, `sha256`, …
- `GET /app/releases/android/{file}` — раздача APK

## Клиент

- Автопроверка после входа в основной shell (не чаще раза в 12 часов).
- **Настройки → Обновления** — ручная проверка, загрузка, установка.
- Только Android; установка через системный инсталлер.
