import 'package:flutter/material.dart';
import '../core/colors.dart';
import '../widgets/floating_nav_bar.dart';
import '../widgets/log_bottom_sheet.dart';
import 'home_screen.dart';
import 'statistics_screen.dart';
import 'ai_insights_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // Index 2 is the FAB — not a real screen. Map to 4 actual screens:
  // nav 0→screen 0, nav 1→screen 1, nav 2→FAB, nav 3→screen 2, nav 4→screen 3
  final List<Widget> _screens = const [
    HomeScreen(),
    StatisticsScreen(),
    AiInsightsScreen(),
    ProfileScreen(),
  ];

  int _navToScreen(int navIndex) {
    if (navIndex < 2) return navIndex;
    return navIndex - 1; // 3→2, 4→3
  }

  void _onNavTap(int index) {
    if (index == 2) {
      showLogBottomSheet(context);
      return;
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final screenIndex = _navToScreen(_currentIndex);

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      extendBody: true,
      body: IndexedStack(
        index: screenIndex.clamp(0, _screens.length - 1),
        children: _screens,
      ),
      bottomNavigationBar: FloatingNavBar(
        currentIndex: _currentIndex,
        onTap: _onNavTap,
      ),
    );
  }
}
