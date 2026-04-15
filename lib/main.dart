import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'onboarding.dart';
import 'main_nav.dart';
import 'database.dart';
import 'biometric_service.dart';

late AppDatabase database;

// Theme Notifier
class ThemeNotifier extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.dark;

  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  void toggle() {
    _mode = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }
}

final themeNotifier = ThemeNotifier();

// App Colors
class AppColors {
  // Dark
  static const darkBg = Color(0xFF0A0A0A);
  static const darkCard = Color(0xFF1C1C1E);
  static const darkCardAlt = Color(0xFF2C2C2E);

  // Light
  static const lightBg = Color(0xFFF2F2F7);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightCardAlt = Color(0xFFE5E5EA);

  static const accent = Color(0xFFFFCC00);
  static const accentBlue = Color(0xFF6C63FF);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  database = AppDatabase();
  runApp(const TripPackApp());
}

class TripPackApp extends StatefulWidget {
  const TripPackApp({super.key});

  @override
  State<TripPackApp> createState() => _TripPackAppState();
}

class _TripPackAppState extends State<TripPackApp> {
  @override
  void initState() {
    super.initState();
    themeNotifier.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TripPack',
      debugShowCheckedModeBanner: false,
      themeMode: themeNotifier.mode,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.lightBg,
        cardColor: AppColors.lightCard,
        colorScheme: const ColorScheme.light(
          primary: AppColors.accent,
          surface: AppColors.lightCard,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.lightBg,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.darkBg,
        cardColor: AppColors.darkCard,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.accent,
          surface: AppColors.darkCard,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.darkBg,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: const AppEntry(),
    );
  }
}

class AppEntry extends StatefulWidget {
  const AppEntry({super.key});

  @override
  State<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<AppEntry> {
  bool _checking = true;
  bool _authenticated = false;
  bool _biometricEnabled = false;
  bool _onboardingComplete = false;

  @override
  void initState() {
    super.initState();
    _checkStartup();
  }

  Future<void> _checkStartup() async {
    final prefs = await SharedPreferences.getInstance();
    final onboardingComplete = prefs.getBool('onboarding_complete') ?? false;
    final enabled = prefs.getBool('biometric_enabled') ?? false;
    setState(() {
      _onboardingComplete = onboardingComplete;
      _biometricEnabled = enabled;
    });

    if (!enabled) {
      setState(() {
        _authenticated = true;
        _checking = false;
      });
      return;
    }

    final result = await BiometricService.authenticate();
    setState(() {
      _authenticated = result;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = themeNotifier.isDark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final textColor = isDark ? Colors.white : Colors.black;

    if (_checking) {
      return Scaffold(
        backgroundColor: bg,
        body: const Center(
          child: CircularProgressIndicator(color: Colors.white38),
        ),
      );
    }

    if (!_authenticated && _biometricEnabled) {
      return Scaffold(
        backgroundColor: bg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, color: textColor.withOpacity(0.4), size: 64),
              const SizedBox(height: 24),
              Text('TripPack is locked',
                  style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Authenticate to continue',
                  style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 15)),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _checkStartup,
                icon: const Icon(Icons.fingerprint),
                label: const Text('Unlock'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.white : Colors.black,
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_onboardingComplete) {
      return const MainNav();
    }

    return const OnboardingScreen();
  }
}