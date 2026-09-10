import 'package:flutter/material.dart';

import '../../core/api/bck_api_client.dart';

class DevicesPage extends StatefulWidget {
  const DevicesPage({super.key, required this.apiClient});

  final BckApiClient apiClient;

  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
  String _mode = 'PERSONAL';
  PairingCode? _pairing;
  bool _loading = false;
  String? _error;

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final pairing = await widget.apiClient.createPairingCode(_mode);
      if (mounted) {
        setState(() => _pairing = pairing);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Não foi possível gerar o código. Verifique a conexão e suas permissões.');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dispositivos')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Conectar novo aparelho',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Gere um código temporário para conectar outro aparelho somente a esta empresa.',
          ),
          const SizedBox(height: 24),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'PERSONAL',
                label: Text('Pessoal'),
                icon: Icon(Icons.person_outline),
              ),
              ButtonSegment(
                value: 'SHARED',
                label: Text('Compartilhado'),
                icon: Icon(Icons.groups_outlined),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (selection) =>
                setState(() => _mode = selection.first),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _loading ? null : _generate,
            icon: const Icon(Icons.add_link_rounded),
            label: Text(_loading ? 'Gerando...' : 'Gerar código de conexão'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (_pairing != null) ...[
            const SizedBox(height: 28),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    const Text(
                      'Código de conexão',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      _pairing!.code,
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Válido até ${TimeOfDay.fromDateTime(_pairing!.expiresAt.toLocal()).format(context)}',
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Use este código no novo aparelho em “Conectar a uma empresa existente”.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
