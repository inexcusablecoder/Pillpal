from fastapi import APIRouter, HTTPException, Depends, Request
from fastapi.responses import JSONResponse
from deep_translator import GoogleTranslator
from typing import List
import logging

from app.core.deps import get_current_user
from app.models.user import User

router = APIRouter()
logger = logging.getLogger("pillpal.translate")

MAX_CHARS = 4800

def split_chunks(texts, max_chars=MAX_CHARS):
    chunks, current, length = [], [], 0
    for t in texts:
        t = t.strip()
        if not t:
            continue

        if len(t) > max_chars:
            t = t[:max_chars]

        if length + len(t) > max_chars:
            chunks.append(current)
            current, length = [t], len(t)
        else:
            current.append(t)
            length += len(t)

    if current:
        chunks.append(current)

    return chunks

@router.get("/get-language")
async def get_language(current_user: User = Depends(get_current_user)):
    return {"lang": current_user.language}

@router.post("/translate")
async def translate(data: dict, current_user: User = Depends(get_current_user)):
    texts = data.get("texts")
    lang = data.get("lang") or current_user.language

    if not texts or not lang:
        return JSONResponse({"error": "Missing texts or lang"}, status_code=400)

    try:
        translated_all = []

        for chunk in split_chunks(texts):
            # ---------- SAFE PLACEHOLDER JOIN ----------
            placeholder_text = []
            for i, t in enumerate(chunk):
                placeholder_text.append(f"__TXT{i}__{t}")

            joined = "\n".join(placeholder_text)
            
            # Using deep_translator
            translated = GoogleTranslator(source="en", target=lang).translate(joined)

            # ---------- SAFE SPLIT ----------
            for i in range(len(chunk)):
                marker = f"__TXT{i}__"
                start = translated.find(marker)

                if start == -1:
                    translated_all.append(chunk[i])
                    continue

                start += len(marker)

                # find next marker
                next_pos = min(
                    [
                        translated.find(f"__TXT{j}__", start)
                        for j in range(i + 1, len(chunk))
                        if translated.find(f"__TXT{j}__", start) != -1
                    ] or [len(translated)]
                )

                translated_all.append(translated[start:next_pos].strip())

        return {"translated": translated_all}

    except Exception as e:
        logger.error(f"Translation API Error: {e}")
        return JSONResponse({"error": str(e)}, status_code=500)
