import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import '../screens/dashboard_screen.dart';
import '../screens/market_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/profile_screen.dart'; 
import '../theme/colors.dart';

class BottomNavScreen extends StatefulWidget {
  const BottomNavScreen({super.key});

  @override
  State<BottomNavScreen> createState() => _BottomNavScreenState();
}

class _BottomNavScreenState extends State<BottomNavScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const MarketScreen(),
    const ChatScreen(),
    const ProfileScreen(), 
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        color: AppColors.cardDark,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 20),
          child: GNav(
            backgroundColor: AppColors.cardDark,
            color: AppColors.textGray,
            activeColor: Colors.white,
            tabBackgroundColor: AppColors.primary.withOpacity(0.1),
            gap: 8,
            padding: const EdgeInsets.all(16),
            tabs: const [
              GButton(icon: Icons.dashboard_rounded, text: 'Home'),
              GButton(icon: Icons.candlestick_chart_rounded, text: 'Market'),
              GButton(icon: Icons.smart_toy_rounded, text: 'Advisor'),
              GButton(icon: Icons.person_rounded, text: 'Profile'),
            ],
            selectedIndex: _selectedIndex,
            onTabChange: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
          ),
        ),
      ),
    );
  }
}