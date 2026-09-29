import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../features/splash/splash_screen.dart';

class ShareTimeApp extends StatelessWidget {
  const ShareTimeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ShareTime',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}
