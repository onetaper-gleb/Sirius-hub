# SiriusHub (client)

Мобильное Flutter-приложение **SiriusHub** для кампуса/университета: новости, форум, расписание и профиль.  
Клиент работает с backend по HTTP (Dio) и использует **Firebase Auth** для входа.

Этот файл закрывает пункт отчёта **«Документация разработчика, документация пользователя»** для frontend (`client/`).

---

## Документация пользователя

### Назначение

SiriusHub помогает студентам и представителям студсовета:

- читать и публиковать **новости** кампуса;
- обсуждать темы на **форуме**;
- смотреть **расписание** своей группы;
- вести **профиль** (имя, группа, Telegram, «о себе», аватар-эмодзи).

### Роли

| Роль | Возможности |
|------|-------------|
| **student** (по умолчанию) | Вход, профиль, просмотр новостей, участие в форуме (комментарии), расписание своей группы |
| **council** (студсовет) | Всё то же + создание/удаление новостей, создание тем форума |

### Первый запуск

1. Откройте приложение.
2. На экране входа выберите **Вход** или **Регистрация**.
3. Укажите email и пароль (при регистрации — подтвердите пароль).
4. После регистрации заполните профиль:
   - отображаемое имя;
   - код группы (нужен для расписания);
   - Telegram (необязательно);
   - «О себе» (необязательно);
   - аватар-эмодзи.
5. Черновик профиля сохраняется локально, пока вы его не отправите.

### Основные экраны

Нижняя навигация после входа:

| Вкладка | Что делает пользователь |
|---------|-------------------------|
| **Новости** | Лента новостей с изображениями. У роли `council` — кнопка «+» для создания новости (заголовок, текст, фото) и удаление своих/доступных новостей |
| **Форум** | Список тем. Открытие темы → комментарии (в т.ч. ответы). У `council` — создание новой темы (можно анонимно). Удаление комментария — автор или `council` |
| **Расписание** | Пары по группе из профиля: дни недели (Пн–Сб), переключение недели вперёд/назад |
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
2. Repository получает Firebase ID Token и вызывает backend с заголовком `Authorization: Bearer <token>`.
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

Файл: `lib/core/api_config.dart`

```dart
abstract final class ApiConfig {
  static const String baseUrl = 'http://93.88.203.130:56284';
}
```

Для локальной разработки замените на адрес вашего API, например:

- эмулятор Android → `http://10.0.2.2:56284` (если backend на хосте в Docker на порту 56284);
- устройство в той же сети → `http://<IP-хоста>:56284`.

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
flutter run
```

Полезные варианты:

```bash
flutter run -d chrome          # web (если нужен)
flutter run -d <device_id>     # конкретное устройство
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

### Сборка релиза (кратко)

```bash
# Android
flutter build apk
# или
flutter build appbundle

# iOS (macOS + Xcode)
flutter build ios
```

Иконки и splash задаются в `pubspec.yaml` (`flutter_launcher_icons`, `flutter_native_splash`).

### Частые проблемы (client)

| Симптом | Что проверить |
|---------|----------------|
| Ошибка соединения / Dio timeout | `ApiConfig.baseUrl`, доступность backend, firewall, cleartext HTTP на Android |
| 401 Unauthorized | валидный Firebase-пользователь; токен передаётся в repository |
| После регистрации «зависает» профиль | backend: `POST /auth/init`, затем профиль; сеть до API |
| Пустое расписание | в профиле заполнен `groupCode`; backend `/schedule` отвечает для этой группы |
| Нет FAB создания новости/темы | у пользователя роль `council` в профиле/custom claims |
| Splash не снимается | смотрите исключения на старте Firebase / `main()` |

### Связь с корневым README

Обзор всего репозитория (backend API, Docker, CI): [`../README.md`](../README.md).
