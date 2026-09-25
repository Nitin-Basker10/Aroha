import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase backend hookup for AROHA (offline-first).
///
/// The app keeps working fully on its in-memory mock store when the
/// backend is unreachable — Supabase is additive (auth verification,
/// future table sync, Edge Function calls), never a boot dependency.
///
/// SECURITY: only the publishable key ships in the client. The SECRET
/// key must live server-side only (Edge Functions / your API) and must
/// never be committed. Override via --dart-define for other environments:
///   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
class SupabaseService {
  SupabaseService._();

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://qznvgjsenqtdxoidnuht.supabase.co',
  );
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_m6YvxFWHJF2DpVJ5M38RNQ_JWlULpGd',
  );

  static bool _ready = false;
  static bool get isReady => _ready;

  /// Null when init hasn't run or failed (offline) — callers must handle it.
  static SupabaseClient? get clientOrNull =>
      _ready ? Supabase.instance.client : null;

  /// Initialise once at startup. Never throws; returns false when the
  /// backend can't be reached so the app boots into offline mode.
  static Future<bool> init() async {
    try {
      await Supabase.initialize(url: url, publishableKey: anonKey);
      _ready = true;
    } catch (e) {
      debugPrint('Supabase offline mode: $e');
      _ready = false;
    }
    return _ready;
  }
}
