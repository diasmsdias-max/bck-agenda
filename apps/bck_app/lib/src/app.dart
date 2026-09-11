import 'package:flutter/material.dart';

import 'core/api/bck_api_client.dart';
import 'core/theme/bck_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/auth/session_gate.dart';

class BckAgendaApp extends StatefulWidget {
  const BckAgendaApp({super.key});

  @override
  State<BckAgendaApp> createState() => _BckAgendaAppState();
}

class _BckAgendaAppState extends State<BckAgendaApp> {
  late final BckApiClient _apiClient;
  late final ThemeController _themeController;

  @override
  void initState() {
    super.initState();
    _apiClient = BckApiClient();
    _themeController = ThemeController()..load();
  }

  @override
  void dispose() {
    _themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _themeController,
      builder: (context, _) => MaterialApp(
        title: 'BCK Agenda',
        debugShowCheckedModeBanner: false,
        theme: BckTheme.dark(_themeController.accentTheme),
        home: SessionGate(
          apiClient: _apiClient,
          themeController: _themeController,
        ),
      ),
    );
  }
}
