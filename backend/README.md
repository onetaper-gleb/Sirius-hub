# Backend authentication

The API uses local email/password accounts and HS256 access tokens. Firebase tokens are not accepted.

## API

| Request | Body | Response |
| --- | --- | --- |
| `POST /auth/register` | JSON: `email`, `password`, optional `display_name` | `201`: `access_token`, `token_type: bearer` |
| `POST /auth/token` | Form: `username` (email), `password` | `200`: `access_token`, `token_type: bearer` |
| `GET /auth/me` | Bearer token | Account ID, email, role, display name, active status |
| `GET /profile/me` | Bearer token | Own profile |
| `PUT /profile/update` | Bearer token and profile JSON | Updated profile |
| `PATCH /profile/avatar` | Bearer token and `avatar_emoji` JSON | Updated profile |

Registration creates a student account immediately. There is no `/auth/init` step. Email matching ignores case. Passwords contain 8–64 characters and use Argon2. Profile responses never include password hashes. Public profiles omit email.

Clients send `Authorization: Bearer <access_token>`. Tokens expire after `ACCESS_TOKEN_EXPIRE_MINUTES` (default: 60, allowed: 1–10080). There is no refresh token endpoint. On expiry, clients must sign in again. Logout deletes the client token. It does not revoke a copied token before expiry. Deactivating the account blocks all its tokens. Role checks read the database on every request.

Only database administrators can bootstrap an application administrator. Application administrators can change roles with `/auth/promote-user` or `/roles/test-give_me_role`. The legacy role request's `admin_id` field has no authority. Students and council members cannot change roles.

## How to deploy password authentication

Prerequisites: PostgreSQL, Python 3.12, a database backup, and a mobile client with JWT authentication support.

1. Copy `.env.example` to `.env` and set the database credentials.
2. Generate a random `JWT_SECRET_KEY` of at least 32 bytes. For example, run `openssl rand -hex 32`.
3. Set the deployment secret `JWT_SECRET_KEY` when using the GitHub deployment workflow.
4. Check existing accounts for duplicate emails that differ only in case. Reconcile them before migration. The unique index rejects ambiguous email identities.
5. Run `docker compose up -d --build` from `backend/`. The API container runs `alembic upgrade head` before Uvicorn.
6. Set a new password for each former Firebase account through a trusted administrator process: `docker compose exec api python manage_roles/promote.py EMAIL --set-password`.
7. Bootstrap an administrator when needed: `docker compose exec api python manage_roles/promote.py EMAIL --role admin`.
8. Build the mobile client with `--dart-define=AUTH_BACKEND=jwt` and the configured backend URL.

External API requests must use the HTTPS reverse proxy. Compose binds the API and PostgreSQL to localhost.

For local startup, install `requirements-dev.txt`, run `alembic upgrade head`, then run `uvicorn main:app --reload`.

The migration keeps account IDs, profiles, roles, and foreign keys. Firebase password hashes cannot be transferred through this repository. Existing accounts receive an unusable password marker until an administrator sets their password. Registration cannot replace an existing email. New registrations receive new IDs. The removed development seed script must not be used to create privileged test accounts in production.

`DATABASE_URL` takes precedence over `DB_*`. Without either configuration, local development uses SQLite with `aiosqlite`. The privileged development seed script has been removed. The JWT secret must remain stable across restarts. Rotating it invalidates every existing token.

The deployment workflow writes a Compose `.env` file with dollar escaping. Run administrative commands inside the container. Local development can run the same Python CLI directly with a normal `.env` file.

The deployment workflow uses `deploy.sh` in the active Compose directory. It deploys the exact commit and rejects concurrent Docker operations. Before migration, it stops the API and saves a database dump, uploads, and a rollback image under `~/.local/state/sirius-hub/`. Recovery files stay on the server. Failed readiness checks restart the previous API image with Uvicorn directly, without rerunning its old Alembic migrations or downgrading the database. The script reports restoration only after the previous API responds to an OpenAPI request. If that check fails, it reports that manual recovery is required. After a JWT migration, the old Firebase image cannot create accounts with the new password schema. Correct the JWT deployment before accepting new registrations.
