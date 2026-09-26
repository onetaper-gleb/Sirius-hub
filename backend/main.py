import base64
import json
import os
from contextlib import asynccontextmanager

import fastapi
from dotenv import load_dotenv
from fastapi.staticfiles import StaticFiles

load_dotenv()

import firebase_admin
from firebase_admin import credentials

from database import models
from database.database import Base, engine
from utils.logger import set_logger


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
set_logger()

import auth
import forum
import manage_roles
import news
import newsoffers
import profiles
import schedule

os.makedirs("uploads", exist_ok=True)


@asynccontextmanager
async def lifespan(app: fastapi.FastAPI):
    print("Инициализация таблиц БД...")
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    print("БД готова!")
    yield


app = fastapi.FastAPI(title="CampusHub", version="0.0.0", lifespan=lifespan)

app.mount("/static", StaticFiles(directory="uploads"), name="static")
app.include_router(auth.router)
app.include_router(profiles.router)
app.include_router(news.router)
app.include_router(schedule.router)
app.include_router(forum.forum_router)
app.include_router(forum.topic_router)
app.include_router(manage_roles.router)
app.include_router(newsoffers.router)
