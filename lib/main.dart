import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cwc/services/supabase_service.dart';
import 'package:cwc/services/payment_service.dart';
import 'package:cwc/services/local_notification_service.dart';
import 'package:cwc/services/fcm_service.dart';
import 'package:cwc/controllers/auth_controller.dart';
import 'package:cwc/controllers/workspace_controller.dart';
import 'package:cwc/services/navigation_service.dart';
import 'package:cwc/utils/themes/theme.dart';
import 'package:cwc/views/screens/splash_screen.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Use bundled Poppins files from assets/fonts/ (works offline on web + mobile).
  GoogleFonts.config.allowRuntimeFetching = false;

  await SupabaseService.initialize();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initPlatformServices());
  }

  Future<void> _initPlatformServices() async {
    if (kIsWeb) return;

    // Paint splash/home first; heavy native plugins after a short delay.
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    try {
      await LocalNotificationService.instance.initialize();
      await LocalNotificationService.instance.ensurePlatformReady();
    } catch (e) {
      debugPrint('Local notifications init failed: $e');
    }

    // FCM spins up a second Flutter engine — defer to avoid activity restart/black screen.
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    try {
      await FcmService.instance.initialize();
    } catch (e) {
      debugPrint('FCM init failed: $e');
    }

    try {
      Stripe.publishableKey = PaymentService.stripePublishableKey;
      await Stripe.instance.applySettings();
    } catch (e) {
      debugPrint('Stripe init failed (card payments may be unavailable): $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController()..initialize()),
        ChangeNotifierProvider(create: (_) => WorkspaceController()),
      ],
      child: MaterialApp(
        navigatorKey: NavigationService.navigatorKey,
        title: 'CWL - Coworking Spaces',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.light,
        theme: CAppTheme.lightTheme,
        darkTheme: CAppTheme.darkTheme,
        home: const SplashScreen(),
      ),
    );
  }
}
