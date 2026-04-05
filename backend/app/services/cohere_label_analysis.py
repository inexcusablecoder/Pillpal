from __future__ import annotations

import base64
import json
import logging
import re
from typing import Any

import httpx

from app.core.config import settings

logger = logging.getLogger(__name__)

_LABEL_PROMPT = """You help users read medicine packaging in PillPal (a medication reminder app). You are not giving medical advice.

Analyze this photo of a medicine label, bottle, or box. Write a clear, friendly summary in markdown:

### What’s on the label
- Drug or product name, strength (e.g. mg, mcg), and form (tablet, capsule, liquid, etc.) only if you can read them.
- Any prominent warnings or “Rx only” style cues you can see.

### How to take (if printed)
- Short bullets quoting only what is clearly printed (dosage frequency, with food, etc.). If not visible, say it’s not readable.

### Readability
- Note if the photo is blurry, cropped, or glare makes text unreliable.

Rules: Do not invent names, doses, or instructions. If unsure, say so.

End with this exact line:
**Always confirm with your pharmacist or doctor before changing how you take any medicine.**"""

_PREVIEW_JSON_PROMPT = """You read medicine packaging for a reminder app (not medical advice).

Look at the image. Reply with a single JSON object only — no markdown code fences, no other text. Keys:
- "product_name": string, the clearest drug or product name you can read, or null if not readable
- "strength": string, only the strength line (e.g. "500 mg", "10 mL"), or null
- "form": string, one of "tablet", "capsule", "liquid", "injection", "other", or null
- "summary": string, one short sentence describing what is visible; say "unreadable" if the label is unclear

Rules: Use null when unsure. Do not invent names or doses."""


def _mime_for_bytes_hint(content_type: str) -> str:
    ct = (content_type or "image/jpeg").split(";")[0].strip().lower()
    if ct == "image/jpg":
        return "image/jpeg"
    if ct in ("image/jpeg", "image/png", "image/webp"):
        return ct
    return "image/jpeg"


def _extract_assistant_text(data: dict[str, Any]) -> str | None:
    msg = data.get("message")
    if not isinstance(msg, dict):
        return None
    content = msg.get("content")
    if isinstance(content, str):
        t = content.strip()
        return t or None
    if isinstance(content, list):
        parts: list[str] = []
        for block in content:
            if isinstance(block, dict) and block.get("type") == "text":
                parts.append(str(block.get("text") or ""))
        t = "".join(parts).strip()
        return t or None
    return None


def _parse_json_object(text: str) -> dict[str, Any] | None:
    t = text.strip()
    if t.startswith("```"):
        t = re.sub(r"^```(?:json)?\s*", "", t, flags=re.IGNORECASE)
        t = re.sub(r"\s*```\s*$", "", t)
    try:
        obj = json.loads(t)
    except json.JSONDecodeError:
        return None
    return obj if isinstance(obj, dict) else None


async def _cohere_vision_chat(prompt: str, image_bytes: bytes, content_type: str) -> str | None:
    key = (settings.cohere_api_key or "").strip()
    if not key:
        return None

    mime = _mime_for_bytes_hint(content_type)
    b64 = base64.standard_b64encode(image_bytes).decode("ascii")
    data_url = f"data:{mime};base64,{b64}"

    payload: dict[str, Any] = {
        "model": settings.cohere_vision_model,
        "messages": [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": prompt},
                    {
                        "type": "image_url",
                        "image_url": {"url": data_url, "detail": "high"},
                    },
                ],
            }
        ],
    }

    try:
        async with httpx.AsyncClient(timeout=httpx.Timeout(120.0, connect=30.0)) as client:
            r = await client.post(
                "https://api.cohere.ai/v2/chat",
                headers={
                    "Authorization": f"Bearer {key}",
                    "Content-Type": "application/json",
                    "Accept": "application/json",
                },
                json=payload,
            )
            r.raise_for_status()
            data = r.json()
    except httpx.HTTPStatusError as e:
        body = e.response.text[:800] if e.response is not None else ""
        logger.warning("Cohere HTTP %s: %s", e.response.status_code if e.response else "?", body)
        return None
    except (httpx.RequestError, ValueError, KeyError, TypeError) as e:
        logger.warning("Cohere request failed: %s", type(e).__name__)
        return None

    text = _extract_assistant_text(data) if isinstance(data, dict) else None
    if not text:
        logger.warning("Cohere response missing assistant text")
    return text


async def analyze_medicine_label(image_bytes: bytes, content_type: str) -> str | None:
    return await _cohere_vision_chat(_LABEL_PROMPT, image_bytes, content_type)


def _norm_str(v: Any) -> str | None:
    if v is None:
        return None
    if isinstance(v, str):
        t = v.strip()
        return t or None
    if isinstance(v, (int, float, bool)):
        return str(v)
    return None


async def analyze_label_preview_fields(image_bytes: bytes, content_type: str) -> dict[str, Any] | None:
    """Returns parsed JSON with product_name, strength, form, summary or None."""
    raw = await _cohere_vision_chat(_PREVIEW_JSON_PROMPT, image_bytes, content_type)
    if not raw:
        return None
    obj = _parse_json_object(raw)
    if not obj:
        logger.warning("Cohere preview response not valid JSON")
        return None
    return {
        "product_name": _norm_str(obj.get("product_name")),
        "strength": _norm_str(obj.get("strength")),
        "form": _norm_str(obj.get("form")),
        "summary": _norm_str(obj.get("summary")),
    }
