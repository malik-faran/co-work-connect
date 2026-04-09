import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  SupabaseService._();

  static const String supabaseUrl = 'https://wlnzjfhlsqxnwnyildys.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndsbnpqZmhsc3F4bndueWlsZHlzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM3Mjk4NzMsImV4cCI6MjA3OTMwNTg3M30.zX5JeMAFyhh0WFM07Gi_ClWiYP8ya9-Gq6ZPLM_Pj1c';

  static Future<void> initialize() async {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }

  static SupabaseClient get client => Supabase.instance.client;
}
