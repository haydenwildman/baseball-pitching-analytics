import 'package:supabase_flutter/supabase_flutter.dart';
// Re-exported so any file that imports this one also gets SupabaseClient,
// AuthException, FunctionException, etc. without a second import line.
export 'package:supabase_flutter/supabase_flutter.dart';

/// ══════════════════════════════════════════════════════════════
/// SUPABASE CONFIG
///
/// The anon/public key below is SAFE to ship in the app — it has no
/// power on its own; every table it touches is locked down by Row
/// Level Security policies (see supabase_schema.sql). Never put the
/// service_role/secret key here or anywhere else in this app — that
/// key bypasses RLS entirely and must only ever live inside the
/// admin-users Edge Function, on Supabase's servers.
/// ══════════════════════════════════════════════════════════════
const supabaseUrl = 'https://xmzdwoqvnnwhbnntziuk.supabase.co';
const supabaseAnonKey =
    'sb_publishable_MLI_UHma0Z_9kT8p0MReaQ_lVQ2h_zN';

/// Call once at app startup, before runApp(). Sets up the singleton
/// accessed everywhere else via `Supabase.instance.client`.
Future<void> initSupabase() async {
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
}

/// Shorthand used throughout the services layer.
SupabaseClient get sb => Supabase.instance.client;
