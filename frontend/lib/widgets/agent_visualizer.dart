import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../utils/constants.dart';

/// A pure UI component that renders the animated agent interface.
/// Reacts to connection state, speaking state, and mute state.
class AgentVisualizer extends StatelessWidget {
  final bool isConnected;
  final bool isConnecting;
  final bool isAgentConnected; // New parameter
  final bool isAgentSpeaking;
  final bool isMicMuted;
  final VoidCallback? onTap;

  const AgentVisualizer({
    super.key,
    required this.isConnected,
    required this.isConnecting,
    required this.isAgentConnected, // Add to constructor
    required this.isAgentSpeaking,
    required this.isMicMuted,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Determine the color theme based on current state
    final Color visualizerColor = _getVisualizerColor();
    final IconData centerIcon = _getCenterIcon();

    // Check for specific "Waiting" state
    final bool isWaitingForAgent = isConnected && !isAgentConnected;

    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Layer 1: Radar Ripple (Connecting)
            if (isConnecting)
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AgentConstants.secondaryColor.withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
              )
                  .animate(onPlay: (c) => c.repeat())
                  .scale(
                  begin: const Offset(1, 1),
                  end: const Offset(3, 3),
                  duration: 2.seconds
              )
                  .fadeOut(duration: 2.seconds),

            // Layer 1.5: Searching Pulse (Waiting for Agent)
            if (isWaitingForAgent)
              Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.orangeAccent.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
              )
                  .animate(onPlay: (c) => c.repeat())
                  .scale(
                begin: const Offset(0.9, 0.9),
                end: const Offset(1.3, 1.3),
                duration: 3.seconds,
                curve: Curves.easeInOut,
              )
                  .fadeOut(duration: 3.seconds),

            // Layer 2: Ambient Glow (Always breathing)
            Animate(
              onPlay: (c) => c.repeat(reverse: true),
              effects: [
                ScaleEffect(
                    begin: const Offset(1, 1),
                    end: const Offset(1.1, 1.1),
                    duration: 2000.ms
                ),
                FadeEffect(begin: 0.5, end: 0.8, duration: 2000.ms),
              ],
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: visualizerColor.withValues(alpha: 0.05),
                  boxShadow: [
                    BoxShadow(
                      color: visualizerColor.withValues(alpha: 0.2),
                      blurRadius: 40,
                      spreadRadius: 1,
                    )
                  ],
                ),
              ),
            ),

            // Layer 3: Main Core Circle
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: visualizerColor.withValues(alpha: 0.1),
                border: Border.all(
                  color: visualizerColor.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              child: Icon(
                centerIcon,
                size: 80,
                color: visualizerColor,
              )
                  .animate(target: isAgentSpeaking ? 1 : 0)
                  .shake(hz: 4, offset: const Offset(2, 0)) // Shake when speaking
                  .animate(target: isConnecting ? 1 : 0, onPlay: (c) => c.repeat())
                  .rotate(duration: 2.seconds) // Rotate when connecting
                  .shimmer(duration: 1.seconds, color: Colors.white54)
                  .animate(target: isWaitingForAgent ? 1 : 0, onPlay: (c) => c.repeat(reverse: true))
                  .fade(begin: 0.5, end: 1.0, duration: 1.seconds), // Breathe when waiting
            ),
          ],
        ),
      ),
    );
  }

  Color _getVisualizerColor() {
    if (isConnecting) return AgentConstants.secondaryColor;
    if (!isConnected) return Colors.grey;
    if (!isAgentConnected) return Colors.orangeAccent; // Waiting Color
    if (isAgentSpeaking) return AgentConstants.primaryColor;
    if (isMicMuted) return Colors.redAccent.withValues(alpha: 0.5);
    return Colors.greenAccent;
  }

  IconData _getCenterIcon() {
    if (isConnecting) return Icons.sync;
    if (!isConnected) return Icons.mic_none;
    if (!isAgentConnected) return Icons.person_search; // Waiting Icon
    if (isAgentSpeaking) return Icons.graphic_eq;
    if (isMicMuted) return Icons.mic_off;
    return Icons.mic;
  }
}