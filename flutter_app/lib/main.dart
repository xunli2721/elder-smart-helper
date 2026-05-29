import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'providers/font_size_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/tutorial_list_screen.dart';
import 'screens/remote_assist_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => FontSizeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // 启动时从本地缓存加载字体设置
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FontSizeProvider>().loadFromPrefs();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FontSizeProvider>(
      builder: (context, fontProvider, _) {
        return MaterialApp(
          title: '智能助手',
          theme: AppTheme.lightTheme(scaleFactor: fontProvider.scaleFactor),
          home: const SplashScreen(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomeScreen(),
    TutorialListScreen(),
    RemoteAssistScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final scale = context.watch<FontSizeProvider>().scaleFactor;
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedFontSize: 14 * scale,
        unselectedFontSize: 12 * scale,
        iconSize: 28,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '首页'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: '教程'),
          BottomNavigationBarItem(icon: Icon(Icons.support_agent), label: '远程协助'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: '设置'),
        ],
      ),
    );
  }
}