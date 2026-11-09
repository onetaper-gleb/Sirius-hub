import argparse
import asyncio
import getpass
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from sqlalchemy import func, select

from auth.security import get_password_hash
from database.database import AsyncSessionLocal, engine
from database.models import User, UserRole


async def update_account(email: str, role: str | None, reset_password: bool) -> None:
    try:
        async with AsyncSessionLocal() as session:
            user = await session.scalar(
                select(User).where(func.lower(User.email) == email.strip().lower())
            )
            if user is None:
                raise ValueError("User not found.")
            if reset_password:
                password = getpass.getpass("New password: ")
                if not 8 <= len(password) <= 64:
                    raise ValueError("The password must contain 8 to 64 characters.")
                if password != getpass.getpass("Repeat password: "):
                    raise ValueError("The passwords do not match.")
                user.hashed_password = get_password_hash(password)
            if role:
                user.role = role
            await session.commit()
    finally:
        await engine.dispose()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Update a local account with database administrator access."
    )
    parser.add_argument("email")
    parser.add_argument("--role", choices=[role.value for role in UserRole])
    parser.add_argument("--set-password", action="store_true")
    args = parser.parse_args()
    if not args.role and not args.set_password:
        parser.error("Set --role or --set-password.")
    try:
        asyncio.run(update_account(args.email, args.role, args.set_password))
    except ValueError as error:
        parser.exit(1, f"{error}\n")
