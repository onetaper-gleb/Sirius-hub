from contextlib import asynccontextmanager
import fastapi
from fastapi.staticfiles import StaticFiles
import os
import json
import base64
from dotenv import load_dotenv

load_dotenv()

from database.database import engine, Base
from database import models

import firebase_admin
from firebase_admin import credentials

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

import schedule
import auth
import news
import profiles
import forum

os.makedirs("uploads", exist_ok=True)

@asynccontextmanager
async def lifespan(app: fastapi.FastAPI):
    print("Инициализация таблиц БД...")
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    print("БД готова!")
    yield

app = fastapi.FastAPI(
    title="CampusHub",
    version="0.0.0",
    lifespan=lifespan
)

app.mount("/static", StaticFiles(directory="uploads"), name="static")
app.include_router(auth.router)
app.include_router(profiles.router)
app.include_router(news.router)
app.include_router(schedule.router)
app.include_router(forum.forum_router)
app.include_router(forum.topic_router)
