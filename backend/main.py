import os
from contextlib import asynccontextmanager

import fastapi
from dotenv import load_dotenv
from fastapi.staticfiles import StaticFiles
from sqlalchemy import text

load_dotenv()

from database.database import engine
from utils.logger import set_logger

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
    try:
        async with engine.connect() as conn:
            await conn.execute(text("SELECT 1"))
        yield
    finally:
        await engine.dispose()


app = fastapi.FastAPI(title="SiriusHub", version="0.0.0", lifespan=lifespan)
app.mount("/static", StaticFiles(directory="uploads"), name="static")
app.include_router(auth.router)
app.include_router(profiles.router)
app.include_router(news.router)
app.include_router(schedule.router)
app.include_router(forum.forum_router)
app.include_router(forum.topic_router)
app.include_router(manage_roles.router)
app.include_router(newsoffers.router)
