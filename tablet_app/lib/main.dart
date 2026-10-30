import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/kiosk_sync_service.dart';
import 'views/kiosk_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fullscreen kiosk immersive mode for tablets
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // Initialize offline storage & real-time sync engine
  await KioskSyncService.instance.init();

  runApp(const GymTabletKioskApp());
}

class GymTabletKioskApp extends StatelessWidget {
  const GymTabletKioskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gym Tablet Kiosk',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF07090C),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E676),
          surface: Color(0xFF0F1318),
        ),
      ),
      home: const KioskScreen(),
    );
  }
}
