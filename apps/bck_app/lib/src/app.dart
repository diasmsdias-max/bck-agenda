import 'package:flutter/material.dart';

import 'core/api/bck_api_client.dart';
import 'features/system/connection_page.dart';

class BckAgendaApp extends StatelessWidget {
  const BckAgendaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BCK Agenda',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFFD6A84B),
        scaffoldBackgroundColor: const Color(0xFF10151D),
        useMaterial3: true,
      ),
      home: ConnectionPage(apiClient: BckApiClient()),
    );
  }
}
