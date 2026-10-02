import '../models/user.dart';
import 'supabase_config.dart';

/// Result wrapper — mirrors the R `check_creds()` return shape
/// (list(result=TRUE/FALSE, message=..., user_info=...)).
class AuthResult {
  final bool success;
  final String? message;
  final AppUser? user;
  AuthResult({required this.success, this.message, this.user});
}

/// ══════════════════════════════════════════════════════════════
/// AUTH SERVICE
///
/// Backed by Supabase Auth + a `public.profiles` table (see
/// supabase_schema.sql), instead of the old local SHA-256 scheme.
/// Login is by EMAIL now (Supabase Auth's native identifier) — the
/// app-level "username" is a separate display field stored on the
/// profile row, unchanged elsewhere in the app.
///
/// Admin operations that need to create a user or set/reset a
/// password go through the `admin-users` Edge Function instead of
/// happening here directly — those require the service-role key,
/// which must never be embedded in this (public, static-hosted) app.
/// See admin-users_index.ts.
/// ══════════════════════════════════════════════════════════════
class AuthService {
  /// Builds an [AppUser] from the current Supabase session + a fetched
  /// `profiles` row. Throws if there's no logged-in session.
  Future<AppUser> _currentAppUser() async {
    final authUser = sb.auth.currentUser!;
    final profile =
        await sb.from('profiles').select().eq('id', authUser.id).single();
    return AppUser.fromSupabase(
      id: authUser.id,
      email: authUser.email ?? '',
      profile: profile,
    );
  }

  /// Call once at startup: if a Supabase session was persisted from a
  /// previous visit (same browser/device), rebuilds the [AppUser] from
  /// it so the person doesn't have to log in again. Returns null if
  /// there's no existing session.
  Future<AppUser?> restoreSession() async {
    if (sb.auth.currentSession == null) return null;
    try {
      return await _currentAppUser();
    } catch (_) {
      return null; // stale/invalid session — fall back to the login screen
    }
  }

  Future<AuthResult> login(String email, String password) async {
    try {
      final res = await sb.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      if (res.user == null) {
        return AuthResult(success: false, message: 'Invalid email or password.');
      }
      final user = await _currentAppUser();
      if (!user.isActive) {
        await sb.auth.signOut();
        return AuthResult(success: false, message: 'Account inactive. Contact support.');
      }
      return AuthResult(success: true, user: user);
    } on AuthException catch (e) {
      return AuthResult(success: false, message: e.message);
    } catch (e) {
      return AuthResult(success: false, message: 'Invalid email or password.');
    }
  }

  Future<void> logout() => sb.auth.signOut();

  /// Self-serve signup — creates a `basic` tier account directly (no
  /// admin needed). Supabase sends its own confirmation email unless
  /// "Confirm email" is turned off in Auth settings.
  Future<AuthResult> signUp({
    required String username,
    required String email,
    required String password,
    required String confirmPassword,
    UserTier tier = UserTier.basic,
  }) async {
    if (username.trim().isEmpty) {
      return AuthResult(success: false, message: 'Username is required.');
    }
    if (email.trim().isEmpty) {
      return AuthResult(success: false, message: 'Email is required.');
    }
    if (password.length < 6) {
      return AuthResult(success: false, message: 'Password must be at least 6 characters.');
    }
    if (password != confirmPassword) {
      return AuthResult(success: false, message: 'Passwords do not match.');
    }
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username.trim())) {
      return AuthResult(success: false, message: 'Username: letters, numbers, underscore only.');
    }
    try {
      final res = await sb.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'username': username.trim()}, // read by the handle_new_user trigger
      );
      if (res.user == null) {
        return AuthResult(success: false, message: 'Sign up failed.');
      }
      // The trigger creates the profiles row, but it fills pitcher_display_name
      // from username/email before we know if this call also wants a custom tier.
      if (tier != UserTier.basic) {
        await sb.from('profiles').update({'tier': tier.label}).eq('id', res.user!.id);
      }
      final msg = res.session == null
          ? 'Account created! Check your email to confirm, then log in.'
          : 'Account created! You can log in now.';
      return AuthResult(success: true, message: msg);
    } on AuthException catch (e) {
      return AuthResult(success: false, message: e.message);
    }
  }

  // ── ADMIN OPERATIONS ─────────────────────────────────────
  // create/resetPassword/delete call the admin-users Edge Function
  // (needs the service-role key, so it can't happen client-side).
  // update (tier/status) is a plain table write — RLS already allows
  // this for admins, so it goes straight to Postgres.

  /// profiles doesn't carry email (that lives in auth.users, which the
  /// client can never query directly) — so the full list, emails
  /// included, comes from the Edge Function's listUsers action, which
  /// joins auth.users + profiles server-side using the service role.
  Future<List<AppUser>> allUsers() async {
    try {
      final res = await sb.functions.invoke('admin-users', body: {'action': 'listUsers'});
      final rows = (res.data as Map)['users'] as List;
      return rows.map((r) {
        final row = r as Map<String, dynamic>;
        return AppUser.fromSupabase(
          id: row['id'] as String,
          email: row['email'] as String? ?? '',
          profile: row,
        );
      }).toList();
    } on FunctionException catch (e) {
      throw Exception(_funcErrorMessage(e));
    }
  }

  /// The Edge Function throws [FunctionException] on any non-2xx status
  /// (it never returns a non-200 [FunctionResponse]) — pull a readable
  /// message out of whatever shape the error body comes back as.
  String _funcErrorMessage(FunctionException e) {
    final d = e.details;
    if (d is String && d.isNotEmpty) return d;
    if (d is Map && d['error'] is String) return d['error'] as String;
    return e.reasonPhrase ?? 'Request failed (${e.status}).';
  }

  Future<void> adminCreateUser({
    required String username,
    required String email,
    required String password,
    required UserTier tier,
  }) async {
    try {
      await sb.functions.invoke('admin-users', body: {
        'action': 'createUser',
        'username': username.trim(),
        'email': email.trim(),
        'password': password,
        'tier': tier.label,
      });
    } on FunctionException catch (e) {
      throw Exception(_funcErrorMessage(e));
    }
  }

  Future<void> adminUpdateUser(
    String userId, {
    UserTier? tier,
    SubStatus? status,
  }) async {
    final patch = <String, dynamic>{};
    if (tier != null) patch['tier'] = tier.label;
    if (status != null) patch['status'] = status.label;
    if (patch.isEmpty) return;
    await sb.from('profiles').update(patch).eq('id', userId);
  }

  Future<void> adminResetPassword(String userId, String newPassword) async {
    try {
      await sb.functions.invoke('admin-users', body: {
        'action': 'resetPassword',
        'userId': userId,
        'newPassword': newPassword,
      });
    } on FunctionException catch (e) {
      throw Exception(_funcErrorMessage(e));
    }
  }

  Future<void> adminDeleteUser(String userId) async {
    try {
      await sb.functions.invoke('admin-users', body: {
        'action': 'deleteUser',
        'userId': userId,
      });
    } on FunctionException catch (e) {
      throw Exception(_funcErrorMessage(e));
    }
  }
}
