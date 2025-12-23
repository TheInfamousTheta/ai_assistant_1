# 🎙️ AI Voice Assistant

A full-stack **AI Voice Assistant** application that delivers a seamless, real-time conversational experience using state-of-the-art speech and AI technologies. The system combines fast speech recognition, ultra-low-latency LLM inference, lifelike voice synthesis, and real-time audio streaming.

---

## 🚀 Features

- **Android App**
  - Currently built and optimized for Android devices.

- **Multi-Platform Roadmap**
  - Planned support for **iOS, Windows, macOS, and Linux**.

- **Real-time Speech-to-Text (STT)**
  - Powered by Deepgram for fast and accurate transcription.

- **Intelligent AI Core (LLM)**
  - Uses Groq running Llama 3 for near-instant responses.

- **Lifelike Text-to-Speech (TTS)**
  - High-quality, natural voice synthesis using Murf.ai.

- **Real-time Infrastructure**
  - Built on LiveKit for low-latency audio rooms and agent orchestration.

- **Audio Visualization**
  - Real-time visual feedback during voice interaction.

- **User Authentication**
  - Secure login using Firebase Auth.

---

## 📸 Screenshots

| Login Screen | Room Connection | Voice Customization |
|-------------|----------------|---------------------|
| Secure Firebase Login | Dynamic Room Allocation per User | Voice Change Abilities |

<div style="display: flex; justify-content: space-around;">
  <div><img src="screenshots\login_screenshot.png" alt="Image 1" style="width: 60%; height: auto;"></div>
  <div><img src="screenshots\room_connect_screenshot.png" alt="Image 2" style="width: 60%; height: auto;"></div>
  <div><img src="screenshots\voice_change_screenshot.png" alt="Image 3" style="width: 60%; height: auto;"></div>
</div>

---

## 🔄 System Architecture

```mermaid
graph TD
User((User))
App[Flutter Mobile App]
LK[LiveKit Room]

subgraph "Python Backend (Agent)"
  Worker[Agent Worker]
  STT[Deepgram STT]
  LLM[Groq (Llama 3)]
  TTS[Murf.ai TTS]
end

User -->|Speaks| App
App <-->|WebRTC Audio/Data| LK
LK <-->|Audio Stream| Worker
Worker -->|Raw Audio| STT
STT -->|Transcript| LLM
LLM -->|Text Response| TTS
TTS -->|Generated Audio| Worker
```

---

## 🏗 Tech Stack

### Frontend
- Flutter (Dart)
- Controller-based state management
- Firebase Auth
- Custom audio visualization painters

### Backend & AI
- Flask (Python)
- LiveKit (Agents & Rooms)
- Deepgram (STT)
- Groq (Llama 3)
- Murf.ai (TTS)
- Firebase Admin SDK

---

## 📂 Project Structure

```
├── backend/
│   ├── api_server.py
│   ├── murf_tts.py
│   ├── firebase_config.py
│   └── requirements.txt
│
└── frontend/
    ├── lib/
    │   ├── screens/
    │   ├── controllers/
    │   ├── widgets/
    │   └── main.dart
    └── pubspec.yaml
```

---

## 🛠 Installation & Setup

### Prerequisites
- Flutter SDK
- Python 3.x
- Firebase Project
- API keys for Deepgram, Groq, Murf.ai, and LiveKit

---

## 1️⃣ Backend Setup

```bash
cd backend
python -m venv venv
```

Activate virtual environment:

**Windows**
```bash
venv\Scripts\activate
```

**macOS / Linux**
```bash
source venv/bin/activate
```

Install dependencies:
```bash
pip install -r requirements.txt
```

Create a `.env` file:
```env
DEEPGRAM_API_KEY=your_deepgram_key
GROQ_API_KEY=your_groq_key
MURF_API_KEY=your_murf_key
LIVEKIT_API_KEY=your_livekit_key
LIVEKIT_API_SECRET=your_livekit_secret
LIVEKIT_URL=your_livekit_url
```

Run backend:
```bash
python api_server.py
```

---

## 2️⃣ Frontend Setup

```bash
cd frontend
flutter pub get
```

### Firebase Configuration

- **Android:** `frontend/android/app/google-services.json`
- **iOS:** `frontend/ios/Runner/GoogleService-Info.plist`

Run app:
```bash
flutter run
```

---

## 📱 Usage

1. Start backend server.
2. Launch the Flutter app.
3. Login via Firebase.
4. Connect to Voice Agent screen.
5. Speak and interact in real time.

---

## 🤝 Contributing

Contributions are welcome!

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Open a pull request

---

⭐ If you like this project, consider starring the repository!

