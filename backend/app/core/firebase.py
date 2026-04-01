import os

import firebase_admin
from firebase_admin import credentials, firestore


def init_firebase() -> None:
    if firebase_admin._apps:
        return

    cred_path = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS")
    if cred_path and os.path.isfile(cred_path):
        cred = credentials.Certificate(cred_path)
        firebase_admin.initialize_app(cred)
    else:
        # Default credentials (e.g. GCP) — local dev should use service account file
        firebase_admin.initialize_app()


def get_db():
    return firestore.client()
