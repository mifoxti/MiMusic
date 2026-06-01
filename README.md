# 🎧 MiMusic — твоя персональная музыкальная вселенная

![Platform](https://img.shields.io/badge/platform-Android%20%7C%20Windows-blue)
![Flutter](https://img.shields.io/badge/Flutter-3.11+-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.11+-0175C2?logo=dart&logoColor=white)
![Backend](https://img.shields.io/badge/server-Ktor-087CFA)
![Status](https://img.shields.io/badge/status-active-brightgreen)

**MiMusic** — кроссплатформенный клиент для стриминга музыки с собственным backend.  
Ты не просто слушаешь — ты проживаешь музыку: делишься мыслями, собираешь плейлисты, слушаешь вместе с друзьями и загружаешь свои треки в студию.

> Обновления и инструкции — в [Telegram-канале](https://t.me/evtumi).

---

## ✨ Возможности

| Область | Что умеет приложение |
|--------|----------------------|
| **Плеер** | Очередь, shuffle/repeat, мини- и полноэкранный режим, палитра из обложки, эквалайзер, системное медиа-уведомление с лайками |
| **Каталог** | Поиск треков и исполнителей, чарты, рекомендации на главной, история прослушивания |
| **Социальное** | Лайки, друзья, лента «мыслей», публичные профили, уведомления |
| **Colisten** | Совместное прослушивание: открытые комнаты, синхронизация хоста и гостей по WebSocket |
| **Студия** | Загрузка треков на сервер, обложки, жанры, статистика прослушиваний |
| **Офлайн** | Скачивание треков и плейлистов с учётом лимита кеша |
| **Обновления** | OTA для Android — проверка и установка новых сборок без магазина |
| **UI** | Стеклянный (glass) интерфейс, тёмная тема, RU/EN локализация |

---

## 🛠 Технологии

### Клиент (этот репозиторий)

- **Flutter** + **Dart 3.11+**
- **just_audio** + **audio_service** — воспроизведение и фоновый плеер
- **Dio** — REST API с авторизацией
- **web_socket_channel** — colisten в реальном времени
- **shared_preferences**, **path_provider** — настройки и локальные файлы
- **flutter_local_notifications** — медиа-уведомления

### Сервер (отдельный репозиторий `mimusicback-master`)

- **Ktor 3** + **Exposed** + **PostgreSQL**
- Транскод аудио в AAC (ffmpeg), стрим с **Range**, обложки по URL
- JWT-сессии, загрузки треков/аватаров/обложек, colisten API

---

## 📦 Структура проекта

```
MiMusic/
├── lib/
│   ├── core/                 # Аудио, сеть, auth, offline, colisten, OTA
│   ├── features/             # Home, player, onboarding, friends
│   ├── presentation/         # Shell, страницы, glass-виджеты, профиль
│   └── main.dart
├── assets/                   # Иконки, изображения, демо-музыка
├── android/                  # Gradle, adb reverse, API base URL
└── README.md
```

---

## 🚀 Быстрый старт

```bash
flutter pub get
flutter run
```

### Подключение к backend (Ktor на ПК)

| Сценарий | Настройка |
|----------|-----------|
| **USB + Android Studio** | `adb reverse tcp:8080 tcp:8080`; базовый URL задаётся в `android/app/build.gradle.kts` |
| **Wi‑Fi** | В `android/local.properties`: `flutter.apiBaseUrl=http://<IP_ПК>:8080` |
| **Вручную** | `flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8080` |

---

## 📊 О проекте

- **~180** Dart-файлов в `lib/`, **~43k** строк кода — активная разработка
- Единая медиатека: любой залогиненный пользователь слушает любой трек и добавляет его в **свои** плейлисты
- Обложки, аватары и аудио хранятся на сервере; клиент кеширует изображения и офлайн-треки локально

---

## 📚 Ссылки

- [Документация Flutter](https://docs.flutter.dev/)
- [Канал обновлений в Telegram](https://t.me/evtumi)

---

*Музыка начинается там, где слова уже не справляются — пусть MiMusic поможет тебе найти нужную мелодию.* 🎶
