### SiriusHub

SiriusHub — мобильное приложение и backend-сервис для кампуса/университета: **новости**, **расписание**, **профили**, **форум/темы/комментарии**.  
Репозиторий содержит два основных модуля:

- **`client/`**: Flutter-приложение SiriusHub (BLoC + Dio + JWT/Firebase Auth)
- **`backend/`**: FastAPI API-сервис (PostgreSQL + SQLAlchemy async + JWT)

**Документация frontend (разработчик + пользователь):** [`client/README.md`](client/README.md)

---

### Архитектура (высокоуровнево)

**Client (Flutter)**:

- Авторизация через **JWT** (email/password) для текущего backend; вход в UI через `AuthGate`. Режим Firebase оставлен для прежнего backend.
- Слои: `module` (UI) → `domain` (BLoC/модели) → `data` (Repository + AuthDataSource) → `network` (Dio)
- DI через `DependenciesScope` (`client/lib/core/dependencies.dart`)
- Для этого backend нужен режим JWT: `--dart-define=AUTH_BACKEND=jwt`. URL API по умолчанию — `https://104.143.201.57`.
- Базовый URL backend: `client/lib/core/api_config.dart`
- Роли в UI: `student` (базовый доступ), `council` и `admin` (создание новостей и тем форума, модерация)

**Backend (FastAPI)**:

- Проверка пользователя по **JWT access token** (HS256). Пароли хранятся как Argon2-хеши.
- Контракты API и миграция аккаунтов: [`backend/README.md`](backend/README.md).
- Данные хранятся в **PostgreSQL** (async SQLAlchemy + asyncpg)
- Картинки новостей сохраняются в `backend/uploads/` и отдаются как статика по `/static/...`
- Перед запуском backend применяются миграции Alembic (`alembic upgrade head`).

**Инфраструктура**:

- Для backend есть `backend/docker-compose.yml` (Postgres + FastAPI)
- CI в GitHub Actions форматирует код, запускает тесты и деплоит backend на сервер по SSH (см. `.github/workflows/deploy.yml`)

---

### Стек

- **Mobile (client)**: Flutter, Dart `^3.11`, bloc/flutter_bloc, dio, shared_preferences, firebase_core, firebase_auth, image_picker, cached_network_image, flutter_native_splash
- **Backend**: FastAPI, Uvicorn, SQLAlchemy 2 (async), asyncpg, Alembic, PyJWT, pwdlib/Argon2, python-dotenv, pytest, Pillow
- **DB**: PostgreSQL 15

---

### Модули backend и маршруты API (основные)

Backend запускается как FastAPI-приложение `backend/main.py` и подключает роутеры:

- **Auth** (`/auth/*`):
  - `POST /auth/register` — создать локальный аккаунт и получить JWT
  - `POST /auth/token` — войти по email и паролю
  - `GET /auth/me` — текущий аккаунт
  - `POST /auth/promote-user` — изменить роль пользователя (только `admin`, роль проверяется в PostgreSQL)
- **Profile** (`/profile/*`):
  - `GET /profile/me` — профиль текущего пользователя
  - `PUT /profile/update` — обновление профиля
  - `PATCH /profile/avatar` — обновление аватар-эмодзи
  - `GET /profile/user/{user_id}` — публичный профиль пользователя
- **News** (`/news/*`):
  - `GET /news/` — список новостей
  - `POST /news/` — создание новости (для `council` и `admin`), изображение передаётся строкой Base64 в JSON-поле `image`
  - `DELETE /news/{news_id}` — удаление новости (`council` и `admin`)
- **Schedule** (`/schedule/*`):
  - `GET /schedule?group=...&week_offset=...` — расписание группы (парсинг внешнего источника)
- **Forum/Topic**:
  - `GET /forum/topics`, `POST /forum/topics` — список/создание тем (создание — `council` и `admin`)
  - `GET /topic/comments?topic_id=...`, `POST /topic/comments` — комментарии в теме

**Предложки** (`/offers/*`):

- `POST /offers/offers` — создаёт черновик; JSON содержит `title`, `content`, `contacts_author` и необязательные поля события, темы и Base64-изображения `image`
- `GET /offers/offers/my`, `GET /offers/offers/{offer_id}` — свои предложки; чужую предложку могут читать только `council` и `admin`
- `PUT /offers/offers/{offer_id}`, `PATCH /offers/offers/{offer_id}/submit` — автор правит черновик или доработку и отправляет на модерацию
- `GET /offers/admin/offers`, `PATCH /offers/admin/offers/{offer_id}/moderate` — очередь и решение модератора; доступны `council` и `admin`
- При одобрении backend создаёт новость, событие и тему в одной транзакции. Ответ содержит предложку со статусом `approved`.

Регистрация на событие занимает место в статусах `moderation` и `confirmed`; `waiting_list` и отменённые регистрации места не занимают.
`POST /news/events/{event_id}/register` принимает `application/x-www-form-urlencoded` с необязательным полем `comment`: не более 50 кодовых точек Unicode. Отсутствующее или пустое поле сохраняется как `null`. Более длинный комментарий возвращает 422 до изменения регистрации и числа участников; сервер не обрезает текст.
Расписание возвращает семь дней выбранной недели, включая пустые дни. Поиск свободных аудиторий принимает `date=YYYY-MM-DD`, `start_time=HH:MM`, `end_time=HH:MM`, не дальше десяти недель от текущей.

**Документация API (Swagger/OpenAPI)** доступна на:

- `GET /docs`
- `GET /openapi.json`

---

### Переменные окружения (backend)

См. пример: `backend/.env.example`

- **`JWT_SECRET_KEY`**: случайный секрет не короче 32 байт.
- **`ACCESS_TOKEN_EXPIRE_MINUTES`**: срок действия JWT, по умолчанию 60 минут.
- **`DB_USER`**, **`DB_PASSWORD`**, **`DB_NAME`**: параметры Postgres
- **`DB_HOST`**: хост БД (по умолчанию `db` — имя сервиса в Docker Compose)
- **`DB_PORT`**: порт PostgreSQL (по умолчанию `5432`)
- **`DATABASE_URL`**: явный URL подключения, имеет приоритет над `DB_*`; для локальной SQLite нужен драйвер `sqlite+aiosqlite`

---

### Запуск backend (Docker Compose, рекомендовано)

Требования: Docker + Docker Compose.

1) Создайте файл `backend/.env` на базе примера:

- Скопируйте `backend/.env.example` → `backend/.env`
- Заполните значения

2) Запустите сервисы:

```bash
cd backend
docker compose up -d --build
```

По умолчанию:

- **API**: `http://localhost:56284`
- **Postgres**: `localhost:5454` (внутри compose: `db:5432`)

API и PostgreSQL публикуются только на loopback хоста. Для внешнего доступа настройте HTTPS reverse proxy к `http://127.0.0.1:56284`.

Изображения хранятся в `backend/uploads/`, подключённом к `/app/uploads`; пересоздание контейнера сохраняет файлы.
При первом переходе со старого контейнера остановите API и скопируйте `/app/uploads/.` из контейнера в `backend/uploads/` до пересоздания.
Workflow деплоя переносит эти файлы автоматически. На SSH-хосте нужен Python 3; файл `.env` workflow записывает в формате Docker Compose.
Для административных команд используйте окружение контейнера: сгенерированный `.env` экранирует символ `$` для Compose.
Удалённый seed-скрипт содержал общие пароли привилегированных тестовых аккаунтов. Если его запускали, оператор должен отключить эти аккаунты или сменить их пароли.

---

### Запуск backend (локально без Docker)

Требования: Python 3.12, как в CI и Docker, установленный Postgres (или используйте Docker только для БД).

```bash
cd backend
python -m venv .venv
# активируйте окружение:
# - Windows (PowerShell): .venv\Scripts\Activate.ps1
# - Windows (cmd): .venv\Scripts\activate.bat
# - macOS/Linux: source .venv/bin/activate
pip install -r requirements.txt
alembic upgrade head
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Если вы запускаете Postgres не через compose, убедитесь что выставлены `DB_*`/`DATABASE_URL`.

---

### Запуск client (Flutter)

Требования: Flutter SDK (stable), Dart `^3.11`, настроенная платформа (Android Studio/Xcode), Firebase-конфиг в репозитории.

```bash
cd client
flutter pub get
flutter run --dart-define=AUTH_BACKEND=jwt
```

Backend URL задаётся в `client/lib/core/api_config.dart` (по умолчанию — адрес деплоя).

Полные инструкции (документация разработчика и пользователя frontend): [`client/README.md`](client/README.md).

---

### Документация frontend (кратко)

| Тип | Где | Содержание |
|-----|-----|------------|
| **Пользовательская** | [`client/README.md`](client/README.md) → «Документация пользователя» | Роли, регистрация/вход, вкладки (новости, форум, расписание, профиль), типичные сценарии |
| **Разработчика** | [`client/README.md`](client/README.md) → «Документация разработчика» | Стек, архитектура слоёв, структура `lib/`, Firebase, URL API, запуск, тесты, сборка, troubleshooting |

---

### Тесты и форматирование

**Client**:

```bash
cd client
dart format lib test
flutter analyze
flutter test
```

**Backend**:

```bash
cd backend
pip install -r requirements-dev.txt
black --check .
isort --check-only .
cd ..
bazel test //backend:backend_tests --test_env=BACKEND_TEST_PYTHON="$(command -v python)" --test_env=DART="$(command -v dart)" --test_output=errors
```

Для Bazel установите Bazelisk и Dart 3.12. Цель запускает pytest через Dart; API-тесты используют SQLite и JWT с тестовым ключом.
Прямой запуск тех же тестов: `cd backend && python -m pytest tests`.

Также настроены pre-commit хуки (`.pre-commit-config.yaml`) для форматирования Python-кода в `backend/`.

---

### CI/CD (кратко)

Проверки и деплой разделены:

- `.github/workflows/backend.yml` проверяет формат Python и запускает backend-тесты через Bazel для PR
- `.github/workflows/client.yml` проверяет Flutter
- `.github/workflows/deploy.yml` собирает контейнер, сохраняет изображения и запускает backend по SSH при пуше в `main`

---

### Структура репозитория

- **`client/`** — Flutter-приложение SiriusHub
  - `README.md` — документация разработчика и пользователя (frontend)
  - `lib/main.dart` — точка входа
  - `lib/module/` — UI: auth, news, forum, schedule, profile
  - `lib/domain/` — BLoC и модели
  - `lib/data/` — repositories и Firebase/JWT Auth data sources
  - `lib/network/`, `lib/core/` — Dio и конфиг API
  - `test/` — unit/widget-тесты
- **`backend/`** — FastAPI backend
  - `main.py` — точка входа приложения, подключение роутеров
  - `auth/`, `profiles/`, `news/`, `schedule/`, `forum/` — доменные модули/роуты
  - `database/` — подключение к БД и ORM-модели
  - `tests/` — тесты pytest

---

### Частые проблемы

- **401 Unauthorized**: проверьте JWT в `Authorization: Bearer <access_token>` и срок его действия.
- **Старый Firebase-аккаунт не входит**: администратор должен установить локальный пароль по [`backend/README.md`](backend/README.md).
- **Client не достучится до API**: проверьте `client/lib/core/api_config.dart` и сеть устройства/эмулятора (см. [`client/README.md`](client/README.md)).

