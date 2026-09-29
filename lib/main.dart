import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/storage_service.dart';
import 'services/auth_service.dart';
import 'services/app_session.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = StorageService();
  final auth = AuthService(storage);
  await auth.ensureSeedAdmin(); // no-op unless SEED_ADMIN_USER/PASS are passed in, see README §4

  final session = AppSession(auth: auth, storage: storage);

  runApp(
    ChangeNotifierProvider.value(
      value: session,
      child: const PitchingAnalyticsApp(),
    ),
  );
}

class PitchingAnalyticsApp extends StatelessWidget {
  const PitchingAnalyticsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pitching Analytics',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const _RootRouter(),
    );
  }
}

/// Decides whether to show the Login screen or the authenticated Home
/// shell, based on whether AppSession already has a logged-in user
/// (relevant if we ever add "remember me" persistence of the session).
class _RootRouter extends StatelessWidget {
  const _RootRouter();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSession>();
    return session.isLoggedIn ? const HomeShell() : const LoginScreen();
  }
}
