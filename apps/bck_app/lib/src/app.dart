import 'package:flutter/material.dart';

import 'core/api/bck_api_client.dart';
import 'features/auth/session_gate.dart';

class BckAgendaApp extends StatelessWidget {
  const BckAgendaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final apiClient = BckApiClient();
    return MaterialApp(
      title: 'BCK Agenda',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFFD6A84B),
        scaffoldBackgroundColor: const Color(0xFF10151D),
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
        useMaterial3: true,
      ),
      home: SessionGate(apiClient: apiClient),
    );
  }
}
