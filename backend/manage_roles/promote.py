

from firebase_admin import auth, firestore
from sqlalchemy import update
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.models import User as DBUser

import sys
import os

import firebase_admin
from dotenv import load_dotenv
from firebase_admin import credentials
import json
import base64

load_dotenv()

def init_firebase():
    base64_config = os.getenv("FIREBASE_CONFIG_BASE64")
    if base64_config:
        decoded_bytes = base64.b64decode(base64_config)
        config_dict = json.loads(decoded_bytes)
        cred = credentials.Certificate(config_dict)
        firebase_admin.initialize_app(cred)
        print("Firebase инициализирован через Base64!")
    else:
        print("Base64 конфиг не найден, ищу файл...")
        cred = credentials.Certificate("firebase-adminsdk.json")
        firebase_admin.initialize_app(cred)

init_firebase()


db_firestore = firestore.client()
DATABASE_URL = os.getenv("DATABASE_URL")
engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(bind=engine)

def give_me_role(email, role_u):

    session = SessionLocal()

    try:
        user_record = auth.get_user_by_email(email)
        uid = user_record.uid
        auth.set_custom_user_claims(uid, {"role": role_u})

        stmt = update(DBUser).where(DBUser.uid == uid).values(role=role_u)
        session.execute(stmt)
        session.commit()

        user_ref = db_firestore.collection("users").document(uid)
        user_ref.update({"role": role_u})

        print(f"status: success; Роль обновлена везде!")
    
    except auth.UserNotFoundError:
        print(f"Ошибка: Пользователь с email '{email}' не найден")
        sys.exit(1)
    except Exception as e:
        session.rollback()
        print(f"Ошибка: {e}")
        sys.exit(1)

    finally:
        session.close()



if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Использование: python manage_roles.py EMAIL ROLE")
        print("Роли: student, council, admin, superadmin")
        sys.exit(1)

    email = sys.argv[1]
    role_u = sys.argv[2]

    valid_roles = ["student", "council", "admin", "superadmin"]
    if role_u not in valid_roles:
        print(f"Ошибка: роль '{role_u}' не существует")
        sys.exit(1)

    try:
        give_me_role(email, role_u)
    except Exception as e:
        print(f"Ошибка: {e}")
        sys.exit(1)