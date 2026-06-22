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

  final List<Widget> _pages = [
    const HomeScreen(),
    const TutorialListScreen(),
    const RemoteAssistScreen(),
    const SettingsScreen(),
  ];

  static const _navItems = [
    (icon: Icons.home, label: '首页'),
    (icon: Icons.menu_book, label: '教程'),
    (icon: Icons.support_agent, label: '远程协助'),
    (icon: Icons.settings, label: '设置'),
  ];

  @override
  Widget build(BuildContext context) {
    final scale = context.watch<FontSizeProvider>().scaleFactor;
    final theme = Theme.of(context);
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.grey.shade300)),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 60,
            child: Row(
              children: List.generate(_navItems.length, (index) {
                final item = _navItems[index];
                final isSelected = _currentIndex == index;
                return Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _currentIndex = index),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          item.icon,
                          size: 28,
                          color: isSelected
                              ? theme.primaryColor
                              : Colors.grey,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: (isSelected ? 14 : 12) * scale,
                            color: isSelected
                                ? theme.primaryColor
                                : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}