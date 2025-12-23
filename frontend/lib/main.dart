import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // Ensure this file exists via `flutterfire configure`
import 'package:ai_assistant/screens/login_screen.dart';
import 'package:ai_assistant/utils/constants.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint("✅ Firebase Initialized");
  } catch (e) {
    debugPrint("❌ Firebase Init Failed: $e");
  }

  // 2. Load Env (Optional, for other configs)
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Info: .env file not found.");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Neo Nomad Agent',
      debugShowCheckedModeBanner: false,

      // Global Theme Configuration
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AgentConstants.scaffoldBackground,
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
        colorScheme: const ColorScheme.dark(
          primary: AgentConstants.primaryColor,
          secondary: AgentConstants.secondaryColor,
        ),
      ),

      // Define Routes
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
      },
    );
  }
}