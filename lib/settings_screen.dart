import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'biometric_service.dart';
import 'main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    themeNotifier.addListener(() => setState(() {}));
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final available = await BiometricService.isAvailable();
    setState(() {
      _biometricEnabled = prefs.getBool('biometric_enabled') ?? false;
      _biometricAvailable = available;
    });
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      final authenticated = await BiometricService.authenticate();
      if (!authenticated) return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_enabled', value);
    setState(() => _biometricEnabled = value);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = themeNotifier.isDark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Settings',
            style: TextStyle(
                color: textColor, fontWeight: FontWeight.bold, fontSize: 20)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Appearance
            Text('Appearance',
                style: TextStyle(
                    color: textColor.withOpacity(0.5),
                    fontSize: 13,
                    letterSpacing: 1.2)),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: SwitchListTile(
                title: Text('Dark Mode',
                    style: TextStyle(color: textColor, fontSize: 16)),
                subtitle: Text(
                    isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                    style:
                        TextStyle(color: textColor.withOpacity(0.4), fontSize: 13)),
                value: isDark,
                onChanged: (_) => themeNotifier.toggle(),
                activeColor: AppColors.accent,
                inactiveTrackColor: textColor.withOpacity(0.1),
              ),
            ),

            const SizedBox(height: 24),

            // Security
            Text('Security',
                style: TextStyle(
                    color: textColor.withOpacity(0.5),
                    fontSize: 13,
                    letterSpacing: 1.2)),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: _biometricAvailable
                  ? SwitchListTile(
                      title: Text('Face ID / Biometrics',
                          style: TextStyle(color: textColor, fontSize: 16)),
                      subtitle: Text('Lock app with biometrics',
                          style: TextStyle(
                              color: textColor.withOpacity(0.4), fontSize: 13)),
                      value: _biometricEnabled,
                      onChanged: _toggleBiometric,
                      activeColor: AppColors.accent,
                      inactiveTrackColor: textColor.withOpacity(0.1),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.face, color: textColor.withOpacity(0.4)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Face ID / Biometrics',
                                    style:
                                        TextStyle(color: textColor, fontSize: 16)),
                                Text('Not available on this device',
                                    style: TextStyle(
                                        color: textColor.withOpacity(0.4),
                                        fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),

            const SizedBox(height: 24),

            // Privacy
            Text('Privacy',
                style: TextStyle(
                    color: textColor.withOpacity(0.5),
                    fontSize: 13,
                    letterSpacing: 1.2)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline,
                      color: Colors.greenAccent, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Your data never leaves your device',
                            style: TextStyle(color: textColor, fontSize: 15)),
                        const SizedBox(height: 4),
                        Text('No servers. No cloud. No tracking.',
                            style: TextStyle(
                                color: textColor.withOpacity(0.4), fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}