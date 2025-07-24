
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'screens/meal_screen.dart';
import 'screens/schedule_screen.dart';
import 'screens/study_screen.dart';
import 'screens/user_screen.dart';
import 'screens/school_setup_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko_KR', null);
  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isSchoolInfoSet = false;
  bool _isLoading = true;
  final String _apiKey = 'APIkeyhere'; // 고등학교 시간표 API 키
  bool _isConnected = true;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _checkSchoolInfo();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      setState(() {
        _isConnected = results.any((result) => result != ConnectivityResult.none);
      });
    });
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  Future<void> _checkSchoolInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isSchoolInfoSet = prefs.containsKey('schoolCode');
      _isLoading = false;
    });
  }

  void _onSetupComplete() {
    setState(() {
      _isSchoolInfoSet = true;
    });
  }

  void _clearSchoolInfo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    setState(() {
      _isSchoolInfoSet = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: '오늘의 급식',
          themeMode: themeProvider.themeMode,
          theme: ThemeData(
            primarySwatch: Colors.blueGrey,
            visualDensity: VisualDensity.adaptivePlatformDensity,
            textTheme: GoogleFonts.notoSansKrTextTheme(Theme.of(context).textTheme),
            brightness: Brightness.light,
          ),
          darkTheme: ThemeData(
            primarySwatch: Colors.blueGrey,
            visualDensity: VisualDensity.adaptivePlatformDensity,
            textTheme: GoogleFonts.notoSansKrTextTheme(Theme.of(context).textTheme),
            brightness: Brightness.dark,
            scaffoldBackgroundColor: Colors.grey[900],
            cardColor: Colors.grey[800],
            appBarTheme: AppBarTheme(
              backgroundColor: Colors.grey[850],
              foregroundColor: Colors.white,
            ),
            // Add more dark theme specific colors as needed
          ),
          home: _isLoading
              ? const SplashScreen()
              : _isConnected
                  ? _isSchoolInfoSet
                      ? MainScreen(onSchoolInfoCleared: _clearSchoolInfo)
                      : SchoolSetupScreen(apiKey: _apiKey, onSetupComplete: _onSetupComplete)
                  : const NoInternetScreen(),
        );
      },
    );
  }
}

class NoInternetScreen extends StatelessWidget {
  const NoInternetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[100],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              IconlyBold.danger,
              size: 100,
              color: Colors.blue[800],
            ),
            const SizedBox(height: 20),
            Text(
              '인터넷 연결을 확인해주세요.',
              style: GoogleFonts.notoSansKr(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue[800]),
            ),
          ],
        ),
      ),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Lottie.asset('assets/app_loading.json', width: 200, height: 200),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  final VoidCallback onSchoolInfoCleared;
  const MainScreen({super.key, required this.onSchoolInfoCleared});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final String _apiKey = 'APIkeyhere';
  int _page = 0;
  late final List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();
    _widgetOptions = <Widget>[
      MealScreen(apiKey: _apiKey),
      ScheduleScreen(apiKey: _apiKey),
      const StudyScreen(),
      UserScreen(onSchoolInfoCleared: widget.onSchoolInfoCleared),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text('앱 종료', style: GoogleFonts.notoSansKr()),
              content: Text('정말 앱을 종료하시겠습니까?', style: GoogleFonts.notoSansKr()),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('취소', style: GoogleFonts.notoSansKr()),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text('종료', style: GoogleFonts.notoSansKr(color: Colors.red)),
                ),
              ],
            );
          },
        );
        return shouldPop ?? false;
      },
      child: Scaffold(
        body: _widgetOptions[_page],
        bottomNavigationBar: CurvedNavigationBar(
          index: _page,
          height: 60.0,
          items: const <Widget>[
            Icon(IconlyBold.document, size: 30, color: Colors.white),
            Icon(IconlyBold.calendar, size: 30, color: Colors.white),
            Icon(IconlyBold.edit, size: 30, color: Colors.white),
            Icon(IconlyBold.profile, size: 30, color: Colors.white),
          ],
          color: Colors.blue.shade400,
          buttonBackgroundColor: Colors.blue.shade400,
          backgroundColor: Colors.transparent,
          animationCurve: Curves.easeInOut,
          animationDuration: const Duration(milliseconds: 600),
          onTap: (index) {
            setState(() {
              _page = index;
            });
          },
          letIndexChange: (index) => true,
        ),
      ),
    );
  }
}
