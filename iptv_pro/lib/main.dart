import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'config/theme.dart';
import 'providers/app_provider.dart';
import 'providers/mini_player_provider.dart';
import 'screens/login/login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const IPTVProApp());
}

class IPTVProApp extends StatelessWidget {
  const IPTVProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
        ChangeNotifierProvider(create: (_) => MiniPlayerProvider()),
      ],
      child: MaterialApp(
        title: 'IPTV Pro',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const LoginScreen(),
      ),
    );
  }
}
