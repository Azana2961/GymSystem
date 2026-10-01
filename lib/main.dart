import 'package:flutter/material.dart';
import 'package:gym_system/core/theme/app_theme.dart';
import 'package:gym_system/core/widgets/main_layout.dart';

void main() {
  runApp(const GymSystemApp());
}

class GymSystemApp extends StatelessWidget {
  const GymSystemApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gym System',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const MainLayout(),
    );
  }
}
