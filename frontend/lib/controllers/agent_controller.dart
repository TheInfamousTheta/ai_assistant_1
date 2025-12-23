import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';   // ENABLED
import '../utils/constants.dart';

/// Manages the LiveKit room connection, state, and RPC calls.
class AgentController extends ChangeNotifier {
  Room? _room;
  EventsListener<RoomEvent>? _listener;

  // -- State Properties --
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _isAgentConnected = false;
  bool _isAgentSpeaking = false;
  bool _isMicMuted = false;
  String _statusText = "Ready to Connect";
  String _selectedVoiceName = AgentConstants.defaultVoice;

  // -- Auth State --
  String? _authToken; // Renamed from _googleIdToken

  // -- Getters --
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  bool get isAgentConnected => _isAgentConnected;
  bool get isAgentSpeaking => _isAgentSpeaking;
  bool get isMicMuted => _isMicMuted;
  String get statusText => _statusText;
  String get selectedVoiceName => _selectedVoiceName;
  Room? get room => _room;

  // -- Authentication Config --
  // Use 10.0.2.2:8000 for Android Emulator
  // Use localhost:8000 for iOS Simulator
  // Use your Machine IP (e.g., 192.168.1.5:8000) for Real Devices
  final String _authServerUrl = "http://10.0.2.2:8000/login";

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  /// Sets the token if passed from a previous screen
  void setAuthToken(String token) {
    _authToken = token;
  }

  /// Login with Email and Password
  Future<String?> loginWithEmail(String email, String password) async {
    _isConnecting = true;
    notifyListeners();

    try {
      final UserCredential userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final token = await userCredential.user?.getIdToken();

      if (token != null) {
        _authToken = token;
        debugPrint("✅ Login Successful: ${userCredential.user?.email}");
      }

      _isConnecting = false;
      notifyListeners();
      return token;
    } catch (e) {
      debugPrint("Login Error: $e");
      _isConnecting = false;
      notifyListeners();
      return null; // Return null on failure
    }
  }

  /// Sign Up with Email and Password
  Future<String?> signUpWithEmail(String email, String password) async {
    _isConnecting = true;
    notifyListeners();

    try {
      final UserCredential userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final token = await userCredential.user?.getIdToken();

      if (token != null) {
        _authToken = token;
        debugPrint("✅ Sign Up Successful: ${userCredential.user?.email}");
      }

      _isConnecting = false;
      notifyListeners();
      return token;
    } catch (e) {
      debugPrint("Sign Up Error: $e");
      _isConnecting = false;
      notifyListeners();
      return null;
    }
  }

  /// Main entry point: Authenticates, gets token from server, and connects.
  Future<bool> checkPermissionsAndConnect() async {
    // 1. Check Permissions
    Map<Permission, PermissionStatus> statuses = await [
      Permission.microphone,
      Permission.bluetoothConnect,
    ].request();

    if (statuses[Permission.microphone] != PermissionStatus.granted) {
      _setStatus("Microphone Permission Denied");
      return false;
    }

    // 2. Start Connection Flow
    _isConnecting = true;
    _setStatus("Authenticating...");
    notifyListeners();

    try {
      // A. Get Firebase Identity (Use cached or refresh)
      if (_authToken == null) {
        final user = _firebaseAuth.currentUser;
        if (user != null) {
          _authToken = await user.getIdToken(true); // Force refresh
        } else {
          throw "User not logged in";
        }
      }

      // B. Exchange for LiveKit Token via Backend
      _setStatus("Fetching Token...");

      // Ensure _authToken is not null before sending
      if (_authToken == null) throw "Authentication Token Missing";

      final tokenData = await _fetchLiveKitToken(_authToken!);

      final String liveKitUrl = tokenData['url'];
      final String liveKitToken = tokenData['access_token'];

      // C. Connect to Room
      return await _connectToRoom(liveKitUrl, liveKitToken);

    } catch (e) {
      debugPrint("Auth/Connection Error: $e");
      _isConnecting = false;
      _setStatus("Connection Error: ${e.toString().split(':').last.trim()}");
      notifyListeners();
      return false;
    }
  }

  /// Calls the Python Backend to get the Room Token.
  Future<Map<String, dynamic>> _fetchLiveKitToken(String idToken) async {
    try {
      final response = await http.post(
        Uri.parse(_authServerUrl),
        headers: {"Content-Type": "application/json"},
        // Note: The backend key is still "id_token" to match your Python server expectations
        body: jsonEncode({"id_token": idToken}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw "Server Error ${response.statusCode}: ${response.body}";
      }
    } catch (e) {
      debugPrint("❌ Authentication Server Failed: $e");
      rethrow;
    }
  }

  /// Establishes the connection to the LiveKit Cloud/Server.
  Future<bool> _connectToRoom(String url, String token) async {
    _setStatus("Connecting to Neo...");
    notifyListeners();

    final roomOptions = RoomOptions(
      adaptiveStream: true,
      dynacast: true,
      defaultAudioPublishOptions: const AudioPublishOptions(
        name: 'flutter_mic',
        audioBitrate: 32000,
        dtx: true,
      ),
    );

    _room = Room(roomOptions: roomOptions);

    try {
      _listener = _room!.createListener();
      _setupListeners();

      await _room!.connect(url, token);

      await _room!.localParticipant?.setMicrophoneEnabled(true,
          audioCaptureOptions: const AudioCaptureOptions(
            echoCancellation: true,
            noiseSuppression: true,
            autoGainControl: true,
          )
      );

      _isConnected = true;
      _isConnecting = false;
      _checkAgentPresence();
      _setStatus("Connected");
      notifyListeners();

      return true;
    } catch (e) {
      debugPrint('Failed to connect: $e');
      _isConnected = false;
      _isConnecting = false;
      _setStatus("Connection Failed");
      notifyListeners();
      return false;
    }
  }

  void _setupListeners() {
    if (_listener == null) return;

    _listener!.on<ActiveSpeakersChangedEvent>((event) {
      bool agentSpeaking = event.speakers.any(
              (p) => p.identity != _room?.localParticipant?.identity
      );
      _isAgentSpeaking = agentSpeaking;
      notifyListeners();
    });

    _listener!.on<ParticipantConnectedEvent>((event) {
      _checkAgentPresence();
    });

    _listener!.on<ParticipantDisconnectedEvent>((event) {
      _checkAgentPresence();
      _isAgentSpeaking = false;
      notifyListeners();
    });
  }

  void _checkAgentPresence() {
    bool hasAgent = _room?.remoteParticipants.isNotEmpty ?? false;
    if (_isAgentConnected != hasAgent) {
      _isAgentConnected = hasAgent;
      notifyListeners();
    }
  }

  Future<void> toggleMute() async {
    if (_room?.localParticipant == null) return;

    _isMicMuted = !_isMicMuted;
    notifyListeners();

    try {
      await _room!.localParticipant!.setMicrophoneEnabled(!_isMicMuted);
    } catch (e) {
      _isMicMuted = !_isMicMuted;
      notifyListeners();
      debugPrint("Error toggling mute: $e");
    }
  }

  Future<void> changeVoice(String voiceName) async {
    final voiceId = AgentConstants.voices[voiceName];
    if (voiceId == null || _room == null) return;

    final remoteParticipants = _room!.remoteParticipants.values;
    if (remoteParticipants.isEmpty) return;

    final agentIdentity = remoteParticipants.first.identity;

    try {
      _selectedVoiceName = voiceName;
      notifyListeners();

      await _room!.localParticipant!.performRpc(
        PerformRpcParams(
          destinationIdentity: agentIdentity,
          method: "change_voice",
          payload: voiceId,
          responseTimeoutMs: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      debugPrint("RPC Error: $e");
      rethrow;
    }
  }

  Future<void> disconnect() async {
    await _room?.disconnect();
    _isConnected = false;
    _isAgentConnected = false;
    _statusText = "Disconnected";
    notifyListeners();
  }

  void _setStatus(String text) {
    _statusText = text;
    notifyListeners();
  }

  @override
  void dispose() {
    _listener?.dispose();
    _room?.disconnect();
    super.dispose();
  }
}