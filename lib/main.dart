import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'pages/home_page.dart';
import 'pages/history_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize window manager for desktop
  try {
    await windowManager.ensureInitialized();
    
    const windowOptions = WindowOptions(
      size: Size(1000, 700),
      minimumSize: Size(600, 400),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
    );
    
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  } catch (e) {
    // Window manager not available on mobile
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Markdown Editor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      home: const MainScreen(),
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
  bool _isDesktop = false;

  final List<Widget> _pages = const [
    HomePage(),
    HistoryPage(),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isDesktop = MediaQuery.of(context).size.width > 600;
  }

  @override
  Widget build(BuildContext context) {
    if (_isDesktop) {
      return _buildDesktopLayout();
    } else {
      return _buildMobileLayout();
    }
  }

  Widget _buildDesktopLayout() {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: Text('Home'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.history_outlined),
                selectedIcon: Icon(Icons.history),
                label: Text('History'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: _pages[_currentIndex],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
        ],
      ),
    );
  }
}
