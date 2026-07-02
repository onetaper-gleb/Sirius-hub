### CampusHub

CampusHub — мобильное приложение и backend-сервис для кампуса/университета: **новости**, **расписание**, **профили**, **форум/темы/комментарии**.  
Репозиторий содержит два основных модуля:

- **`client/`**: Flutter-приложение (BLoC + Dio + Firebase Auth/Firestore)
- **`backend/`**: FastAPI API-сервис (PostgreSQL + SQLAlchemy async + Firebase Admin)

---

### Архитектура (высокоуровнево)

**Client (Flutter)**:

- Авторизация через **Firebase Auth**
- Работа с данными через слой **Repository** и **BLoC**
- HTTP-запросы в backend через **Dio**
- Базовый URL backend задаётся в `client/lib/core/api_config.dart`

**Backend (FastAPI)**:

- Проверка пользователя по **Firebase ID Token** (Bearer-токен) через `firebase_admin.auth.verify_id_token`
- Данные хранятся в **PostgreSQL** (async SQLAlchemy + asyncpg)
- Картинки новостей сохраняются в `backend/uploads/` и отдаются как статика по `/static/...`
- При старте backend создаёт таблицы (через `Base.metadata.create_all`)

**Инфраструктура**:

- Для backend есть `backend/docker-compose.yml` (Postgres + FastAPI)
- CI в GitHub Actions форматирует код, запускает тесты и деплоит backend на сервер по SSH (см. `.github/workflows/deploy.yml`)

---

### Стек

- **Mobile**: Flutter, Dart, bloc/flutter_bloc, dio, shared_preferences, firebase_core, firebase_auth, cloud_firestore
- **Backend**: FastAPI, Uvicorn, SQLAlchemy 2 (async), asyncpg, Alembic (зависимость есть), firebase-admin, python-dotenv, pytest, Pillow
- **DB**: PostgreSQL 15

---

### Модули backend и маршруты API (основные)

Backend запускается как FastAPI-приложение `backend/main.py` и подключает роутеры:

- **Auth** (`/auth/*`):
  - `POST /auth/init` — инициализация пользователя в БД и установка роли `student` в Firebase custom claims
  - `POST /auth/promote-user` — повысить пользователя до `council` (только для `council`)
  - `POST /auth/test-make-me-council` — временный тестовый эндпоинт (в коде помечен как TODO удалить)
- **Profile** (`/profile/*`):
  - `GET /profile/me` — профиль текущего пользователя (требует предварительный `POST /auth/init`)
  - `PUT /profile/update` — обновление профиля
  - `PATCH /profile/avatar` — обновление аватар-эмодзи
  - `GET /profile/user/{user_id}` — публичный профиль пользователя
- **News** (`/news/*`):
  - `GET /news/` — список новостей
  - `POST /news/` — создание новости (только `council`), поддерживает загрузку изображения (multipart)
  - `DELETE /news/{news_id}` — удаление новости (только `council`)
- **Schedule** (`/schedule/*`):
  - `GET /schedule?group=...&week_offset=...` — расписание группы (парсинг внешнего источника)
- **Forum/Topic**:
  - `GET /forum/topics`, `POST /forum/topics` — список/создание тем (создание — только `council`)
  - `GET /topic/comments?topic_id=...`, `POST /topic/comments` — комментарии в теме

**Документация API (Swagger/OpenAPI)** доступна на:

- `GET /docs`
- `GET /openapi.json`

---

### Переменные окружения (backend)

См. пример: `backend/.env.example`

- **`FIREBASE_CONFIG_BASE64`**: Base64 от JSON service account (Firebase Admin SDK).  
  Если не задан, backend попытается прочитать файл `backend/firebase-adminsdk.json`.
- **`DB_USER`**, **`DB_PASSWORD`**, **`DB_NAME`**: параметры Postgres
- **`DB_HOST`**: хост БД (по умолчанию `db` — имя сервиса в Docker Compose)

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

---

### Запуск backend (локально без Docker)

Требования: Python (лучше 3.12, как в CI), установленный Postgres (или используйте Docker только для БД).

```bash
cd backend
python -m venv .venv
# активируйте окружение:
# - Windows (PowerShell): .venv\Scripts\Activate.ps1
# - Windows (cmd): .venv\Scripts\activate.bat
# - macOS/Linux: source .venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Если вы запускаете Postgres не через compose, убедитесь что выставлены `DB_*`/`DATABASE_URL`.

---

### Запуск client (Flutter)

Требования: Flutter SDK (stable), настроенная платформа (Android Studio/Xcode), и Firebase-конфигурация проекта.

```bash
cd client
flutter pub get
flutter run
```

Backend URL задаётся в `client/lib/core/api_config.dart` (по умолчанию там указан домен деплоя).

---

### Тесты и форматирование

**Client**:

```bash
cd client
dart format lib test
flutter test
```

**Backend**:

```bash
cd backend
pip install -r requirements-dev.txt
black backend
isort backend
pytest
```

Также настроены pre-commit хуки (`.pre-commit-config.yaml`) для форматирования Python-кода в `backend/`.

---

### CI/CD (кратко)

Workflow `.github/workflows/deploy.yml` делает:

- форматирование Dart + Python
- тесты Flutter и pytest
- деплой backend на сервер по SSH при пуше в `main` (через `docker compose up -d --build` в `backend/`)

---

### Структура репозитория

- **`client/`** — Flutter-приложение
  - `lib/` — код приложения (domain/data/module/network и т.п.)
- **`backend/`** — FastAPI backend
  - `main.py` — точка входа приложения, подключение роутеров
  - `auth/`, `profiles/`, `news/`, `schedule/`, `forum/` — доменные модули/роуты
  - `database/` — подключение к БД и ORM-модели
  - `tests/` — тесты pytest

---

### Частые проблемы

- **401 Unauthorized**: проверьте что запросы идут с `Authorization: Bearer <Firebase ID Token>`.
- **Профиль не найден** на `GET /profile/me`: сначала вызовите `POST /auth/init`.
- **Firebase Admin**: если не используете `FIREBASE_CONFIG_BASE64`, положите `firebase-adminsdk.json` рядом с `backend/main.py`.

