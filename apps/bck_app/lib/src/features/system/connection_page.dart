import 'package:flutter/material.dart';

import '../../core/api/bck_api_client.dart';

class ConnectionPage extends StatefulWidget {
  const ConnectionPage({super.key, required this.apiClient});

  final BckApiClient apiClient;

  @override
  State<ConnectionPage> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends State<ConnectionPage> {
  ApiHealth? _health;
  Object? _error;
  bool _loading = false;

  Future<void> _testConnection() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final health = await widget.apiClient.health();
      if (!mounted) return;
      setState(() => _health = health);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final health = _health;
    return Scaffold(
      appBar: AppBar(title: const Text('BCK Agenda')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.event_available, size: 72),
                const SizedBox(height: 20),
                Text(
                  'Organize. Atenda. Gerencie.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: _loading ? null : _testConnection,
                  icon: const Icon(Icons.cloud_done_outlined),
                  label: Text(_loading ? 'Conectando...' : 'Testar conexão com a API'),
                ),
                const SizedBox(height: 20),
                if (health != null)
                  Text(
                    'API conectada: ${health.service} v${health.version}\nServidor: ${health.serverTimeUtc.toLocal()}',
                    textAlign: TextAlign.center,
                  ),
                if (_error != null)
                  Text(
                    'Não foi possível conectar à API.\n$_error',
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
