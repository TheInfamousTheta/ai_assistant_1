import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../controllers/agent_controller.dart';
import '../utils/constants.dart';
import 'voice_agent_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AgentController _authController = AgentController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;

  Future<void> _handleAuth({required bool isLogin}) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter email and password"), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _isLoading = true);

    String? token;
    if (isLogin) {
      token = await _authController.loginWithEmail(email, password);
    } else {
      token = await _authController.signUpWithEmail(email, password);
    }

    if (mounted) {
      setState(() => _isLoading = false);

      if (token != null) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                VoiceAgentScreen(preAuthToken: token),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              const begin = Offset(0.0, 1.0);
              const end = Offset.zero;
              const curve = Curves.ease;
              var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
              return SlideTransition(position: animation.drive(tween), child: child);
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isLogin ? "Login Failed. Check credentials." : "Sign Up Failed."),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AgentConstants.scaffoldBackground,
      body: Stack(
        children: [
          // Background ambient gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.5,
                  colors: [
                    AgentConstants.primaryColor.withValues(alpha: 0.1),
                    AgentConstants.scaffoldBackground,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: SingleChildScrollView(
                child: SizedBox(
                  height: MediaQuery.of(context).size.height - 50, // rough constrain
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(),

                      // Logo / Title
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [AgentConstants.primaryColor, AgentConstants.secondaryColor],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(bounds),
                        child: Text(
                          "NEO NOMAD",
                          style: GoogleFonts.oswald(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4,
                            color: Colors.white,
                          ),
                        ),
                      ).animate().fadeIn(duration: 800.ms).moveY(begin: 20, end: 0),

                      const SizedBox(height: 12),

                      Text(
                        "Your Intelligent Travel Companion",
                        style: GoogleFonts.outfit(
                          color: Colors.white70,
                          fontSize: 16,
                          letterSpacing: 1.2,
                        ),
                      ).animate().fadeIn(delay: 300.ms, duration: 800.ms),

                      const Spacer(),

                      // Email Field
                      _buildTextField(
                        controller: _emailController,
                        hint: "Email Address",
                        icon: Icons.email_outlined,
                      ).animate().fadeIn(delay: 400.ms).moveY(begin: 20, end: 0),

                      const SizedBox(height: 16),

                      // Password Field
                      _buildTextField(
                        controller: _passwordController,
                        hint: "Password",
                        icon: Icons.lock_outline,
                        obscure: true,
                      ).animate().fadeIn(delay: 500.ms).moveY(begin: 20, end: 0),

                      const SizedBox(height: 32),

                      // Login / Sign Up Buttons
                      if (_isLoading)
                        const CircularProgressIndicator(color: AgentConstants.primaryColor)
                      else
                        Column(
                          children: [
                            _buildButton(
                                label: "LOGIN",
                                color: Colors.white,
                                textColor: Colors.black,
                                onTap: () => _handleAuth(isLogin: true)
                            ),
                            const SizedBox(height: 16),
                            _buildButton(
                                label: "SIGN UP",
                                color: Colors.white12,
                                textColor: Colors.white,
                                onTap: () => _handleAuth(isLogin: false)
                            ),
                          ],
                        ).animate().fadeIn(delay: 600.ms).moveY(begin: 30, end: 0),

                      const SizedBox(height: 40),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AgentConstants.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIcon: Icon(icon, color: Colors.white54),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildButton({
    required String label,
    required Color color,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.outfit(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}