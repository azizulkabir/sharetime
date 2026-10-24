import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/chat/chats_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/discover/discover_screen.dart';
import '../features/home/home_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/rates/rates_screen.dart';
import '../features/service_requests/incoming_requests_screen.dart';
import '../features/service_requests/my_requests_screen.dart';
import '../features/sessions/my_sessions_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/wallet/wallet_screen.dart';
import '../features/wallet/wallet_admin_screen.dart';
import 'routes.dart';

class ShareTimeApp extends StatelessWidget {
  const ShareTimeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ShareTime',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: AppRoutes.splash,
      routes: {
        AppRoutes.splash: (_) => const SplashScreen(),
        AppRoutes.login: (_) => const LoginScreen(),
        AppRoutes.register: (_) => const RegisterScreen(),
        AppRoutes.home: (_) => const HomeScreen(),
        AppRoutes.profile: (_) => const ProfileScreen(),
        AppRoutes.discover: (_) => const DiscoverScreen(),
        AppRoutes.rates: (_) => const RatesScreen(),
        AppRoutes.incomingRequests: (_) => const IncomingRequestsScreen(),
        AppRoutes.myRequests: (_) => const MyRequestsScreen(),
        AppRoutes.mySessions: (_) => const MySessionsScreen(),
        AppRoutes.chats: (_) => const ChatsScreen(),
        AppRoutes.wallet: (_) => const WalletScreen(),
        AppRoutes.walletAdmin: (_) => const WalletAdminScreen(),
      },
    );
  }
}
