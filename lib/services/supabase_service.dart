import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  SupabaseService._();

  static const String supabaseUrl = 'https://wlnzjfhlsqxnwnyildys.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndsbnpqZmhsc3F4bndueWlsZHlzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM3Mjk4NzMsImV4cCI6MjA3OTMwNTg3M30.zX5JeMAFyhh0WFM07Gi_ClWiYP8ya9-Gq6ZPLM_Pj1c';

  static bool _initialized = false;
  static final AppLinks _appLinks = AppLinks();

  static Future<void> initialize() async {
    if (_initialized) return;
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
    if (!kIsWeb) {
      _appLinks.uriLinkStream.listen(_consumeAuthLink);
    }
    _initialized = true;
  }

  static Uri? pendingAuthUri;

  /// Call after [AuthController] registers its auth listener (cold-start reset/confirm links).
  static Future<void> processPendingAuthLinks() async {
    if (kIsWeb) {
      final uri = Uri.base;
      if (_isAuthDeepLink(uri)) {
        await _consumeAuthLink(uri);
      }
      return;
    }
    await _consumeInitialAuthLink();
  }

  static bool _isAuthDeepLink(Uri uri) {
    final str = uri.toString();
    return uri.scheme == 'cwc' ||
        str.contains('reset-password') ||
        str.contains('confirm-email') ||
        str.contains('type=recovery') ||
        str.contains('type=signup') ||
        str.contains('type=email') ||
        str.contains('type=invite') ||
        str.contains('token') ||
        str.contains('code=') ||
        str.contains('access_token');
  }

  static Future<void> _consumeAuthLink(Uri? uri) async {
    if (uri == null || !_isAuthDeepLink(uri)) return;
    pendingAuthUri = uri;
    try {
      final qp = uri.queryParameters;
      if (qp.containsKey('token_hash') && qp.containsKey('type')) {
        final tokenHash = qp['token_hash']!;
        final typeStr = qp['type']!;
        final type = typeStr == 'recovery'
            ? OtpType.recovery
            : typeStr == 'signup'
                ? OtpType.signup
                : OtpType.email;
        await Supabase.instance.client.auth.verifyOTP(
          tokenHash: tokenHash,
          type: type,
        );
      } else if (qp.containsKey('code')) {
        await Supabase.instance.client.auth.exchangeCodeForSession(qp['code']!);
      } else {
        await Supabase.instance.client.auth.getSessionFromUrl(uri);
      }
    } catch (_) {}
  }

  static Future<void> _consumeInitialAuthLink() async {
    try {
      await _consumeAuthLink(await _appLinks.getInitialLink());
    } catch (_) {}
  }

  static SupabaseClient get client => Supabase.instance.client;
}
