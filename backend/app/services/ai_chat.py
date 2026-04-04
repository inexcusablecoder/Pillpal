from typing import List, Optional
from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from groq import AsyncGroq
from app.core.config import settings
from app.models.user import User
from app.core.deps import get_current_user
import logging

logger = logging.getLogger(__name__)

router = APIRouter(tags=["ai_chat"])

# ==============================
# 📦 SCHEMAS
# ==============================
class ChatMessage(BaseModel):
    role: str # "user" or "assistant"
    content: str

class ChatRequest(BaseModel):
    messages: List[ChatMessage]
    model: Optional[str] = "llama-3.3-70b-versatile"

class ChatResponse(BaseModel):
    response: str

# ==============================
# 🤖 CHAT SERVICE
# =============0================
async def get_groq_client():
    if not settings.groq_api_key:
        return None
    return AsyncGroq(api_key=settings.groq_api_key)

SYSTEM_PROMPT = """You are PillPal Assistant, a premium AI health companion.
Your goal is to help users manage their medications and stay healthy.
Key personality traits:
- Empathetic and professional.
- Concise but thorough where necessary.
- Knowledgeable about medication adherence, PillPal's role (reminders, tracking), and general wellness.
- Always remind users to consult a real doctor for serious medical concerns.
Match the PillPal clinical blue aesthetic with your clinical yet friendly tone."""

@router.post("/chat", response_model=ChatResponse)
async def chat(request: ChatRequest, client: AsyncGroq = Depends(get_groq_client), current_user: User = Depends(get_current_user)):
    if not client:
        raise HTTPException(status_code=500, detail="Groq API key not configured. Please add GROQ_API_KEY to .env")

    # System prompt can be personalized based on user language
    lang_info = f" The user's preferred language is {current_user.language}. Please respond in that language if possible."
    
    groq_messages = [{"role": "system", "content": SYSTEM_PROMPT + lang_info}]
    for msg in request.messages:
        groq_messages.append({"role": msg.role, "content": msg.content})

    models_to_try = [request.model, "llama3-70b-8192", "mixtral-8x7b-32768"]
    
    last_error = None
    for model in models_to_try:
        try:
            completion = await client.chat.completions.create(
                messages=groq_messages,
                model=model,
                temperature=0.7,
                max_tokens=1024,
            )
            reply = completion.choices[0].message.content
            return ChatResponse(response=reply)
        except Exception as e:
            logger.error(f"❌ Groq API Error with model {model}: {e}")
            last_error = e
            continue

    raise HTTPException(status_code=500, detail=f"AI Chat error: {str(last_error)}")
