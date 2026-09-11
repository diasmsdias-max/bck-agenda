import 'package:flutter/material.dart';

import '../../core/theme/bck_theme.dart';
import '../../core/theme/theme_controller.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.themeController});

  final ThemeController themeController;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Configurações')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Aparência',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                'A cor de destaque é uma preferência deste usuário neste aparelho. Ela não altera a empresa, permissões ou sincronização.',
              ),
              const SizedBox(height: 18),
              AnimatedBuilder(
                animation: themeController,
                builder: (context, _) => SegmentedButton<BckAccentTheme>(
                  segments: const [
                    ButtonSegment(
                      value: BckAccentTheme.gold,
                      icon: Icon(Icons.auto_awesome_rounded),
                      label: Text('Dourado'),
                    ),
                    ButtonSegment(
                      value: BckAccentTheme.rose,
                      icon: Icon(Icons.local_florist_outlined),
                      label: Text('Rosé'),
                    ),
                  ],
                  selected: {themeController.accentTheme},
                  onSelectionChanged: (selection) =>
                      themeController.setAccentTheme(selection.first),
                ),
              ),
              const SizedBox(height: 18),
              AnimatedBuilder(
                animation: themeController,
                builder: (context, _) => Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Icon(
                        Icons.palette_outlined,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                    title: Text(
                      themeController.accentTheme == BckAccentTheme.gold
                          ? 'Dourado ativo'
                          : 'Rosé ativo',
                    ),
                    subtitle: const Text(
                      'A alteração é aplicada imediatamente e fica salva localmente.',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}
