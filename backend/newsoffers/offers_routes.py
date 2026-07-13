from fastapi import APIRouter
from typing import List, Optional
from .schemas import OfferEventResponse, OfferNewsResponse, OfferNewsEventsRequest, AdminModRequest

router = APIRouter(
    prefix="/offers",
    tags=["Offers"],
)

@router.post("/offers", response_model=OfferNewsResponse)
async def create_offer():
    pass

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