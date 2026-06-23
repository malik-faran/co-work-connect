import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:cwc/services/supabase_service.dart';
import 'package:cwc/services/payment_service.dart';
import 'package:cwc/services/local_notification_service.dart';
import 'package:cwc/services/fcm_service.dart';
import 'package:cwc/controllers/auth_controller.dart';
import 'package:cwc/controllers/workspace_controller.dart';
import 'package:cwc/utils/themes/theme.dart';
import 'package:cwc/views/screens/splash_screen.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();

  if (!kIsWeb) {
    await LocalNotificationService.instance.initialize();
    await FcmService.instance.initialize();
    Stripe.publishableKey = PaymentService.stripePublishableKey;
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController()..initialize()),
        ChangeNotifierProvider(create: (_) => WorkspaceController()),
      ],
      child: MaterialApp(
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
