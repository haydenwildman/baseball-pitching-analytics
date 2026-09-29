/// Subscription / permission tier — mirrors the R app's `tier` column
/// ("basic", "plus") plus a dedicated "admin" tier for the admin panel.
enum UserTier { basic, plus, admin }

extension UserTierX on UserTier {
  String get label => switch (this) {
        UserTier.basic => 'basic',
        UserTier.plus => 'plus',
        UserTier.admin => 'admin',
      };

  static UserTier fromString(String s) {
    switch (s.toLowerCase().trim()) {
      case 'plus':
        return UserTier.plus;
      case 'admin':
        return UserTier.admin;
      default:
        return UserTier.basic;
    }
  }
}

/// Subscription status — mirrors R's `subscription_status` column.
enum SubStatus { active, inactive, pendingPayment, canceled }

extension SubStatusX on SubStatus {
  String get label => switch (this) {
        SubStatus.active => 'active',
        SubStatus.inactive => 'inactive',
        SubStatus.pendingPayment => 'pending_payment',
        SubStatus.canceled => 'canceled',
      };

  static SubStatus fromString(String s) {
    switch (s.toLowerCase().trim()) {
      case 'inactive':
        return SubStatus.inactive;
      case 'pending_payment':
        return SubStatus.pendingPayment;
      case 'canceled':
        return SubStatus.canceled;
      default:
        return SubStatus.active;
    }
  }
}

class AppUser {
  final String id; // uuid, stable primary key
  String username;
  String email;
  String passwordHash; // salted SHA-256, see AuthService
  String salt;
  UserTier tier;
  SubStatus status;
  String pitcherDisplayName;
  DateTime createdAt;

  AppUser({
    required this.id,
    required this.username,
    required this.email,
    required this.passwordHash,
    required this.salt,
    this.tier = UserTier.basic,
    this.status = SubStatus.active,
    String? pitcherDisplayName,
    DateTime? createdAt,
  })  : pitcherDisplayName = pitcherDisplayName ?? username,
        createdAt = createdAt ?? DateTime.now();

  bool get isPlus => tier == UserTier.plus || tier == UserTier.admin;
  bool get isAdmin => tier == UserTier.admin;
  bool get isActive => status == SubStatus.active;

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'email': email,
        'passwordHash': passwordHash,
        'salt': salt,
        'tier': tier.label,
        'status': status.label,
        'pitcherDisplayName': pitcherDisplayName,
        'createdAt': createdAt.toIso8601String(),
      };

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] as String,
        username: j['username'] as String,
        email: j['email'] as String,
        passwordHash: j['passwordHash'] as String,
        salt: j['salt'] as String,
        tier: UserTierX.fromString(j['tier'] as String? ?? 'basic'),
        status: SubStatusX.fromString(j['status'] as String? ?? 'active'),
        pitcherDisplayName: j['pitcherDisplayName'] as String? ?? j['username'],
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
}
