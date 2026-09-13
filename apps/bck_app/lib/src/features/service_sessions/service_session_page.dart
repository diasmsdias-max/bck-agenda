import 'package:flutter/material.dart';

import 'add_service_session_item_dialog.dart';
import 'service_session_api.dart';
import 'service_session_models.dart';

class ServiceSessionPage extends StatefulWidget {
  const ServiceSessionPage({super.key, required this.api, required this.appointmentId, required this.clientName});
  final ServiceSessionApi api;
  final String appointmentId;
  final String clientName;
  @override
  State<ServiceSessionPage> createState() => _ServiceSessionPageState();
}

class _ServiceSessionPageState extends State<ServiceSessionPage> {
  ServiceSession? _session;
  bool _loading = false;
  bool _changed = false;
  bool _allowPop = false;
  Object? _error;

  String _money(double value) => 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
  String _time(DateTime? value) {
    if (value == null) return '—';
    final local = value.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
  String _duration(ServiceSession session) {
    final minutes = session.effectiveDurationMinutes;
    if (minutes != null) return '$minutes min';
    if (session.serviceStartedAt != null && !session.isClosed) return 'Em andamento';
    return '—';
  }

  @override
  void initState() { super.initState(); WidgetsBinding.instance.addPostFrameCallback((_) => _openOrResume()); }
  void _exit() { if (!mounted || _allowPop) return; setState(() => _allowPop = true); WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) Navigator.of(context).pop(_changed); }); }
  Future<T?> _busy<T>(Future<T> Function() action) async { setState(() { _loading = true; _error = null; }); try { return await action(); } catch (error) { if (mounted) setState(() => _error = error); return null; } finally { if (mounted) setState(() => _loading = false); } }
  Future<void> _openOrResume() async { if (_loading || _session != null) return; setState(() { _loading = true; _error = null; }); try { final existing = await widget.api.getByAppointment(widget.appointmentId); if (!mounted || _session != null) return; if (existing != null) { setState(() => _session = existing); return; } final opened = await widget.api.open(appointmentId: widget.appointmentId); if (mounted) setState(() { _session = opened; _changed = true; }); } catch (error) { if (mounted) setState(() => _error = error); } finally { if (mounted) setState(() => _loading = false); } }
  Future<void> _refresh() async { final session = _session; if (session == null) return; final value = await _busy(() => widget.api.get(session.id)); if (mounted && value != null) setState(() => _session = value); }
  Future<void> _addItem() async { final session = _session; if (session == null) return; final draft = await showDialog<ServiceSessionItemDraft>(context: context, builder: (_) => const AddServiceSessionItemDialog()); if (draft == null) return; final item = await _busy(() => widget.api.addItem(session.id, itemType: 'PRODUCT', name: draft.name, quantity: draft.quantity, unitPrice: draft.unitPrice, discountAmount: draft.discountAmount)); if (item != null) { _changed = true; await _refresh(); } }
  Future<void> _finish() async { final session = _session; if (session == null) return; final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Finalizar atendimento?'), content: Text('Total preparado para recebimento: ${_money(session.total)}'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Voltar')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Finalizar'))])); if (confirmed != true) return; final value = await _busy(() => widget.api.finish(session.id)); if (mounted && value != null) setState(() { _session = value; _changed = true; }); }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    return PopScope<bool>(canPop: _allowPop, onPopInvokedWithResult: (didPop, result) { if (!didPop) _exit(); }, child: Scaffold(
      appBar: AppBar(title: const Text('Atendimento'), leading: BackButton(onPressed: _exit), actions: [if (session != null) IconButton(onPressed: _loading ? null : _refresh, icon: const Icon(Icons.refresh))]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(widget.clientName, style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 6),
        Text('Agendamento ${widget.appointmentId}', style: Theme.of(context).textTheme.bodySmall), const SizedBox(height: 20),
        if (_error != null) Card(child: Padding(padding: const EdgeInsets.all(12), child: Text('Não foi possível concluir a operação.\n$_error'))),
        if (session == null)
          FilledButton.icon(onPressed: _loading ? null : _openOrResume, icon: const Icon(Icons.play_arrow_rounded), label: Text(_loading ? 'Carregando atendimento...' : 'Tentar carregar atendimento novamente'))
        else ...[
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Tempo real', style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 12),
            Row(children: [const Expanded(child: Text('Chegada')), Text(_time(session.arrivedAt))]),
            Row(children: [const Expanded(child: Text('Início')), Text(_time(session.serviceStartedAt))]),
            Row(children: [const Expanded(child: Text('Término')), Text(_time(session.serviceFinishedAt))]),
            const Divider(),
            Row(children: [const Expanded(child: Text('Duração efetiva')), Text(_duration(session), key: const Key('effective-duration'))]),
          ]))),
          const SizedBox(height: 12),
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Resumo', style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 12), Text('Subtotal: ${_money(session.subtotal)}'), Text('Descontos: ${_money(session.discountTotal)}'), const Divider(), Text('Total: ${_money(session.total)}', style: Theme.of(context).textTheme.titleLarge),
          ]))),
          const SizedBox(height: 12),
          if (!session.isClosed) ...[
            FilledButton.tonalIcon(onPressed: _loading ? null : _addItem, icon: const Icon(Icons.add_shopping_cart), label: const Text('Adicionar produto/item extra')), const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: _loading ? null : _finish, icon: const Icon(Icons.check_circle_outline), label: const Text('Finalizar atendimento')),
          ] else const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Atendimento finalizado e preparado para recebimento.'))),
        ],
        if (_loading) const Padding(padding: EdgeInsets.only(top: 16), child: LinearProgressIndicator()),
      ]),
    ));
  }
}
