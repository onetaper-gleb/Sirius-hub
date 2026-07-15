from fastapi import APIRouter
from typing import List, Optional
from .schemas import OfferEventResponse, OfferNewsResponse, OfferNewsEventsRequest, AdminModRequest
import io
import os
import uuid
from typing import List, Optional
import datetime

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from PIL import Image
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from auth.auth_routes import get_current_user, require_council_role
from database.database import get_db
from database.models import News, Events, OfferNews, OfferEvent, Registrations, RegStatus, EventStatus

from news.news_routes import process_image, delete_old_image, validate_event_data


router = APIRouter(
    prefix="/offers",
    tags=["Offers"],
)

# @router.post("/offers", response_model=OfferNewsResponse)
# async def create_offer(
#     request: OfferNewsEventsRequest,
#     image: UploadFile = File(None),
#     user: dict = Depends(require_council_role),
#     db: AsyncSession = Depends(get_db),
# ):
#     image_url = await process_image(image)

#     new_offer = OfferNews(
#         title=request.title, 
#         content=request.content, 
#         image_url=image_url, 
#         author_id=user.get("uid"), 
#         contacts_author=request.contacts_author,
#         is_event=request.is_event,
#         event_id=None,
#         status_mod='moderation',
#         admin_id=None,
#         comment_admin=None
#     )

#     db.add(new_offer)
#     await db.flush()

#     if request.is_event:
#         await validate_event_data(request, db)
        
#         new_event = Events(
#             status=request.event_status, 
#             event_start=request.event_start, 
#             event_end=request.event_end, 
#             location=request.location, 
#             max_partic=request.max_partic, 
#             cur_partic=0, 
#             is_reg_open=request.is_reg_open,
#             news_id=new_offer.id
#         )

#         db.add(new_event)
#         await db.flush()
#         new_offer.event_id = new_event.id
#         db.add(new_offer)

#     await db.commit()
#     await db.refresh(new_offer)
#     if request.is_event:
#         await db.refresh(new_event)

#     return new_offer
    

@router.get("/admin/offers", response_model=List[OfferNewsResponse])
async def get_all_offers():
    pass

@router.get("/offers/my", response_model=List[OfferNewsResponse])
async def get_my_offers():
    pass

@router.get("/offers/{offer_id}", response_model=OfferNewsResponse)
async def get_offer():
    pass

@router.patch("/admin/offers/{offer_id}/moderate", response_model=OfferNewsResponse)
async def moderate_offer():
    pass

@router.put("/admin/offers/{offer_id}", response_model=OfferNewsResponse)
async def update_offer():
    pass

@router.put("/offers/{offer_id}", response_model=OfferNewsResponse) # draft only
async def update_my_offer():
    pass

@router.patch("/offers/{offer_id}/submit", response_model=OfferNewsResponse)
async def submit_for_moderation():
    pass

@router.delete("/offers/{offer_id}")
async def delete_offer():
    pass