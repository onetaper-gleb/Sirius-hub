import os
import subprocess
import sys
from pathlib import Path

from sqlalchemy import create_engine, text

BACKEND = Path(__file__).resolve().parents[1]


def migrate(db_path, revision):
    env = {**os.environ, "DATABASE_URL": f"sqlite+aiosqlite:///{db_path}"}
    subprocess.run(
        [sys.executable, "-m", "alembic", "upgrade", revision],
        cwd=BACKEND,
        env=env,
        check=True,
        capture_output=True,
    )


def test_clean_install_and_existing_firebase_user_upgrade(tmp_path):
    db_path = tmp_path / "migration.db"
    migrate(db_path, "5a1e237bc965")
    engine = create_engine(f"sqlite:///{db_path}")
    with engine.begin() as conn:
        conn.execute(
            text(
                "INSERT INTO users (id, email, role) VALUES ('existing', 'Existing@example.com', 'council'), ('no-email', NULL, NULL)"
            )
        )
    engine.dispose()
    migrate(db_path, "head")
    engine = create_engine(f"sqlite:///{db_path}")
    with engine.connect() as conn:
        user = conn.execute(
            text(
                "SELECT id, role, hashed_password, is_active FROM users WHERE id='existing'"
            )
        ).one()
        assert tuple(user) == ("existing", "council", "!", 1)
        assert (
            conn.scalar(text("SELECT role FROM users WHERE id='no-email'")) == "student"
        )
    engine.dispose()
    migrate(tmp_path / "clean.db", "head")
