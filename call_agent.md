# 📞 Twilio Call Agent Implementation Details

PillPal uses Twilio for automated voice call reminders. This document outlines the backend architecture, configuration, and frontend integration details.

## 🔐 Credentials & Environment Variables
The following variables must be configured in `backend/.env`:
*   `TWILIO_ACCOUNT_SID`: Your Twilio Account SID.
*   `TWILIO_AUTH_TOKEN`: Your Twilio Auth Token.
*   `TWILIO_NUMBER`: The E.164 formatted number purchased from Twilio (e.g., `+13186682458`).

## 🏗️ Backend logic (`backend/app/services/twilio_calls.py`)

### 1. The Scheduling Engine
- **Library**: Uses the Python `schedule` library.
- **Threading**: Runs in a dedicated background `Daemon Thread` that starts when the FastAPI application initializes.
- **Dynamic Updates**:
    - When a user **Saves, Edits, or Deletes** a schedule via the frontend, the backend calls `load_jobs()`.
    - This function clears the current in-memory schedule and reloads all entries from the `call_schedules` table in the database to ensure the queue is always up-to-date.

### 2. Dual-Mode Voice Execution
PillPal supports two types of voice content, selectable in the UI:

#### 🔊 Audio Playback Mode (`audio`)
- **Logic**: The agent initiates a call and uses the `<Play>` TwiML verb.
- **Default**: If no `audio_url` is provided, it plays a hardcoded MP3 hosted on GitHub.
- **Custom**: Users can provide a link to a specific MP3 (e.g., a recording of their voice).

#### 🗣️ Text-to-Speech Mode (`text`)
- **Logic**: The agent initiates a call and uses the `<Say>` TwiML verb.
- **Voice**: Configured for a pleasant, neutral female voice (`language="en-IN"`).
- **Content**: Reads the custom `message` string saved in the schedule.

## 📊 Database Schema (`call_schedules` table)
| Column Name | Type | Description |
| :--- | :--- | :--- |
| `id` | SERIAL | Primary Key |
| `phone` | VARCHAR | Target E.164 number |
| `times` | TEXT | Comma-separated 24h times (e.g., "08:00,20:00") |
| `call_type` | VARCHAR | `"audio"` or `"text"` |
| `message` | TEXT | Custom message for TTS |
| `audio_url` | TEXT | Direct link to MP3 file |
| `start_date` | DATE | Validity start |
| `end_date` | DATE | Validity end |

## 📱 Frontend Integration (`frontend/pillpal_app/lib/screens/profile/`)

### 🛠️ Call Management UI
- **Choice Chips**: Provides a toggle between "Audio/MP3" and "Text Speech" to dynamically hide/show relevant input fields.
- **Persistence**: Remembers the last used phone number for convenience.
- **List View**: Displays all active schedules with icons representing the call type (🔊 for audio, 🗣️ for text).

### 🤖 AI Chatbot (`frontend/pillpal_app/lib/widgets/ai_chat_widget.dart`)
- **Placement**: Fixed `floatingActionButton` in the bottom-right corner.
- **Backend**: Proxies messages to the Groq Llama 3 API via the `/ai/chat` endpoint.
- **Experience**: Premium UI with glassmorphic bubbles and custom bot icons.

## 🚀 How to Setup
1. Create a [Twilio Account](https://www.twilio.com).
2. Configure `.env` with your SID, Token, and Number.
3. Ensure the `groq_api_key` is also present for the chatbot.
4. Restart the backend service.
5. In the app, go to **Profile > Configure Twilio Call** to schedule your first reminder.
