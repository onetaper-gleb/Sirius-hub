# SiriusHub (client)

Мобильное Flutter-приложение **SiriusHub** для кампуса/университета: новости, форум, расписание и профиль.  
Клиент работает с backend через Dio. По умолчанию вход использует Firebase Auth. Для backend с JWT выберите режим сборки `AUTH_BACKEND=jwt`.

Этот файл закрывает пункт отчёта **«Документация разработчика, документация пользователя»** для frontend (`client/`).

---

## Документация пользователя

### Назначение

SiriusHub помогает студентам и представителям студсовета:

- читать и публиковать **новости** кампуса;
- обсуждать темы на **форуме**;
- смотреть **расписание** своей группы;
- вести **профиль** (имя, группа, Messenger, «о себе», аватар-эмодзи).

### Роли

| Роль | Возможности |
|------|-------------|
| **student** (по умолчанию) | Вход, профиль, просмотр новостей, участие в форуме (комментарии), расписание своей группы |
| **council** (студсовет) | Всё то же + создание/удаление новостей, создание тем форума |
| **admin** (администратор) | все права студсовета + назначение ролей |

### Первый запуск

1. Откройте приложение.
2. На экране входа выберите **Вход** или **Регистрация**.
3. Укажите email и пароль (при регистрации — подтвердите пароль).
4. После регистрации заполните профиль:
   - отображаемое имя;
   - код группы (нужен для расписания);
   - Messenger (необязательно);
   - «О себе» (необязательно);
   - аватар-эмодзи.
5. Черновик профиля сохраняется локально, пока вы его не отправите.

### Основные экраны

Нижняя навигация после входа:

| Вкладка | Что делает пользователь |
|---------|-------------------------|
| **Новости** | Лента новостей с изображениями. У роли `council` — кнопка «+» для создания новости (заголовок, текст, фото) и удаление своих/доступных новостей |
| **Форум** | Список тем. Открытие темы → комментарии (в т.ч. ответы). У `council` — создание новой темы (можно анонимно). Удаление комментария — автор или `council` |
| **Расписание** | Пары по группе из профиля: дни недели (Пн–Вс), переключение недели вперёд/назад |
| **Профиль** | Просмотр данных, редактирование, выход из аккаунта |

### Типичные сценарии

- **Не вижу расписание** — в профиле должен быть заполнен код группы.
- **Нет кнопки создания новости/темы** — нужна роль `council` (выдаётся на стороне backend).
- **Ошибка входа** — проверьте email/пароль; при «Ошибка соединения» нужен доступ к сети и работающий backend.

---

## Документация разработчика

### Требования

- Flutter SDK (stable), Dart SDK `^3.11.0` (см. `pubspec.yaml`)
- Android Studio / Xcode (или настроенный эмулятор/устройство)
- iOS 15 или новее: это минимальная версия Firebase SDK
- CocoaPods для `flutter_secure_storage` на iOS и macOS
- Firebase-проект с Email/Password Auth (конфиг уже в репозитории)
- Доступный backend SiriusHub (деплой или локальный)

### Стек

| Область | Технологии |
|---------|------------|
| UI | Flutter, Material 3 |
| Состояние | `bloc` / `flutter_bloc` |
| HTTP | `dio` |
| Auth | `firebase_core`, `firebase_auth` |
| Локальное хранение | `shared_preferences` (черновик регистрации) |
| Медиа | `image_picker`, `cached_network_image` |
| Splash / иконки | `flutter_native_splash`, `flutter_launcher_icons` |
| Тесты | `flutter_test`, `mocktail` |

Зависимость `cloud_firestore` объявлена в `pubspec.yaml`; основной обмен данными с приложением идёт через REST backend.

### Архитектура

Слои (упрощённо):

```
module/     → UI (экраны, виджеты)
domain/     → BLoC/контроллеры, модели
data/       → Repository + DataSource (Firebase Auth)
network/    → Dio-клиент
core/       → ApiConfig, DI (DependenciesScope)
```

Поток данных:

1. UI отправляет события в BLoC / вызывает repository через `DependenciesScope`.
2. Repository получает токен выбранного источника авторизации и вызывает backend с заголовком `Authorization: Bearer <token>`.
3. Backend проверяет токен (Firebase Admin) и отдаёт JSON.
4. BLoC обновляет state → UI перестраивается.

Точка входа: `lib/main.dart`  
Маршрутизация после auth: `lib/module/auth/auth_gate.dart` → `LoginScreen` / `RegistrationProfileScreen` / `AppShell`.

### Структура `lib/`

```
lib/
  main.dart
  core/
    api_config.dart      # baseUrl backend
    dependencies.dart    # InheritedWidget DI
  network/
    http_client.dart     # фабрика Dio
  data/
    source/              # FirebaseAuthDataSource
    repository/          # auth, news, schedule, forum, topic
    local/               # emoji, draft storage
  domain/
    bloc/                # auth, news, schedule, forum, topic
    model/               # profile, news, schedule, forum, user
  module/
    auth/                # login, registration, auth_gate
    news/
    forum/
    schedule/
    profile/
    widgets/             # AdminFab и др.
  utils/
    firebase_options.dart
```

### Конфигурация backend URL

Адрес API задаётся при сборке через `API_BASE_URL` (по умолчанию `https://104.143.201.57`). Режим авторизации задаётся через `AUTH_BACKEND`: `firebase` (по умолчанию) или `jwt`. Неизвестный режим и некорректный URL останавливают запуск.

Для прежнего backend с `/auth/init` используйте Firebase:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:56284
```

Backend в этой ветке использует JWT (`/auth/register`, `/auth/token`, `/auth/me`). Соберите клиент с тем же режимом:

```bash
flutter build apk --dart-define=AUTH_BACKEND=jwt --dart-define=API_BASE_URL=https://104.143.201.57
flutter build ios --dart-define=AUTH_BACKEND=jwt --dart-define=API_BASE_URL=https://104.143.201.57
```

Если backend работает по другому адресу, замените `API_BASE_URL`. JWT требует HTTPS. В debug-сборках разрешён HTTP для `localhost`, `127.0.0.1`, `::1` и Android-эмулятора `10.0.2.2`:

```bash
flutter run --dart-define=AUTH_BACKEND=jwt --dart-define=API_BASE_URL=http://10.0.2.2:56284
```

Сначала установите backend-исправления, совместимые с Firebase, и этот клиент. Затем установите backend с JWT и выпустите клиент с `AUTH_BACKEND=jwt`. Firebase-сборка не входит в JWT backend, а JWT-сборка не входит в Firebase backend.

JWT-сессия хранится в Keychain/Keystore через `flutter_secure_storage`. При запуске клиент проверяет сохранённый токен через `/auth/me`. При HTTP 401 или выходе клиент удаляет локальный токен. Backend не выдаёт refresh token: после истечения access token (по умолчанию 60 минут) войдите снова. Пароли Firebase не переносятся в JWT автоматически. Для прежних пользователей администратор должен настроить пароль по инструкции backend.

Ошибка сети не запускает регистрацию повторно и не удаляет аккаунт. Если профиль не загрузился, нажмите «Повторить» или «Выйти». Кнопка «Выйти» в незавершённой регистрации завершает сессию без удаления аккаунта.

### Firebase

- Опции платформ: `lib/utils/firebase_options.dart` (FlutterFire CLI)
- Android: `android/app/google-services.json`
- Проект Firebase: `sirius-hub-df66a` (см. `firebase.json`)

Перегенерация (при смене Firebase-проекта):

```bash
flutterfire configure
```

### Запуск

```bash
cd client
flutter pub get
flutter run --dart-define=AUTH_BACKEND=jwt
```

Полезные варианты:

```bash
flutter run -d chrome --dart-define=AUTH_BACKEND=jwt
flutter run -d <device_id> --dart-define=AUTH_BACKEND=jwt
flutter devices                # список устройств
```

Ориентация зафиксирована в portrait (`main.dart`).

### Тесты и форматирование

```bash
cd client
dart format lib test
flutter analyze
flutter test
```

Текущие тесты:

- `test/widget_test.dart` — поведение `ButtonNotifier`
- `test/module/auth/login_screen_test.dart` — экран входа
- `test/domain/model/registration_profile_test.dart` — модель профиля регистрации
- `test/data/` — Firebase/JWT сессии, поля профиля, сроки кэша расписания
- `test/domain/bloc/` — поздние ответы после выхода и смены группы
- `test/module/news/`, `test/module/schedule/` — загрузка события, вместимость, раскладка расписания

Для Bazel установите Bazelisk и добавьте Flutter/Dart в `PATH`. Сначала выполните `flutter pub get`, затем запустите из `client/`:

```bash
bazel test //:tests //:analyze --test_env=PATH --test_env=HOME --test_env=PUB_HOSTED_URL --test_output=errors
```

Bazel использует закреплённую версию 7.6.1. Dart runner копирует исходники во временный каталог, разрешает зависимости из pub cache и запускает Flutter. Цель `analyze` завершится ошибкой при ошибках анализатора. Существующие предупреждения и подсказки выводятся без остановки проверки.

### Сборка релиза (кратко)

```bash
# Android
flutter build apk --dart-define=AUTH_BACKEND=jwt
# или
flutter build appbundle --dart-define=AUTH_BACKEND=jwt

# iOS (macOS + Xcode)
flutter build ios --dart-define=AUTH_BACKEND=jwt
```

Иконки и splash задаются в `pubspec.yaml` (`flutter_launcher_icons`, `flutter_native_splash`).

### Частые проблемы (client)

| Симптом | Что проверить |
|---------|----------------|
| Ошибка соединения / Dio timeout | `ApiConfig.baseUrl`, доступность backend, firewall, cleartext HTTP на Android |
| 401 Unauthorized | выбранный режим соответствует backend; JWT-сессия не истекла; войдите снова |
| После регистрации «зависает» профиль | сеть до API; `POST /auth/init` нужен только для режима Firebase |
| Пустое расписание | в профиле заполнен `groupCode`; backend `/schedule` отвечает для этой группы |
| Нет FAB создания новости/темы | у пользователя роль `council` в профиле/custom claims |
| Splash не снимается | смотрите исключения на старте Firebase / `main()` |

### Связь с корневым README

Обзор всего репозитория (backend API, Docker, CI): [`../README.md`](../README.md).
