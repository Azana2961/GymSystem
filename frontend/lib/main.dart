import 'package:flutter/material.dart';
import 'package:gym_system/core/constants/app_settings.dart';
import 'package:gym_system/core/theme/app_theme.dart';
import 'package:gym_system/core/widgets/main_layout.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AppSettings.instance.loadFromServer();
  runApp(const GymSystemApp());
}

class GymSystemApp extends StatelessWidget {
  const GymSystemApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lá Fitness',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(accessibleNavigation: false),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const MainLayout(),
    );
  }
}
