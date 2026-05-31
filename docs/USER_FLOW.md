# User-flow MiMusic

Диаграмма для вставки в пояснительную записку (рисунок 3.9 или следующий свободный номер).
Можно отрисовать в draw.io / Figma по схеме ниже или экспортировать Mermaid: https://mermaid.live

## Mermaid (дерево слева направо)

```mermaid
flowchart LR
    start["Открытие приложения"]
    init["Инициализация"]
    onboard["Онбординг"]
    auth["Авторизация"]
    reg["Регистрация"]
    main["Main Shell"]

    start --> init
    init --> onboard
    init --> auth
    onboard --> auth
    auth --> reg
    auth --> main
    reg --> main

    home["Главная Music"]
    search["Поиск"]
    profile["Профиль"]

    main --> home
    main --> search
    main --> profile

    fy["Для вас"]
    charts["Чарты"]
    hist["История"]
    colisten["Colisten гость/хост"]
    catalog["Каталог треков"]
    player["Плеер"]

    home --> fy
    home --> charts
    home --> hist
    home --> colisten
    home --> catalog
    home --> player

    s_tracks["Поиск треков"]
    s_users["Поиск пользователей"]
    pubprof["Профиль пользователя"]

    search --> s_tracks
    search --> s_users
    s_users --> pubprof

    thoughts["Мысли"]
    playlists["Плейлисты"]
    fav["Избранное"]
    friends["Друзья"]
    notif["Уведомления"]
    studio["Студия"]
    genres["Жанровые предпочтения"]
    rooms["Открытые комнаты"]
    settings["Настройки"]

    profile --> thoughts
    profile --> playlists
    profile --> fav
    profile --> friends
    profile --> notif
    profile --> studio
    profile --> genres
    profile --> rooms
    profile --> settings

    colisten --> room_host["Комната хоста"]
    colisten --> room_guest["Плеер гостя"]
```

## Текстовая схема (как в примере Englio)

```
[Открытие приложения]
        |
[Инициализация] — настройки, уведомления, AudioService
        |
   +----+----+----+
   |    |    |    |
[Онбординг] [Вход] [Регистрация + инвайт]
   |         \    /
        [Main Shell — нижняя навигация]
   +--------+--------+
   |        |        |
[Главная] [Поиск] [Профиль]
   |        |        |
   |        |        +— Мысли, Плейлисты, Избранное, Друзья
   |        |        +— Уведомления, Студия, Жанровые предпочтения
   |        |        +— Открытые комнаты, Настройки
   |        |
   |        +— Поиск треков / релизов
   |        +— Поиск пользователей → публичный профиль
   |
   +— Для вас, Чарты, История
   +— Совместное прослушивание (Colisten)
   +— Каталог треков, релизы
   +— Мини-плеер / полноэкранный плеер
```
