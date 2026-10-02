import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/storage_service.dart';
import 'services/auth_service.dart';
import 'services/app_session.dart';
import 'services/supabase_config.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSupabase();

  final storage = StorageService();
  final auth = AuthService();
  final session = AppSession(auth: auth, storage: storage);

  // If a Supabase session was persisted from a previous visit (same
  // browser/device), pick it back up so the person doesn't have to log
  // in again every time.
  final restoredUser = await auth.restoreSession();
  if (restoredUser != null) {
    await session.login(restoredUser);
  }

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
/// (set either by a fresh login, or by the session-restore in main()).
class _RootRouter extends StatelessWidget {
  const _RootRouter();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSession>();
    return session.isLoggedIn ? const HomeShell() : const LoginScreen();
  }
}
