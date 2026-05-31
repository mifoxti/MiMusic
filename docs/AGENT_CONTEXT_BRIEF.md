# MiMusic — краткий контекст для нового агента

**Назначение:** вставить в новый чат, когда в основном диалоге закончился контекст. Этот файл **самодостаточен** по домену и путям; детали схемы и таблиц — в полной спецификации ниже.

**Полная спецификация БД / colisten / уведомлений / деплоя:** `md/BACKEND_CLIENT_ALIGNMENT.md` (читать при реализации миграций и API).

**Поэтапный порядок работ (с чего начать и что за чем):** `md/IMPLEMENTATION_ROADMAP.md` (в т.ч. **готовность экранов** — таблица «Готовность экранов (Flutter UI)» в начале файла).

**Клиент (Flutter), локальный контекст:** `MiMusic/project-context.local.md` (в `.gitignore`).

**Статус (актуализировано, 2026-05-29):** закрыт all-in блок social+colisten+upload:
- notifications API + экран уведомлений на remote;
- публичный профиль: обложки плейлистов, корректный `srv:{id}` переход, `recentThoughts`;
- thoughts: `GET /thoughts/feed`, `POST /thoughts`, `GET /users/{id}/thoughts`; Flutter без моков;
- ~~colisten: `GET /colisten/rooms/open`, `POST /colisten/room` с control-флагами, WS host_state / guest по правам, `stateVersion` / `controlSeq`, in-memory `ColistenRoomManager`; host+guest sync и гостевые команды — **готово** (e2e на двух устройствах)~~;
- friends: `GET /friends` возвращает `activeColistenRoomId`;
- upload: прием mp3/wav/m4a, транскод в AAC(m4a) через ffmpeg, ffprobe metadata best-effort, stream content-type/range для m4a.

**Colisten:** ~~этап 8 закрыт~~ — комнаты работают как задумано (создание, join, синхронизация, права, команды хоста и гостя). Ориентиры в git: клиент `e4683b0`…`2eb871e`, бэк `220f018`…`159c656`. Опционально: калибровка дрейфа тайминга между разными Android; перенос комнат из RAM в PostgreSQL — не блокер.

**Открытые задачи (заглушки / backlog):** см. таблицу **«Открытые задачи (backlog, 2026-05-29)»** в `md/IMPLEMENTATION_ROADMAP.md` — поиск треков локально, мысли без лайков/комментариев в БД, история in-memory, чарты/релизы/рекомендации на главной, статистика профиля, студия в основном в SharedPreferences.

**План на последний этап диплома (рекомендации):** закрепить **rule-based scoring**, полноценно вести лог событий рекомендаций (`impression/click/play_start/skip`) и сделать измерение качества — **A/B** или минимум сравнение **до/после** по `CTR` и `plays`.

При регрессиях на устройстве — точечный smoke:
1) ~~guest join и команды гостя в colisten~~ — базовый сценарий закрыт;
2) studio wizard порядок upload (аудио → жанры → cover на publish);
3) attach track to thought без red-screen assert.

---

## Репозиторий

| Путь | Что это |
|------|---------|
| `MiMusic/` | Flutter MiMusic: **Dio** + регистрация/логин, **`GET /me`**, **`GET /tracks`** на главной (`tracks_api.dart`); **лайки треков** — `tracks_api.dart` + `AudioPlayerService` (серверные `server_track_*`); **«Любимые»** — список из лайков + каталог; **плейлисты** — `SessionAwarePlaylistsRepository`, публичный каталог, стеклянный UI; плеер и **colisten** — `ColistenController`, `ListeningRoomSession`, REST+WS (**готово**, см. роадмап этап 8). |
| `mimusicback-master/` | Ktor + Exposed + PostgreSQL; **env** для БД и путей; **загрузки** (треки, обложки, аватар), **отдача** стрима/картинок (**Range** на **`GET /tracks/{id}/stream`** — `TrackRangeRespond.kt`), **`GET /tracks`**, **`/me`**. Таблицы **`users` / `tracks` / …`** — см. `db/schema/pgsql_starter_code.sql`. Пароли в API пока **SHA-256** — по `BACKEND_CLIENT_ALIGNMENT.md`. |

---

## Загрузки и диск на сервере

- **Треки, альбомы и плейлисты** пользователь создаёт **через сервер**: загрузка → валидация/обработка → запись в БД; **аудио** лежит в **`mimusicback-master/music_storage/`** (как у текущего сканера + пользовательские файлы).
- **Обложки и аватары** — в **`mimusicback-master/file_storage/`** по подпапкам ниже; в БД — ключи/относительные пути, не BLOB в строках users/tracks (если не решено иначе).

| Путь от корня бэка | Содержимое |
|---------------------|------------|
| `music_storage/` | Аудио треков |
| `file_storage/avatars/` | Аватары пользователей |
| `file_storage/covers/tracks/` | Обложки треков |
| `file_storage/covers/playlists/` | Обложки плейлистов |
| `file_storage/covers/albums/` | Обложки альбомов |

Каталоги созданы (`.gitkeep`); в `.gitignore` бэка игнорируются реальные загрузки, не структура. Подробнее: `BACKEND_CLIENT_ALIGNMENT.md` §0.

---

## Продуктовые правила (источник правды — клиент + согласованное ТЗ)

- **Медиатека единая:** любой залогиненный пользователь может воспроизвести любой трек, лайкнуть трек и добавить в **свой** плейлист.
- У трека есть **`uploader_user_id`**; в профиле пользователя видны все треки, где он uploader.
- **Плейлисты:** владелец; `is_public` — видимость и рекомендации; **лайки плейлиста** с учётом «кто лайкнул» (`playlist_likes`).
- **Альбомы** пользователя + состав через `album_tracks`.
- **Мысли** (лента): текст + вложение **либо** трек **либо** плейлист; **комментарии** и **лайки мысли**; популярность можно денормализовать (`popularity_score`).
- **Друзья:** заявки (`friend_requests`) + принятая дружба (`friendships`).
- **Colisten:** комнаты `OPEN` vs приватные для друзей хоста; список комнат: открытые для всех + приватные друзей.
- **Инвайт-ключи:** один созданный ключ на пользователя (`invite_keys.creator_user_id` UNIQUE); формат ключа как в клиенте `invite_key_format.dart`.
- **Уведомления:** приглашение в colisten, заявка в друзья / принятие, «загрузил трек» (аудитория — уточнить); таблица `notifications` + REST, позже push.

---

## Сводка таблиц (имена)

**Ядро:** `users`, `tracks`, `albums`, `playlists`, `thoughts`, `comments`, `invite_keys`, опционально `user_settings`, `listen_events`.

**Связи и очереди:** `playlist_tracks`, `album_tracks`, `track_likes`, `playlist_likes`, `thought_likes`, `friend_requests`, `friendships`, `colisten_sessions`, `colisten_session_participants`, `colisten_session_queue_items`, опционально `user_playback_queue_items`, `user_playback_state`, `notifications`, `auth_sessions` (+ опционально `refresh_tokens`, см. `BACKEND_CLIENT_ALIGNMENT.md` §1.13).

**Серверная colisten:** отдельной сущности «плейлисты комнаты» нет — только очередь треков. На клиенте в **`ListeningRoomSession`** пока передаются **`selectedPlaylists`** (названия) вместе с очередью; при появлении бэкенда комнат можно сузить до очереди и метаданных хоста.

---

## Colisten ↔ фронт (важно для WS и API)

Код-ориентиры:

- `MiMusic/lib/core/social/listening_room_session.dart` — `privateRoom`, шесть флагов `*HostOnly` (pause, seek, shuffle, repeat, skip, **playlist** = редактирование очереди), `queue`, **`selectedPlaylists`** (пока для UI/сессии; целевой контракт с сервером — очередь треков).
- `MiMusic/lib/core/audio/audio_player_service.dart` — **`activeQueue`** = персональная очередь вне комнаты.

На сервере: очередь комнаты = **`colisten_session_queue_items`** (`position`, `track_id`); настройки = колонки `control_*_host_only` + `edit_queue_host_only`; аудио по **HTTP Range**; WS — только **события** и состояние синка, не бинарный MP3; версия состояния комнаты для идемпотентности.

---

## Бэкенд: нельзя тащить как есть из mimusicback-master

- Пароли: только **хэш**; ~~хардкод JDBC и путей к диску в коде~~ заменён на **env** (**этап 0**); пароли пользователей в старом API по-прежнему не по ТЗ.
- Стрим: **Range**; старая отдача целого файла — заменить.
- Схема БД под новую модель, не только `track` из сканера папки.
- Загрузки: единая политика путей из раздела выше; корни через env для Docker volume.

---

## Нерешённые продуктовые ветки (явно уточнить у заказчика)

- Одноразовый vs многоразовый инвайт-ключ; таблица `user_registration_invite` или поле на ключе.
- Кто может отправлять **`COLISTEN_INVITE`** (только хост или ещё участники).
- Кому слать уведомление о новом треке: все друзья / подписчики / только «избранные авторы».

---

## Чеклист высокого уровня

~~Этап 0~~ — **готово** (env БД, `MUSIC_STORAGE_DIR` / `FILE_STORAGE_ROOT`). ~~DDL + Exposed под текущие маршруты~~ — **готово** (без Flyway, см. роадмап этап 1). ~~Загрузки и раздача файлов, `GET /tracks`, профиль~~ — на бэке **готово** (см. роадмап этапы 2–3). ~~**HTTP Range** на стриме трека~~ — **готово** (`TrackRangeRespond.kt`). ~~Социальный all-in блок (notifications/profile/thoughts/colisten/upload)~~ — **готово**, в т.ч. ~~colisten (этап 8)~~. Следующий приоритет: **этап 13** (рекомендации и метрики), деплой (11–11a), полировка друзей/уведомлений.

**Обновление приложения:** на сервере — выдача версии/manifest и файла (или URL) сборки; клиент качает и ставит обновление — см. `BACKEND_CLIENT_ALIGNMENT.md` §5.

---

*Последняя синхронизация с `BACKEND_CLIENT_ALIGNMENT.md`: при изменении полной спецификации обновите этот краткий файл (таблицы, открытые вопросы, пути).*
