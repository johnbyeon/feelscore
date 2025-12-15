import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/user_provider.dart';
import 'providers/refresh_provider.dart';
import 'providers/follow_provider.dart';
import 'screens/login_screen.dart';
import 'main_screen.dart';
import 'widgets/responsive_layout.dart';
import 'web_main_screen.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/fcm_service.dart';
import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    print('Error initializing Firebase in background handler: $e');
  }

  print("Handling a background message: ${message.messageId}");
  print("Background Msg Title: ${message.notification?.title}");
  print("Background Msg Body: ${message.notification?.body}");
  print("Background Msg Data: ${message.data}");
}

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Initialize FCM Service
    // We will set the key here or import it in FCMService?
    // Let's pass it via setter to avoid circular deps if FCMService is used elsewhere without main.
    // Or just import main.dart in FCMService is fine for the key.
    // But better: FCMService().setScaffoldMessengerKey(rootScaffoldMessengerKey);
    // await FCMService().initialize(); - we'll update this logic
  } catch (e) {
    print("Failed to initialize Firebase: $e");
    // Continue app execution even if Firebase fails
  }

  // Pre-set the key so initialize can use it if needed, or use it later
  FCMService().setNavigatorKey(navigatorKey);
  await FCMService().initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => RefreshProvider()),
        ChangeNotifierProvider(create: (_) => FollowProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      title: 'FeelScore',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD0BCFF),
          brightness: Brightness.dark,
          surface: const Color(0xFF1E1E1E),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF070707),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF070707),
          foregroundColor: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2C2C2C),
          hintStyle: const TextStyle(color: Color(0xFF9E9E9E)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFD0BCFF), width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          titleLarge: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            height: 1.5,
            color: Color(0xFFE0E0E0),
          ),
          labelLarge: TextStyle(
            color: Color(0xFFD0BCFF),
            fontWeight: FontWeight.bold,
          ),
        ),
        navigationRailTheme: const NavigationRailThemeData(
          backgroundColor: Color(0xFF070707),
          selectedIconTheme: IconThemeData(color: Color(0xFFD0BCFF)),
          unselectedIconTheme: IconThemeData(color: Color(0xFFE6E1E5)),
          selectedLabelTextStyle: TextStyle(color: Color(0xFFE6E1E5)),
          unselectedLabelTextStyle: TextStyle(color: Color(0xFFE6E1E5)),
        ),
        navigationBarTheme: NavigationBarThemeData(
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          backgroundColor: const Color(0xFF070707),
          indicatorColor: const Color(0xFF4F378B),
          iconTheme: WidgetStateProperty.all(
            const IconThemeData(color: Color(0xFFE6E1E5)),
          ),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(color: Color(0xFFE6E1E5)),
          ),
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    // Check login status when app starts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<UserProvider>(context, listen: false).checkLoginStatus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        if (userProvider.isLoggedIn) {
          return const ResponsiveLayout(
            mobileBody: MainScreen(),
            webBody: WebMainScreen(),
          );
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}
