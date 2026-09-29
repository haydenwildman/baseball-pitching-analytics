import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import '../models/user.dart';
import 'billing_service.dart';
import 'storage_service.dart';

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
/// Replaces R's `sodium::password_store` / `password_verify` +
/// SQLite `users` table. Uses a per-user random salt + SHA-256,
/// which is adequate for a local-storage demo app. For a production
/// deployment behind a real backend, swap this for bcrypt/argon2 on
/// the server and never store or compare hashes on-device.
/// ══════════════════════════════════════════════════════════════
class AuthService {
  final StorageService storage;
  final _uuid = const Uuid();

  AuthService(this.storage);

  String _generateSalt() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    return base64UrlEncode(bytes);
  }

  String _hash(String password, String salt) {
    final bytes = utf8.encode('$salt::$password');
    return sha256.convert(bytes).toString();
  }

  /// Bootstraps the very first admin account — but ONLY if you explicitly
  /// provide credentials at build/run time via --dart-define. This app
  /// ships with NO default admin account and NO hardcoded password;
  /// anyone reading the source or decompiling the built app should not
  /// be able to find a working login.
  ///
  /// To create your first admin account, run the app once with:
  ///
  ///   flutter run --dart-define=SEED_ADMIN_USER=youradminname \
  ///               --dart-define=SEED_ADMIN_PASS=SomeStrongPassword123
  ///
  /// After that first run, the account exists in local storage — stop
  /// passing those --dart-define flags for all future runs/builds (and
  /// definitely don't ship a release build with them set, since that
  /// bakes the password into the binary). Once you're logged in as
  /// admin, use the Admin Panel to create additional admins normally —
  /// you never need this bootstrap path again after the first run.
  Future<void> ensureSeedAdmin() async {
    const seedUser = String.fromEnvironment('SEED_ADMIN_USER');
    const seedPass = String.fromEnvironment('SEED_ADMIN_PASS');
    if (seedUser.isEmpty || seedPass.isEmpty) return; // no-op by default

    final users = await storage.loadUsers();
    if (users.any((u) => u.username.toLowerCase() == seedUser.toLowerCase())) {
      return; // already bootstrapped
    }
    final salt = _generateSalt();
    users.add(AppUser(
      id: _uuid.v4(),
      username: seedUser,
      email: '$seedUser@example.com',
      passwordHash: _hash(seedPass, salt),
      salt: salt,
      tier: UserTier.admin,
      status: SubStatus.active,
    ));
    await storage.saveUsers(users);
  }

  Future<AuthResult> login(String username, String password) async {
    final users = await storage.loadUsers();
    final match = users.firstWhereOrNullCompat(
        (u) => u.username.toLowerCase() == username.trim().toLowerCase());
    if (match == null) {
      return AuthResult(success: false, message: 'Invalid username or password.');
    }
    final hashed = _hash(password, match.salt);
    if (hashed != match.passwordHash) {
      return AuthResult(success: false, message: 'Invalid username or password.');
    }
    if (!match.isActive) {
      return AuthResult(success: false, message: 'Account inactive. Contact support.');
    }
    return AuthResult(success: true, user: match);
  }

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
      return AuthResult(
          success: false, message: 'Password must be at least 6 characters.');
    }
    if (password != confirmPassword) {
      return AuthResult(success: false, message: 'Passwords do not match.');
    }
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username.trim())) {
      return AuthResult(
          success: false,
          message: 'Username: letters, numbers, underscore only.');
    }
    final users = await storage.loadUsers();
    if (users.any(
        (u) => u.username.toLowerCase() == username.trim().toLowerCase())) {
      return AuthResult(success: false, message: 'Username already taken.');
    }
    final salt = _generateSalt();
    // ── BILLING HOOK POINT ──────────────────────────────────────
    // Both Basic and Plus are paid tiers now (see PricingConfig).
    // In production, a brand-new account should be SubStatus.pendingPayment
    // until Stripe/RevenueCat confirms the first payment via webhook —
    // then your backend flips it to `active` (see billing_service.dart).
    // For this local-storage demo (no backend wired up yet) we mark new
    // accounts `active` immediately so the app is usable end-to-end.
    // Flip the line below once real billing is connected:
    //   final status = SubStatus.pendingPayment;
    const status = SubStatus.active;
    final newUser = AppUser(
      id: _uuid.v4(),
      username: username.trim(),
      email: email.trim(),
      passwordHash: _hash(password, salt),
      salt: salt,
      tier: tier,
      status: status,
    );
    users.add(newUser);
    await storage.saveUsers(users);
    final msg =
        'Account created! (${PricingConfig.priceLabel(tier)}) You can log in now — '
        'once billing is connected, new accounts will show as pending until '
        'payment is confirmed.';
    return AuthResult(success: true, message: msg, user: newUser);
  }

  // ── ADMIN OPERATIONS ─────────────────────────────────────
  Future<List<AppUser>> allUsers() => storage.loadUsers();

  Future<void> adminCreateUser({
    required String username,
    required String email,
    required String password,
    required UserTier tier,
  }) async {
    final users = await storage.loadUsers();
    if (users.any(
        (u) => u.username.toLowerCase() == username.trim().toLowerCase())) {
      throw Exception('Username already taken.');
    }
    final salt = _generateSalt();
    users.add(AppUser(
      id: _uuid.v4(),
      username: username.trim(),
      email: email.trim(),
      passwordHash: _hash(password, salt),
      salt: salt,
      tier: tier,
      status: SubStatus.active,
    ));
    await storage.saveUsers(users);
  }

  Future<void> adminUpdateUser(
    String userId, {
    UserTier? tier,
    SubStatus? status,
  }) async {
    final users = await storage.loadUsers();
    final idx = users.indexWhere((u) => u.id == userId);
    if (idx == -1) throw Exception('User not found.');
    if (tier != null) users[idx].tier = tier;
    if (status != null) users[idx].status = status;
    await storage.saveUsers(users);
  }

  Future<void> adminResetPassword(String userId, String newPassword) async {
    final users = await storage.loadUsers();
    final idx = users.indexWhere((u) => u.id == userId);
    if (idx == -1) throw Exception('User not found.');
    final salt = _generateSalt();
    users[idx].salt = salt;
    users[idx].passwordHash = _hash(newPassword, salt);
    await storage.saveUsers(users);
  }

  Future<void> adminDeleteUser(String userId) async {
    final users = await storage.loadUsers();
    users.removeWhere((u) => u.id == userId);
    await storage.saveUsers(users);
  }
}

/// Small helper since `firstWhereOrNull` requires importing `collection`
/// in every call site otherwise; kept local to avoid an extra import here.
extension _FirstWhereOrNull<T> on List<T> {
  T? firstWhereOrNullCompat(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}
