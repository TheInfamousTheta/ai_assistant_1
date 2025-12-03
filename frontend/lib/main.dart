import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  // Ensure .env is loaded before app start
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Neo Nomad Agent',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF111111),
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
      ),
      home: const VoiceAgentScreen(),
    );
  }
}

class VoiceAgentScreen extends StatefulWidget {
  const VoiceAgentScreen({super.key});

  @override
  State<VoiceAgentScreen> createState() => _VoiceAgentScreenState();
}

class _VoiceAgentScreenState extends State<VoiceAgentScreen> {
  // Load credentials from .env
  final String _liveKitUrl = dotenv.env['LIVEKIT_URL'] ?? "";
  final String _token = dotenv.env['LIVEKIT_TOKEN'] ?? "";

  Room? _room;
  EventsListener<RoomEvent>? _listener;
  bool _isConnected = false;
  bool _isAgentSpeaking = false;
  bool _isMicMuted = false;

  final Map<String, String> _voices = {
    "Zion (Male, Bilingual)": "en-US-zion",
    "Ken (Male, Deep)": "en-US-ken",
    "Aara (Female, Hindi)": "hi-IN-aara",
    "Falcon Default": "en-US-falcon",
  };
  String _selectedVoiceName = "Zion (Male, Bilingual)";

  @override
  void initState() {
    super.initState();
    _checkCredentialsAndConnect();
  }

  Future<void> _checkCredentialsAndConnect() async {
    if (_liveKitUrl.isEmpty || _token.isEmpty) {
      debugPrint("ERROR: Missing LIVEKIT_URL or LIVEKIT_TOKEN in .env file");
      return;
    }
    // Request audio permission (Android 12+ might need BLUETOOTH_CONNECT too)
    await [
      Permission.microphone,
      Permission.bluetoothConnect,
    ].request();

    _connectToRoom();
  }

  Future<void> _connectToRoom() async {
    final roomOptions = RoomOptions(
      adaptiveStream: true,
      dynacast: true,
      defaultAudioPublishOptions: const AudioPublishOptions(
        name: 'flutter_mic',
        audioBitrate: 32000,
      ),
    );

    final room = Room();
    try {
      await room.connect(_liveKitUrl, _token, roomOptions: roomOptions);
      await room.localParticipant?.setMicrophoneEnabled(true);

      final listener = room.createListener();
      listener.on<ActiveSpeakersChangedEvent>((event) {
        // Detect if someone other than me is speaking
        bool agentSpeaking = event.speakers.any((p) => p != room.localParticipant);
        if (mounted) setState(() => _isAgentSpeaking = agentSpeaking);
      });

      // Listen for Participant Connection (to find the agent immediately)
      listener.on<ParticipantConnectedEvent>((event) {
        print("Agent Joined: ${event.participant.identity}");
      });

      if (mounted) {
        setState(() {
          _room = room;
          _listener = listener;
          _isConnected = true;
        });
      }
      print('Connected to ${room.name}');

    } catch (e) {
      print('Failed to connect: $e');
    }
  }

  void _toggleMute() async {
    if (_room?.localParticipant == null) return;
    bool newMuteState = !_isMicMuted;
    setState(() => _isMicMuted = newMuteState);
    await _room!.localParticipant!.setMicrophoneEnabled(!newMuteState);
  }

  Future<void> _changeVoice(String voiceName) async {
    final voiceId = _voices[voiceName];
    if (voiceId == null || _room == null) return;

    // FIX: Dynamically find the Agent's identity
    // Since this is a 1-on-1 room, any remote participant is the Agent.
    final remoteParticipants = _room!.remoteParticipants.values;

    if (remoteParticipants.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Waiting for Agent to join... try again in a moment.")),
        );
      }
      return;
    }

    // Get the first remote participant (The Agent)
    final agentIdentity = remoteParticipants.first.identity;

    try {
      setState(() => _selectedVoiceName = voiceName);

      // Send RPC command to the Agent
      await _room!.localParticipant!.performRpc(
          PerformRpcParams(
            destinationIdentity: agentIdentity,
            method: "change_voice",
            payload: voiceId,
          )
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Voice switched to $voiceName"),
            backgroundColor: Colors.grey[800],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print("RPC Error: $e");
    }
  }

  @override
  void dispose() {
    _listener?.dispose();
    _room?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Visual State Logic
    Color visualizerColor;
    IconData centerIcon;

    if (!_isConnected) {
      visualizerColor = Colors.amber; // Connecting state
      centerIcon = Icons.sync;
    } else if (_isAgentSpeaking) {
      visualizerColor = Colors.cyanAccent; // Agent active
      centerIcon = Icons.graphic_eq;
    } else if (_isMicMuted) {
      visualizerColor = Colors.grey; // Muted
      centerIcon = Icons.mic_off;
    } else {
      visualizerColor = Colors.greenAccent; // Listening
      centerIcon = Icons.mic;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("Neo Nomad", style: GoogleFonts.oswald(letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Voice Selector
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              dropdownColor: const Color(0xFF222222),
              value: _selectedVoiceName,
              icon: Icon(Icons.record_voice_over, color: _isConnected ? Colors.white70 : Colors.white24),
              items: _voices.keys.map((String key) {
                return DropdownMenuItem<String>(
                  value: key,
                  child: Text(key, style: const TextStyle(color: Colors.white)),
                );
              }).toList(),
              onChanged: _isConnected ? (String? newValue) {
                if (newValue != null) _changeVoice(newValue);
              } : null,
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),

          // --- ANIMATED VISUALIZER ---
          Center(
            child: GestureDetector(
              onTap: _isConnected ? _toggleMute : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: visualizerColor.withOpacity(0.1),
                  border: Border.all(
                      color: visualizerColor.withOpacity(0.5),
                      width: 2
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: visualizerColor.withOpacity(_isConnected ? 0.3 : 0.1),
                        blurRadius: _isConnected ? 50 : 20,
                        spreadRadius: _isConnected ? 5 : 0
                    )
                  ],
                ),
                child: Icon(
                  centerIcon,
                  size: 80,
                  color: visualizerColor,
                )
                    .animate(
                  target: !_isConnected ? 1 : 0, // Spin while connecting
                  onPlay: (c) => c.repeat(),
                )
                    .rotate(duration: 2000.ms)
                    .animate(
                    target: (_isConnected && _isAgentSpeaking) ? 1 : 0 // Pulse while agent speaks
                )
                    .scale(
                    begin: const Offset(1,1),
                    end: const Offset(1.2, 1.2),
                    duration: 400.ms,
                    curve: Curves.easeInOut
                )
                    .then()
                    .scale(begin: const Offset(1.2, 1.2), end: const Offset(1, 1)),
              )
                  .animate(
                  target: !_isConnected ? 1 : 0, // Breathe while connecting
                  onPlay: (c) => c.repeat(reverse: true)
              )
                  .scale(
                  begin: const Offset(1, 1),
                  end: const Offset(1.05, 1.05),
                  duration: 1000.ms
              ),
            ),
          ),

          const SizedBox(height: 40),

          // Status Text
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              !_isConnected
                  ? "Connecting to Neo..."
                  : (_isMicMuted
                  ? "Microphone Off"
                  : (_isAgentSpeaking ? "Neo is speaking..." : "Listening...")),
              key: ValueKey(_isConnected.toString() + _isMicMuted.toString() + _isAgentSpeaking.toString()),
              style: GoogleFonts.outfit(
                  fontSize: 20,
                  color: !_isConnected ? Colors.amber : (_isMicMuted ? Colors.grey : Colors.white70),
                  fontWeight: FontWeight.w300
              ),
            ),
          ),

          const Spacer(),

          // Controls
          Padding(
            padding: const EdgeInsets.only(bottom: 50),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FloatingActionButton(
                  heroTag: "mute",
                  backgroundColor: !_isConnected
                      ? Colors.white10
                      : (_isMicMuted ? Colors.redAccent : Colors.white12),
                  elevation: 0,
                  onPressed: _isConnected ? _toggleMute : null,
                  child: Icon(_isMicMuted ? Icons.mic_off : Icons.mic, color: Colors.white),
                ),
                const SizedBox(width: 30),
                FloatingActionButton(
                  heroTag: "hangup",
                  backgroundColor: Colors.red,
                  onPressed: () {
                    _room?.disconnect();
                    // exit(0); // Optional: Close app
                  },
                  child: const Icon(Icons.call_end, color: Colors.white),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}