from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from firebase_admin import auth

from app.core.firebase import init_firebase

security = HTTPBearer(auto_error=False)


async def get_current_user_uid(
    credentials: HTTPAuthorizationCredentials | None = Depends(security),
) -> str:
    """
    Verifies Firebase ID token (from Flutter: user.getIdToken()).
    Send header: Authorization: Bearer <id_token>
    """
    if credentials is None or not credentials.credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or invalid Authorization header",
            headers={"WWW-Authenticate": "Bearer"},
        )

    init_firebase()
    try:
        decoded = auth.verify_id_token(credentials.credentials)
        uid = decoded.get("uid")
        if not uid:
            raise HTTPException(status_code=401, detail="Invalid token payload")
        return uid
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid Firebase ID token: {e!s}",
        ) from e
