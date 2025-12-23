import os
import firebase_admin
from firebase_admin import credentials, firestore

def init_firebase():
    """Initializes Firebase Admin SDK if not already initialized."""
    try:
        # Check if already initialized to avoid "App already exists" error
        firebase_admin.get_app()
    except ValueError:
        # We rely on GOOGLE_APPLICATION_CREDENTIALS env var being set
        # OR you can pass the path directly: credentials.Certificate("service-account.json")
        cred = credentials.ApplicationDefault()
        firebase_admin.initialize_app(cred)

def get_firestore_db():
    init_firebase()
    return firestore.client()