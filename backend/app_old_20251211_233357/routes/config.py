from fastapi import APIRouter
from ..config import get_config_status
from ..schemas import ConfigStatus

router = APIRouter(prefix="/config", tags=["config"])

@router.get("", response_model=ConfigStatus)
async def read_config():
    return get_config_status()
