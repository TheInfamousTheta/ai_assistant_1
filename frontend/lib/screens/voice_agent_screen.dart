import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../controllers/agent_controller.dart';
import '../utils/constants.dart';
import '../widgets/agent_visualizer.dart';

class VoiceAgentScreen extends StatefulWidget {
  final String? preAuthToken; // Accept token from LoginScreen

  const VoiceAgentScreen({super.key, this.preAuthToken});

  @override
  State<VoiceAgentScreen> createState() => _VoiceAgentScreenState();
}

class _VoiceAgentScreenState extends State<VoiceAgentScreen> {
  // Initialize the Logic Controller
  final AgentController _controller = AgentController();

  @override
  void initState() {
    super.initState();
    // Listen to controller changes to rebuild UI when state updates
    _controller.addListener(_handleControllerUpdate);

    // Inject the token if we have one from the Login Screen
    if (widget.preAuthToken != null) {
      _controller.setAuthToken(widget.preAuthToken!);
    }
  }

  void _handleControllerUpdate() {
    // Only setState if the widget is still in the tree
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerUpdate);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleVoiceChange(String voiceName) async {
    try {
      await _controller.changeVoice(voiceName);
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to change voice: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine status text based on priority:
    String displayStatus;
    if (!_controller.isConnected) {
      displayStatus = _controller.statusText;
    } else if (!_controller.isAgentConnected) {
      displayStatus = "Waiting for Agent...";
    } else if (_controller.isMicMuted) {
      displayStatus = "Microphone Off";
    } else if (_controller.isAgentSpeaking) {
      displayStatus = "Neo is speaking...";
    } else {
      displayStatus = "Listening...";
    }

    return Scaffold(
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),

            // --- ANIMATED VISUALIZER ---
            AgentVisualizer(
              isConnected: _controller.isConnected,
              isConnecting: _controller.isConnecting,
              isAgentConnected: _controller.isAgentConnected,
              // Passed here
              isAgentSpeaking: _controller.isAgentSpeaking,
              isMicMuted: _controller.isMicMuted,
              onTap: _controller.isConnected ? _controller.toggleMute : null,
            ),

            const SizedBox(height: 60),

            // --- STATUS TEXT ---
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                displayStatus,
                key: ValueKey(displayStatus),
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  color: _controller.isConnecting
                      ? AgentConstants.secondaryColor
                      : (!_controller.isConnected
                            ? Colors.white70
                            : (_controller.isMicMuted
                                  ? Colors.redAccent
                                  : Colors.white70)),
                  fontWeight: FontWeight.w300,
                  letterSpacing: 1.2,
                ),
              ),
            ),

            const Spacer(),

            // --- BOTTOM CONTROLS ---
            Padding(
              padding: const EdgeInsets.only(bottom: 50),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Mute Button (Hidden if not connected)
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: _controller.isConnected ? 1.0 : 0.0,
                    child: FloatingActionButton(
                      heroTag: "mute",
                      backgroundColor: _controller.isMicMuted
                          ? Colors.redAccent
                          : Colors.white12,
                      elevation: 0,
                      onPressed: _controller.isConnected
                          ? _controller.toggleMute
                          : null,
                      child: Icon(
                        _controller.isMicMuted ? Icons.mic_off : Icons.mic,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  const SizedBox(width: 30),

                  // Connect / Disconnect Button (Morphing Animation)
                  _buildConnectionButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        "NEO NOMAD",
        style: GoogleFonts.oswald(
          letterSpacing: 3,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.logout, color: Colors.white54),
        onPressed: () {
          // Allow logging out to go back to Login Screen
          Navigator.of(context).pushReplacementNamed('/');
        },
      ),
      actions: [
        if (_controller.isConnected && _controller.isAgentConnected)
          PopupMenuButton<String>(
            icon: const Icon(Icons.record_voice_over, color: Colors.white70),
            color: AgentConstants.cardBackground,
            onSelected: _handleVoiceChange,
            itemBuilder: (context) {
              return AgentConstants.voices.keys.map((String key) {
                return PopupMenuItem<String>(
                  value: key,
                  child: Text(
                    key,
                    style: TextStyle(
                      color: key == _controller.selectedVoiceName
                          ? AgentConstants.primaryColor
                          : Colors.white,
                    ),
                  ),
                );
              }).toList();
            },
          ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildConnectionButton() {
    final bool active = _controller.isConnected || _controller.isConnecting;

    return Animate(
      target: !active ? 1 : 0, // Animate when disconnected (Invite pulse)
      effects: [
        ShimmerEffect(
          delay: 2000.ms,
          duration: 1500.ms,
          color: Colors.white24,
          curve: Curves.easeInOut,
        ),
      ],
      onPlay: (c) => c.repeat(period: 3000.ms),
      child: FloatingActionButton(
        heroTag: "hangup",
        backgroundColor: active ? Colors.red[900] : Colors.greenAccent[700],
        onPressed: active
            ? _controller.disconnect
            : _controller.checkPermissionsAndConnect,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, anim) => RotationTransition(
            turns: child.key == const ValueKey('connect')
                ? Tween(begin: 0.75, end: 1.0).animate(anim)
                : Tween(begin: 1.0, end: 1.0).animate(anim),
            child: ScaleTransition(scale: anim, child: child),
          ),
          child: Icon(
            active ? Icons.call_end : Icons.call,
            key: ValueKey(active ? 'end' : 'connect'),
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }
}
