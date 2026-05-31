# Телефон по USB + бэк на ПК + PostgreSQL (Windows)

Цель: **реальная регистрация** с Android-устройства на **Ktor**, который крутится на компьютере, с базой **PostgreSQL** на этом же ПК.

---

## Часть A. Установить и поднять PostgreSQL (Windows)

### A1. Скачать и установить

1. Открой в браузере: **https://www.postgresql.org/download/windows/**  
   → установщик от **EDB** (официальный путь для Windows).
2. Запусти установщик. Запомни:
   - **порт** (по умолчанию **5432** — оставь так);
   - **пароль суперпользователя `postgres`** — он понадобится для `.env` бэка.
3. Компоненты: достаточно **PostgreSQL Server** + **Command Line Tools**. **pgAdmin** по желанию (удобно смотреть таблицы).
4. Дождись окончания установки.

### A2. Создать базу под MiMusic

1. Открой **«Командная строка»** или **PowerShell** (можно от имени обычного пользователя).
2. Перейди в каталог `bin` PostgreSQL (путь типичный, подправь версию):

   `cd "C:\Program Files\PostgreSQL\16\bin"`

   (если папка `16` другая — используй свою, например `17`.)

3. Создай базу (имя как в бэке по умолчанию — **`music_app`**):

   ```text
   psql -U postgres -c "CREATE DATABASE music_app;"
   ```

   Введи пароль пользователя `postgres`, который задавал при установке.

4. Если команда ругается на кодировку/locale — для локальной разработки обычно достаточно повторить команду; при ошибке «база уже есть» — переходи к шагу A3.

### A3. Накатить схему (SQL из репозитория)

1. Файл скрипта: **`mimusicback-master/db/schema/pgsql_starter_code.sql`** (полный путь на диске, например `D:\Programming\MiMusic\mimusicback-master\db\schema\pgsql_starter_code.sql`).
2. Выполни (одной строкой, путь к файлу свой):

   ```text
   psql -U postgres -d music_app -f "D:\Programming\MiMusic\mimusicback-master\db\schema\pgsql_starter_code.sql"
   ```

3. Ошибок в конце быть не должно; при повторном накате на **непустую** базу возможны конфликты — для чистого повтора удобнее пересоздать базу:

   ```text
   psql -U postgres -c "DROP DATABASE IF EXISTS music_app;"
   psql -U postgres -c "CREATE DATABASE music_app;"
   psql -U postgres -d music_app -f "...\pgsql_starter_code.sql"
   ```

### A4. Проверка, что Postgres слушает порт

В PowerShell:

```powershell
Test-NetConnection -ComputerName 127.0.0.1 -Port 5432
```

`TcpTestSucceeded : True` — нормально.

---

## Часть B. Настроить и запустить бэкенд (Ktor)

Рабочая папка: **`mimusicback-master`**.

### B1. JDK

Нужен **JDK 11+** (Gradle/Ktor 3.x). Подойдёт **Amazon Corretto** и т.п.; в проекте задан **jvmToolchain** под установленный JDK (см. `mimusicback-master/build.gradle.kts`). В Android Studio: **File → Settings → Build → Gradle → Gradle JDK** — не ниже 11. Скрипт **`run-dev.ps1`** ищет JDK в типичных путях (в т.ч. `D:\AmazonCoretto`, JBR Studio).

### B2. Файл окружения

1. Скопируй **`mimusicback-master/.env.example`** → **`mimusicback-master/.env`** (рядом с проектом).
2. Заполни минимум:

   - **`DB_HOST`** = `localhost`
   - **`DB_PORT`** = `5432`
   - **`DB_NAME`** = `music_app`
   - **`DB_USER`** = `postgres`
   - **`DB_PASSWORD`** = пароль пользователя `postgres` из установки

При **`gradlew run`** бэк сам читает **`mimusicback-master/.env`** (если переменная не задана в ОС). Иначе: экспорт в PowerShell или **Environment variables** в Run Configuration для `ApplicationKt`.

### B3. Запуск сервера

Из каталога **`mimusicback-master`**:

```powershell
.\run-dev.ps1 run
```

Скрипт **`run-dev.ps1`** выставляет **JDK 11+** (ищет `JAVA_HOME`, JBR из **Android Studio**, типичные `C:\Program Files\Java\jdk-17` и т.д.). Если у тебя только Java 8 в PATH, без этого шага **`gradlew.bat run`** падает с ошибкой про **«compatible with Java 8»** и плагин Ktor.

Альтернатива: в **`gradle.properties`** раскомментировать **`org.gradle.java.home=...`** на свой путь к JDK 17.

Либо запуск **main** из IDE: класс **`com.example.ApplicationKt`**, в Run Configuration выбери **Gradle JDK** / **JRE** не ниже **11**.

В **`Application.kt`** сервер уже слушает **`0.0.0.0:8080`** — то есть доступен и с других интерфейсов (не только localhost), если файрвол разрешит.

### B4. Быстрая проверка с ПК

В браузере или curl:

- **`GET http://127.0.0.1:8080/`** — ответ JSON (`Hello World!` / тестовый DTO), маршрут подключён в `Application.module()`.
- Регистрация: **Postman** или `POST .../register` с JSON (см. `RegisterReceiveRemote`). Для проверки с **`REQUIRE_INVITE_KEY=true`** можно использовать сид **`TESTK-EYDEV-BUILD`** (см. `DatabaseBootstrap.kt` / `.env.example`).

---

## Часть C. Телефон по USB — чтобы регистрация ходила на ПК

Есть **два рабочих варианта**. Для кабеля USB чаще проще **вариант 1**.

### Вариант 1 (рекомендуется): `adb reverse` — телефон стучится на `127.0.0.1:8080`

На телефоне **127.0.0.1** — это сам телефон. Через USB мы **пробрасываем** порт: запросы с телефона на `127.0.0.1:8080` попадают на **твой ПК:8080**.

1. На телефоне: **Настройки → Для разработчиков → Отладка по USB** (включить). Подключи кабель, разреши отладку.
2. На ПК установи **Android SDK Platform-Tools** (есть в составе Android Studio). В PATH должен быть **`adb`**.
3. Проверка:

   ```text
   adb devices
   ```

   Должен быть `device`, не `unauthorized`.

4. Выполни **каждый раз после подключения** (или после перезапуска adb):

   ```text
   adb reverse tcp:8080 tcp:8080
   ```

   Успех — без ошибок в консоли.

5. **Flutter из Android Studio (кнопка Run):** в **`MiMusic/android/app/build.gradle.kts`** при сборке задаётся **`dart-defines`** с базовым URL **`http://127.0.0.1:8080`**, перед **`preBuild`** выполняется **`adb reverse tcp:8080 tcp:8080`** (ищется **`adb`** из **`sdk.dir`** в `android/local.properties`, не только `PATH`). На устройстве **`MainActivity`** через **MethodChannel** подставляет **`10.0.2.2`** вместо loopback на **эмуляторе**. Дополнительно: в **`android/local.properties`** можно задать **`flutter.apiBaseUrl=http://IP_ПК:8080`** (Wi‑Fi без reverse).

   Вручную по-прежнему можно:

   ```text
   flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8080
   ```

6. Бэк на ПК должен быть **запущен** (`gradlew run` / `run-dev.ps1`). Postgres — **запущен** и база накатана.

**Важно:** `adb reverse` действует, пока живёт сессия adb; при отвале USB иногда нужно повторить команду.

### Вариант 2: телефон и ПК в одной Wi‑Fi сети — IP компьютера

1. На ПК в PowerShell: `ipconfig` → найди **IPv4-адрес** Wi‑Fi адаптера, например `192.168.0.42`.
2. Убедись, что телефон в **той же Wi‑Fi** сети.
3. В **Брандмауэре Windows** разреши **входящие** TCP **8080** для частной сети (или временно отключи брандмауэр только для проверки — не для постоянной работы).
4. Flutter:

   ```text
   flutter run --dart-define=API_BASE_URL=http://192.168.0.42:8080
   ```

   Подставь свой IP.

---

## Часть D. Частые проблемы

| Симптом | Что проверить |
|--------|----------------|
| `auth.error.network` в приложении | Бэк запущен? **`adb reverse tcp:8080 tcp:8080`** (или эмулятор + `10.0.2.2`). В Logcat по строке **`ApiConfig`** видно выбранный base URL. Вариант 2: **`flutter.apiBaseUrl`** в `local.properties` + файрвол. |
| Ошибка подключения к БД в консоли Ktor | `DB_*` в env, служба Postgres запущена (Службы Windows → postgresql). |
| Регистрация 409 / «уже существует» | Уже есть пользователь с таким ником; другой ник или другая база. |
| Cleartext / HTTP на Android | В проекте для **debug** уже включён `usesCleartextTraffic`; для **release** нужен HTTPS. |

---

## Краткий чеклист «всё работает»

1. [ ] PostgreSQL установлен, база **`music_app`** создана, **`pgsql_starter_code.sql`** выполнен без ошибок.  
2. [ ] В env для бэка заданы **`DB_HOST` / `DB_PORT` / `DB_NAME` / `DB_USER` / `DB_PASSWORD`**.  
3. [ ] `.\gradlew.bat run` в **`mimusicback-master`** — сервер слушает **8080**.  
4. [ ] Телефон: USB отладка, **`adb devices`**, **`adb reverse tcp:8080 tcp:8080`**.  
5. [ ] Flutter: **Run из Android Studio** (Gradle уже подставляет API URL + reverse) **или** `flutter run --dart-define=API_BASE_URL=...`.  
6. [ ] Регистрация в приложении создаёт строку в **`users`** (смотри pgAdmin / `psql`); служебные **`__scanner_uploader__`** / **`__invite_key_holder__`** — не удалять без понимания.  
7. [ ] На **главной** Flutter после входа отображается блок **«треки на сервере»** (данные с **`GET /tracks`**), если в таблице **`tracks`** есть строки (например от сканера **`music_storage/`** или после **`POST /upload/track`**).  
8. [ ] (Опционально) С ПК: `curl -v -H "Range: bytes=0-255" "http://127.0.0.1:8080/tracks/<id>/stream"` — ожидается **HTTP/1.1 206** и заголовок **Content-Range**; без `-H Range` — **200**.

Если нужно, следующим шагом можно добавить в README ссылку на этот файл одной строкой (скажи — добавлю).
