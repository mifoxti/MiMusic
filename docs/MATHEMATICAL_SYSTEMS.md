# Математическое обеспечение MiMusic (клиент и сервер)

Документ фиксирует **численные модели, формулы и места в коде**, где они реализованы. Актуальность: по состоянию репозитория на момент добавления файла.

**Про превью формул:** здесь используется LaTeX (`\(…\)`, `\[…\]`). Обычный рендер Markdown **не** рисует их как формулы. В **Cursor / VS Code** включите в настройках **`Markdown › Math: Enabled`** (`markdown.math.enabled`: `true`) и откройте превью снова — тогда подставится KaTeX. Без этого в превью будет «сырой» LaTeX, как на скриншоте. На GitHub формулы тоже поддерживаются только при включённой разметке; в простых просмотрщиках `.md` смотрите текстом или экспортируйте в PDF/HTML с MathJax.

---

## 1. Рекомендации по жанрам (сервер, Ktor)

### 1.1. Входные данные

- Для пользователя \(u\) и жанра \(g\) (по `genre_id`): вес предпочтения \(U_{u,g} \ge 0\) из таблицы `user_genre_preferences` (поле `weight`, в БД ограничено диапазоном \([0, 100]\)).
- Для трека \(t\) и жанра \(g\): вес тега \(T_{t,g} \ge 0\) из `track_genres` (поле `weight`, тот же диапазон в DDL).

### 1.2. Скор трека для пользователя

Для каждого трека \(t\) суммируются только жанры, у которых есть и тег на треке, и ненулевое предпочтение у пользователя (если предпочтения нет, вклад \(0\)):

\[
S(t, u) = \sum_{g \in G} U_{u,g} \cdot T_{t,g}
\]

где \(G\) — множество всех жанров, фактически сумма по строкам `track_genres` для данного `track_id`.

**Особые случаи**

1. **Нет строк в `user_genre_preferences` для \(u\)**  
   Список выдаётся как каталог: последние треки по `id` DESC, формально всем присваивается \(S = 0\) (сортировка по `id`).

2. **У трека нет строк в `track_genres`**  
   После цикла по жанрам \(S = 0\); затем подставляется малая константа:

\[
S \leftarrow 10^{-6}
\]

чтобы трек не «терялся» при сортировке, но оставался ниже любого трека с ненулевым скором.

**Реализация:** `mimusicback-master/src/main/kotlin/services/RecommendationScoreService.kt` (`RecommendationScoreService.scoredTrackIds`).

### 1.3. Сортировка

Сначала по убыванию \(S\), при равенстве — по убыванию `track_id`:

\[
(t_1, S_1) \succ (t_2, S_2) \iff (S_1 > S_2) \lor (S_1 = S_2 \land \mathrm{id}(t_1) > \mathrm{id}(t_2))
\]

**API:** `GET /recommendations/tracks?limit=…` — `mimusicback-master/src/main/kotlin/features/recommendations/RecommendationRouting.kt`.  
Поле **`score`** в ответе — это \(S\) (после правила с \(10^{-6}\) для безжанровых треков).

### 1.4. Учёт событий (не формула, а измерение)

В `recommendation_events` пишутся `impression`, `click` и т.д.; в поле **`score_present`** при показе может сохраняться тот же \(S\), что вернул API (для последующей аналитики, не для пересчёта скора в рантайме).

**Клиент:** `MiMusic/lib/presentation/pages/for_you_page.dart` (после загрузки — пакет `impression`, по тапу — `click`), `MiMusic/lib/core/network/recommendations_api.dart`.

---

## 2. Нормализация весов жанров на треке/альбоме (сервер)

При сохранении тегов (`replaceTrackGenres` / `replaceAlbumGenres`) для **\(n\)** выбранных жанров (после дедупликации по `genre_id`):

- если флаг **`normalizeWeights = false`** (по умолчанию):

\[
T_{t,g_i} = 1 \quad \forall i \in \{1,\ldots,n\}
\]

- если **`normalizeWeights = true`**:

\[
T_{t,g_i} = \frac{1}{n}
\]

**Реализация:** `mimusicback-master/src/main/kotlin/services/TrackGenreService.kt`.  
**Вызов при загрузке трека:** multipart `genreNormalizeWeights` в `UploadRouting.kt`.

---

## 3. Локальная «персонализация» в разделе «Для вас» (Flutter, без сервера)

Для локальной библиотеки строится **бинарный** скор по совпадению подстроки исполнителя или названия с «подсказками» из секции главной (`historyArtists`):

\[
\mathrm{score}_{\mathrm{local}}(t) = \begin{cases}
1 & \exists\, h \in H:\; h \subseteq a(t) \lor h \subseteq \mathrm{title}(t) \\
0 & \text{иначе}
\end{cases}
\]

где строки приводятся к нижнему регистру, \(H\) — множество подсказок, \(a(t)\) — отображаемый исполнитель трека, проверка — **вхождение подстроки** (`contains`), не полное совпадение.

Сортировка: по убыванию \(\mathrm{score}_{\mathrm{local}}\).

**Реализация:** `MiMusic/lib/presentation/pages/for_you_page.dart` (`_buildRecommendedOrder`).  
**Серверная** подборка при наличии входа — отдельно, см. §1; очереди воспроизведения выбираются в `_queueForTrack` / `_onPlayMixPressed`.

---

## 4. Нормализация жанров в студии (Flutter, строки)

Не вероятности, а **канонизация идентификаторов**:

1. Нормализация ключа для словаря алиасов: trim, lower case, `ё` → `е`, схлопывание пробелов в один.
2. Отображение произвольной строки в один из `studioGenreIds` через `studioGenreAliases` или прямое совпадение.
3. `normalizeStudioGenreList`: множество без дубликатов, только валидные id.

**Реализация:** `MiMusic/lib/core/studio/studio_constants.dart`.

---

## 5. Явные предпочтения по жанрам на клиенте (Flutter → сервер)

На экране настроек жанров каждый выбранный жанр отправляется с **фиксированным весом**:

\[
U_{u,g} = 1
\]

для всех выбранных \(g\); невыбранные жанры в `PUT` не попадают (на сервере строки удаляются и вставляются заново).

**Реализация:** `MiMusic/lib/presentation/pages/genre_preferences_page.dart`, API — `UserGenrePreferencesApi` → `PUT /me/genre-preferences`.

---

## 6. Эквалайзер (Flutter, Android)

### 6.1. Ограничение диапазона усиления полос и преампа

Полосы \(i = 0,\ldots,4\), значения в децибелах:

\[
g_i \leftarrow \mathrm{clamp}(g_i, -6,\, 6), \qquad
p \leftarrow \mathrm{clamp}(p, -6,\, 6)
\]

**Реализация:** `MiMusic/lib/presentation/pages/equalizer_page.dart` (`_eqMinDb`, `_eqMaxDb`, `_clampDb`).

### 6.2. Распределение преампа по полосам (нативный эквалайзер)

Пусть \(n\) — число полос устройства, \(g_i\) — усиление полосы из настроек, \(p\) — преамп. Итоговое усиление, подаваемое в `setGain` для полосы \(i\):

- при \(n \ge 2\):

\[
\tilde{g}_0 = g_0 + 0.55\, p, \qquad
\tilde{g}_1 = g_1 + 0.45\, p, \qquad
\tilde{g}_i = g_i \;\;(i \ge 2)
\]

- при \(n = 1\):

\[
\tilde{g}_0 = g_0 + p
\]

Затем каждое \(\tilde{g}_i\) ограничивается физическими пределами эквалайзера устройства:

\[
\tilde{g}_i \leftarrow \mathrm{clamp}(\tilde{g}_i,\; \mathrm{minDecibels},\; \mathrm{maxDecibels})
\]

**Реализация:** `MiMusic/lib/core/audio/mimusic_audio_handler.dart` (`_syncAndroidEqualizer`).

### 6.3. Отключение DSP на «плоской» кривой**

DSP считается выключенным (плоская кривая), если:

\[
|p| < 0.05 \quad \land \quad \forall i:\; |g_i| < 0.05
\]

(порог в дБ, эвристика для шума/искажений).

### 6.4. Дебаунс

- применение полос к плееру: **100 ms**;
- сохранение в настройки: **120 ms**.

**Реализация:** `EqualizerPage` (`_scheduleApplyGainsDebounced`, `_scheduleSaveDebounced`).

---

## 7. Криптография и хэши

### 7.1. Пароль пользователя (клиент и сервер, временная схема)

От пароля \(P\) (UTF-8) вычисляется SHA-256, в хранилище попадает **шестнадцатеричная строка** дайджеста:

\[
H_{\mathrm{pwd}} = \mathrm{hex}\bigl(\mathrm{SHA256}(\mathrm{UTF8}(P))\bigr)
\]

Проверка: то же вычисление и сравнение строк.

**Клиент:** `MiMusic/lib/core/auth/password_hash.dart`.  
**Сервер:** `mimusicback-master/src/main/kotlin/utils/Crypto.kt` (`sha256Hex`), использование в `RegisterRouting` / `LoginRouting`.

### 7.2. Сессионный токен (сервер)

В БД в `auth_sessions` хранится **хэш** токена, не сам токен:

\[
H_{\mathrm{tok}} = \mathrm{hex}\bigl(\mathrm{SHA256}(\mathrm{token})\bigr)
\]

**Реализация:** выдача/проверка в `LoginRouting` / `RegisterRouting`, утилита `sha256Hex`.

### 7.3. Хэш аудиофайла трека (сервер)

Для дедупликации/целостности файла на диске:

\[
H_{\mathrm{file}} = \mathrm{hex}\bigl(\mathrm{SHA256}(\text{байты файла})\bigr)
\]

**Реализация:** `UploadRouting.kt` (`sha256File`), `MusicScanner.kt` (аналогично по содержимому файла).

---

## 8. Длительность трека (сервер)

Из длительности MP3 в секундах (целое) в миллисекунды для БД:

\[
\mathrm{duration\_ms} = \max(0, \lfloor T_{\mathrm{sec}} \rfloor) \cdot 1000
\]

Обратно в JSON для клиента часто отдаётся **секунда**:

\[
\mathrm{duration}_{\mathrm{sec}} = \left\lfloor \frac{\mathrm{duration\_ms}}{1000} \right\rfloor
\]

**Реализация:** загрузка — `UploadRouting.kt`; выдача — `TrackRouting.kt`, `RecommendationRouting.kt`, `SearchRouting.kt`.

---

## 9. HTTP Range для стрима (сервер)

Пусть \(L\) — размер файла в байтах, \(L>0\), последний допустимый байт \(\mathrm{last} = L - 1\).

### 9.1. Суффикс `bytes=-N`

Запрос последних \(N\) байт:

\[
\mathrm{start} = \max(0,\; L - N), \quad \mathrm{end} = \mathrm{last}
\]

(при некорректных \(N\) диапазон отбраковывается — см. код.)

### 9.2. Интервал `bytes=A-B`

\[
\mathrm{start} = A,\quad \mathrm{end} = \min(B,\; \mathrm{last})
\]

при пустом \(B\) берётся \(\mathrm{end} = \mathrm{last}\); пустой \(A\) → \(0\).

### 9.3. Длина отдаваемого фрагмента

\[
\mathrm{sliceLen} = \mathrm{end} - \mathrm{start} + 1
\]

Ограничение сверху: если \(\mathrm{sliceLen} > 64 \cdot 1024^2\), ответ **413**.

**Реализация:** `mimusicback-master/src/main/kotlin/features/tracks/TrackRangeRespond.kt` (`satisfiableByteRange`, `respondTrackAudioWithOptionalRange`).

---

## 10. Ограничения в БД (жанровые веса)

В PostgreSQL для `track_genres`, `album_genres`, `user_genre_preferences`:

\[
0 \le \mathrm{weight} \le 100
\]

(тип `double precision`, проверка `CHECK` в `pgsql_starter_code.sql`.)

---

## 11. Карта «формула → файл»

| Тема | Файл(ы) |
|------|---------|
| Скор рекомендаций \(S = \sum U \cdot T\), \(\varepsilon\)-правило, сортировка | `RecommendationScoreService.kt`, `RecommendationRouting.kt` |
| Нормализация \(1/n\) для жанров | `TrackGenreService.kt`, `UploadRouting.kt` |
| Локальный бинарный скор «Для вас» | `for_you_page.dart` |
| Канонизация жанров в студии | `studio_constants.dart` |
| Вес 1.0 в предпочтениях с клиента | `genre_preferences_page.dart` |
| Эквалайзер: clamp, преамп 0.55/0.45, порог flat | `equalizer_page.dart`, `mimusic_audio_handler.dart` |
| SHA-256 пароля/токена/файла | `password_hash.dart`, `Crypto.kt`, `UploadRouting.kt`, auth routing |
| Длительность мс ↔ с | `UploadRouting.kt`, `TrackRouting.kt`, … |
| HTTP Range, длина среза, лимит 64 MiB | `TrackRangeRespond.kt` |

---

## 12. Что намеренно **не** формализовано формулами здесь

- **Colisten / WebSocket** — синхронизация состояния комнаты без общего скорингового ядра в текущем коде.
- **Плейлист как вектор жанров** — агрегат по составу в БД не считается автоматически (см. обсуждение в `md/BACKEND_CLIENT_ALIGNMENT.md`).
- **Рекомендации на основе только** `recommendation_events` (CTR, логистическая регрессия и т.д.) — **пока не реализованы**, таблица ведётся для будущей аналитики.

## 13. План финального этапа (диплом)

### 13.1. Rule-based scoring (боевая формула без тяжёлого ML)

На финальном этапе фиксируем и документируем единую формулу ранжирования:

\[
S_{final}(t,u) = \alpha \cdot S_{genre}(t,u) + \beta \cdot S_{fresh}(t) + \gamma \cdot S_{pop}(t)
\]

где базовый жанровый компонент уже реализован:

\[
S_{genre}(t,u)=\sum_g U_{u,g}\cdot T_{t,g}
\]

а \(S_{fresh}\) и \(S_{pop}\) можно оставить нулевыми (если не успеваете) или добавить простыми эвристиками. Главное — зафиксировать коэффициенты \(\alpha,\beta,\gamma\) в коде и отчёте.

### 13.2. Лог событий рекомендаций

Минимальный набор событий для `recommendation_events`:

- `impression` — карточка показана пользователю;
- `click` — пользователь нажал карточку;
- `play_start` — реально начато воспроизведение;
- `skip` — пропуск трека.

Для `impression` сохраняем `score_present`, чтобы потом сравнивать качество разных формул на одинаковой шкале.

### 13.3. Оценка качества: A/B или «до/после»

Если аудитории мало (30–100 пользователей), допускается «до/после» как основной метод.

Базовые метрики:

\[
CTR = \frac{N_{click}}{N_{impression}}
\]

\[
PlayRate = \frac{N_{play\_start}}{N_{impression}}
\]

\[
SkipRate = \frac{N_{skip}}{N_{play\_start}}
\]

Сравнение:

- **A/B:** сравнить метрики между группами A и B за одинаковый период;
- **До/после:** сравнить baseline-период и период после обновления scoring.

При добавлении новых численных правил имеет смысл дополнять этот файл и ссылаться на него из `md/AGENT_CONTEXT_BRIEF.md` или роадмапа.
