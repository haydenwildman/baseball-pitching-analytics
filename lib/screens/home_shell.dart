import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_session.dart';
import '../theme/app_theme.dart';
import '../widgets/sidebar_nav.dart';
import 'login_screen.dart';
import 'game_input_screen.dart';
import 'overview_screen.dart';
import 'pitch_breakdown_screen.dart';
import 'count_approach_screen.dart';
import 'spray_chart_screen.dart';
import 'game_logs_screen.dart';
import 'pitch_sequencing_screen.dart';
import 'scouting_report_screen.dart';
import 'edit_raw_data_screen.dart';
import 'edit_at_bats_screen.dart';
import 'admin_panel_screen.dart';

/// The authenticated shell of the app: persistent sidebar + a body that
/// swaps between the feature screens, mirroring the R app's
/// `sbNav()` / `.tab-page` show/hide behavior.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  String _selected = 'Game Input';
  bool _drawerOpenOnMobile = false;
  // Only meaningful for the wide/desktop layout — the mobile Drawer is
  // already inherently collapsible (open/close), so this only affects the
  // persistent side rail shown at >=900px width.
  bool _sidebarCollapsed = false;

  /// Looks up the same outline icon already used for this section in the
  /// sidebar, so every screen's top bar carries the "[ICON] PRIMARY TITLE"
  /// pattern consistently, without duplicating an icon map per-screen.
  IconData _iconFor(String label) {
    for (final item in mainNavItems) {
      if (item.label == label) return item.icon;
    }
    if (adminNavItem.label == label) return adminNavItem.icon;
    return Icons.circle_outlined;
  }

  Widget _buildBody(String label) {
    switch (label) {
      case 'Game Input':
        return const GameInputScreen();
      case 'Overview':
        return const OverviewScreen();
      case 'Pitch Breakdown':
        return const PitchBreakdownScreen();
      case 'Count & Approach':
        return const CountApproachScreen();
      case 'Spray Chart':
        return const SprayChartScreen();
      case 'Game Logs':
        return const GameLogsScreen();
      case 'Pitch Sequencing':
        return const PitchSequencingScreen();
      case 'Scouting Report':
        return const ScoutingReportScreen();
      case 'Edit Raw Data':
        return const EditRawDataScreen();
      case 'Edit At-Bats':
        return const EditAtBatsScreen();
      case 'Admin Panel':
        return const AdminPanelScreen();
      default:
        return const GameInputScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSession>();
    final isNarrow = MediaQuery.of(context).size.width < 900;

    final sidebar = SidebarNav(
      selected: _selected,
      onSelect: (label) {
        setState(() {
          _selected = label;
          _drawerOpenOnMobile = false;
        });
      },
      isPlus: session.isPlus,
      isAdmin: session.isAdmin,
      pitcherName:
          session.currentUser?.pitcherDisplayName ?? session.currentUser?.username ?? '—',
      onLogout: () {
        session.logout();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      },
      // Always expanded inside the mobile Drawer (isNarrow) — collapsing
      // only makes sense for the persistent side rail on wide screens.
      collapsed: isNarrow ? false : _sidebarCollapsed,
      onToggleCollapse: () => setState(() => _sidebarCollapsed = !_sidebarCollapsed),
    );

    if (isNarrow) {
      return Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images/logo.png', height: 26),
              const SizedBox(width: 8),
              Icon(_iconFor(_selected), size: 18, color: AppColors.blueDark),
              const SizedBox(width: 6),
              Text(_selected, style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => setState(() => _drawerOpenOnMobile = true),
          ),
        ),
        drawer: Drawer(
          child: sidebar,
        ),
        body: SafeArea(
          child: Stack(
            children: [
              Positioned(
                right: -60,
                bottom: -40,
                child: Image.asset('assets/images/logo_watermark.png', width: 260),
              ),
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _buildBody(_selected),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          sidebar,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppColors.colBorder)),
                  ),
                  child: Row(
                    children: [
                      Image.asset('assets/images/logo.png', height: 28),
                      const SizedBox(width: 10),
                      Icon(_iconFor(_selected), size: 19, color: AppColors.blueDark),
                      const SizedBox(width: 8),
                      Text(
                        _selected,
                        textAlign: TextAlign.left,
                        style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: AppColors.blueDark),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      // Faint watermark behind the working area — matches
                      // the "behind the screen → watermarked version" rule.
                      Positioned(
                        right: -60,
                        bottom: -40,
                        child: Image.asset(
                          'assets/images/logo_watermark.png',
                          width: 320,
                        ),
                      ),
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: _buildBody(_selected),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
