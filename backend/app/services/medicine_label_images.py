from __future__ import annotations

import mimetypes
import secrets
import uuid
from pathlib import Path

from fastapi import HTTPException, UploadFile, status

from app.core.config import BACKEND_ROOT, settings

_ALLOWED_CT = frozenset(
    {
        "image/jpeg",
        "image/png",
        "image/webp",
        "image/jpg",
    }
)
_EXT = {".jpg": ".jpg", ".jpeg": ".jpg", ".png": ".png", ".webp": ".webp"}


def mime_for_storage_key(key: str) -> str:
    suf = Path(key).suffix.lower()
    if suf in (".jpg", ".jpeg"):
        return "image/jpeg"
    if suf == ".png":
        return "image/png"
    if suf == ".webp":
        return "image/webp"
    return "image/jpeg"


def _upload_root() -> Path:
    p = Path(settings.medicine_label_upload_dir)
    if not p.is_absolute():
        p = BACKEND_ROOT / p
    return p


def ensure_upload_dir() -> Path:
    root = _upload_root()
    root.mkdir(parents=True, exist_ok=True)
    return root


def file_path_for_key(key: str) -> Path:
    """Resolve storage path; reject path traversal."""
    name = Path(key).name
    if name != key or ".." in key or "/" in key or "\\" in key:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid key")
    return ensure_upload_dir() / name


def delete_stored_file(key: str | None) -> None:
    if not key:
        return
    path = file_path_for_key(key)
    try:
        if path.is_file():
            path.unlink()
    except OSError:
        pass


def guess_extension(content_type: str | None, filename: str | None) -> str:
    ext = None
    if filename:
        suf = Path(filename).suffix.lower()
        if suf in _EXT:
            ext = _EXT[suf]
    if ext is None and content_type:
        if content_type in ("image/jpeg", "image/jpg"):
            ext = ".jpg"
        elif content_type == "image/png":
            ext = ".png"
        elif content_type == "image/webp":
            ext = ".webp"
    if ext is None:
        guessed, _ = mimetypes.guess_type(filename or "")
        if guessed == "image/jpeg":
            ext = ".jpg"
        elif guessed == "image/png":
            ext = ".png"
        elif guessed == "image/webp":
            ext = ".webp"
    if ext is None:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail="Use JPEG, PNG, or WebP",
        )
    return ext


async def read_label_upload_bytes(file: UploadFile) -> tuple[bytes, str]:
    """Validate and read image bytes for in-memory use (e.g. AI preview). Returns (bytes, content_type)."""
    ct = (file.content_type or "").split(";")[0].strip().lower()
    if ct not in _ALLOWED_CT and ct != "image/jpg":
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail="Use JPEG, PNG, or WebP",
        )
    guess_extension(file.content_type, file.filename)
    raw = await file.read()
    if len(raw) > settings.medicine_label_max_bytes:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=f"Image too large (max {settings.medicine_label_max_bytes // (1024 * 1024)} MB)",
        )
    if ct == "image/jpg":
        ct = "image/jpeg"
    return raw, ct


async def save_label_upload(medicine_id: uuid.UUID, file: UploadFile) -> str:
    ct = (file.content_type or "").split(";")[0].strip().lower()
    if ct not in _ALLOWED_CT and ct != "image/jpg":
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail="Use JPEG, PNG, or WebP",
        )
    ext = guess_extension(file.content_type, file.filename)
    raw = await file.read()
    if len(raw) > settings.medicine_label_max_bytes:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=f"Image too large (max {settings.medicine_label_max_bytes // (1024 * 1024)} MB)",
        )
    token = secrets.token_hex(8)
    key = f"{medicine_id}_{token}{ext}"
    path = ensure_upload_dir() / key
    path.write_bytes(raw)
    return key
