import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'biometric_service.dart';

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
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Settings',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Security',
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13, letterSpacing: 1.2)),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF16213E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: _biometricAvailable
                  ? SwitchListTile(
                      title: const Text('Face ID / Biometrics',
                          style: TextStyle(color: Colors.white, fontSize: 16)),
                      subtitle: Text('Lock app with biometrics',
                          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13)),
                      value: _biometricEnabled,
                      onChanged: _toggleBiometric,
                      activeColor: Colors.white,
                      inactiveTrackColor: Colors.white12,
                    )
                  : Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.face, color: Colors.white38),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Face ID / Biometrics',
                                    style: TextStyle(color: Colors.white, fontSize: 16)),
                                Text('Not available on this device',
                                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 24),
            Text('Privacy',
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13, letterSpacing: 1.2)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF16213E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline, color: Colors.greenAccent, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Your data never leaves your device',
                            style: TextStyle(color: Colors.white, fontSize: 15)),
                        const SizedBox(height: 4),
                        Text('No servers. No cloud. No tracking.',
                            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13)),
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