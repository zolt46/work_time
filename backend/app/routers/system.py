# File: /backend/app/routers/system.py
from fastapi import APIRouter, Depends, status
from fastapi.responses import JSONResponse
from sqlalchemy import text
from sqlalchemy.orm import Session

from ..deps import get_db

router = APIRouter(tags=["system"])


@router.get("/health")
def health_check(db: Session = Depends(get_db)):
    """간단한 서버·DB 연결 헬스체크 엔드포인트."""
    try:
        db.execute(text("SELECT 1"))
        return {"server_status": "ok", "db_status": "ok"}
    except Exception:  # pragma: no cover - runtime safety
        return JSONResponse(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            content={"server_status": "ok", "db_status": "error"},
        )
