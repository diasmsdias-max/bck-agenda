import 'package:flutter/material.dart';

import '../../core/api/bck_api_client.dart';
import '../../core/theme/theme_controller.dart';
import 'connect_company_page.dart';
import 'create_company_page.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({
    super.key,
    required this.apiClient,
    required this.themeController,
  });

  final BckApiClient apiClient;
  final ThemeController themeController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(
                Icons.calendar_month_rounded,
                size: 72,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'BCK Agenda',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Organize. Atenda. Gerencie.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white70,
                    ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CreateCompanyPage(apiClient: apiClient),
                  ),
                ),
                icon: const Icon(Icons.add_business_rounded),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('Criar minha empresa'),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ConnectCompanyPage(
                      apiClient: apiClient,
                      themeController: themeController,
                    ),
                  ),
                ),
                icon: const Icon(Icons.sync_rounded),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('Conectar a uma empresa existente'),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Beleza é gestão.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
