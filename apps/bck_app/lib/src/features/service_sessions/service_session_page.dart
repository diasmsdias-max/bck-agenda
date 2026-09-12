import 'package:flutter/material.dart';

import 'service_session_api.dart';
import 'service_session_models.dart';

class ServiceSessionPage extends StatefulWidget {
  const ServiceSessionPage({
    super.key,
    required this.api,
    required this.appointmentId,
    required this.clientName,
  });

  final ServiceSessionApi api;
  final String appointmentId;
  final String clientName;

  @override
  State<ServiceSessionPage> createState() => _ServiceSessionPageState();
}

class _ServiceSessionPageState extends State<ServiceSessionPage> {
  ServiceSession? _session;
  bool _loading = false;
  Object? _error;

  String _money(double value) => 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';

  Future<void> _open() async {
    setState(() { _loading = true; _error = null; });
    try {
      final value = await widget.api.open(appointmentId: widget.appointmentId);
      if (mounted) setState(() => _session = value);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    final session = _session;
    if (session == null) return;
    setState(() { _loading = true; _error = null; });
    try {
      final value = await widget.api.get(session.id);
      if (mounted) setState(() => _session = value);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _finish() async {
    final session = _session;
    if (session == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finalizar atendimento?'),
        content: Text('Total preparado para recebimento: ${_money(session.total)}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Voltar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Finalizar')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() { _loading = true; _error = null; });
    try {
      final value = await widget.api.finish(session.id);
      if (mounted) setState(() => _session = value);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Atendimento'),
        actions: [if (session != null) IconButton(onPressed: _loading ? null : _refresh, icon: const Icon(Icons.refresh))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(widget.clientName, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text('Agendamento ${widget.appointmentId}', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 20),
          if (_error != null) Card(child: Padding(padding: const EdgeInsets.all(12), child: Text('Não foi possível concluir a operação.\n$_error'))),
          if (session == null)
            FilledButton.icon(
              onPressed: _loading ? null : _open,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(_loading ? 'Abrindo...' : 'Abrir atendimento'),
            )
          else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Resumo', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Text('Subtotal: ${_money(session.subtotal)}'),
                    Text('Descontos: ${_money(session.discountTotal)}'),
                    const Divider(),
                    Text('Total: ${_money(session.total)}', style: Theme.of(context).textTheme.titleLarge),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (!session.isClosed)
              OutlinedButton.icon(
                onPressed: _loading ? null : _finish,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Finalizar atendimento'),
              )
            else
              const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Atendimento finalizado e preparado para recebimento.'))),
          ],
          if (_loading) const Padding(padding: EdgeInsets.only(top: 16), child: LinearProgressIndicator()),
        ],
      ),
    );
  }
}
