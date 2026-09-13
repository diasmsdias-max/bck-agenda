import 'package:flutter/material.dart';

import '../../core/api/bck_api_client.dart';
import '../../core/auth/session_store.dart';

class NewAppointmentPage extends StatefulWidget {
  const NewAppointmentPage({
    super.key,
    required this.session,
    required this.apiClient,
    this.day,
    this.initialHour,
    this.initialProfessionalId,
  });

  final StoredSession session;
  final BckApiClient apiClient;
  final DateTime? day;
  final int? initialHour;
  final String? initialProfessionalId;

  @override
  State<NewAppointmentPage> createState() => _NewAppointmentPageState();
}

class _NewAppointmentPageState extends State<NewAppointmentPage> {
  late Future<List<ClientItem>> _clients;
  late Future<List<ServiceItem>> _services;
  late Future<List<ManagedUserItem>> _professionals;
  ClientItem? _client;
  ServiceItem? _service;
  String? _professionalId;
  int _duration = 30;
  late TimeOfDay _time;
  bool _walkIn = false;
  bool _saving = false;
  final _walkName = TextEditingController();
  final _walkPhone = TextEditingController();
  final _notes = TextEditingController();

  bool get _isAdmin =>
      widget.session.profile.toUpperCase() == 'ADMIN' || widget.session.isOwner;
  String get _activeProfessionalId =>
      _professionalId ?? widget.session.userId;

  @override
  void initState() {
    super.initState();
    _professionalId = widget.initialProfessionalId ?? widget.session.userId;
    _time = TimeOfDay(hour: widget.initialHour ?? DateTime.now().hour, minute: 0);
    _clients = widget.apiClient.clients(widget.session.groupId);
    _services = widget.apiClient.services(widget.session.groupId);
    _professionals = widget.apiClient.professionals();
  }

  @override
  void dispose() {
    _walkName.dispose();
    _walkPhone.dispose();
    _notes.dispose();
    super.dispose();
  }

  DateTime get _start {
    final d = widget.day ?? DateTime.now();
    return DateTime(d.year, d.month, d.day, _time.hour, _time.minute);
  }

  Future<bool> _canFitIn() async {
    if (_isAdmin) return true;
    if (_activeProfessionalId != widget.session.userId) return false;
    try {
      final me = await widget.apiClient.me();
      final raw = me['permissions'];
      return raw is List &&
          raw.map((e) => e.toString().toUpperCase()).contains('ALLOW_FIT_IN');
    } catch (_) {
      return false;
    }
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _time);
    if (t != null) setState(() => _time = t);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Novo agendamento')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (_isAdmin) ...[
                const Text('Profissional', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                FutureBuilder<List<ManagedUserItem>>(
                  future: _professionals,
                  builder: (context, s) => DropdownButtonFormField<String>(
                    initialValue: _professionalId,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.badge_outlined),
                      labelText: 'Profissional',
                    ),
                    items: (s.data ?? [])
                        .map((p) => DropdownMenuItem(value: p.id, child: Text(p.name)))
                        .toList(),
                    onChanged: (v) => setState(() => _professionalId = v),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              const Text('1. Cliente', style: TextStyle(fontWeight: FontWeight.w700)),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Cliente sem cadastro / avulso'),
                subtitle: const Text('Informe nome e telefone para este atendimento'),
                value: _walkIn,
                onChanged: (v) => setState(() => _walkIn = v),
              ),
              if (_walkIn) ...[
                TextField(
                  controller: _walkName,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.person_outline),
                    labelText: 'Nome',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _walkPhone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.phone_outlined),
                    labelText: 'Telefone / WhatsApp',
                  ),
                ),
              ] else
                FutureBuilder<List<ClientItem>>(
                  future: _clients,
                  builder: (context, s) => DropdownButtonFormField<ClientItem>(
                    initialValue: _client,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.person_outline),
                      labelText: 'Cliente cadastrado',
                    ),
                    items: (s.data ?? [])
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text('${c.name} • ${c.phone}'),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _client = v),
                  ),
                ),
              const SizedBox(height: 20),
              const Text('2. Serviço', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              FutureBuilder<List<ServiceItem>>(
                future: _services,
                builder: (context, s) => DropdownButtonFormField<ServiceItem>(
                  initialValue: _service,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.content_cut_rounded),
                    labelText: 'Serviço',
                  ),
                  items: (s.data ?? [])
                      .map((x) => DropdownMenuItem(
                            value: x,
                            child: Text('${x.name} • ${x.durationMinutes} min'),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() {
                    _service = v;
                    if (v != null) _duration = v.durationMinutes;
                  }),
                ),
              ),
              const SizedBox(height: 20),
              const Text('3. Horário', style: TextStyle(fontWeight: FontWeight.w700)),
              ListTile(
                contentPadding: EdgeInsets.zero,
                onTap: _pickTime,
                leading: const Icon(Icons.schedule_rounded),
                title: Text(
                  '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
                ),
                subtitle: Text('Duração prevista: $_duration min • toque para alterar'),
              ),
              Wrap(
                spacing: 8,
                children: [20, 30, 40, 60]
                    .map((m) => ChoiceChip(
                          label: Text('$m min'),
                          selected: _duration == m,
                          onSelected: (_) => setState(() => _duration = m),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _notes,
                maxLines: 3,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.notes_rounded),
                  labelText: 'Observações',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('Confirmar agendamento'),
                ),
              ),
            ],
          ),
        ),
      );

  Future<void> _save() async {
    if (_service == null ||
        (!_walkIn && _client == null) ||
        (_walkIn && _walkName.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe cliente e serviço.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final availability = await widget.apiClient.appointmentAvailability(
        professionalUserId: _activeProfessionalId,
        startsAt: _start,
        endsAt: _start.add(Duration(minutes: _duration)),
      );
      var force = false;
      if (!availability.available) {
        if (!await _canFitIn()) {
          if (mounted) {
            await showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Conflito de agenda'),
                content: const Text(
                  'Este profissional já possui atendimento neste período. Escolha outro horário.',
                ),
                actions: [
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Entendi'),
                  ),
                ],
              ),
            );
          }
          return;
        }
        if (!mounted) return;
        force = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Criar como encaixe?'),
                content: Text(
                  'Existe conflito com ${availability.conflicts.length} atendimento(s). O encaixe pode gerar atraso nos próximos horários.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Voltar'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Confirmar encaixe'),
                  ),
                ],
              ),
            ) ??
            false;
        if (!force) return;
      }
      await widget.apiClient.createAppointment(
        groupId: widget.session.groupId,
        professionalUserId: _activeProfessionalId,
        createdByUserId: widget.session.userId,
        clientId: _walkIn ? null : _client!.id,
        walkInName: _walkIn ? _walkName.text.trim() : null,
        walkInPhone: _walkIn ? _walkPhone.text.trim() : null,
        serviceId: _service!.id,
        startsAt: _start,
        durationMinutes: _duration,
        isFitIn: force,
        forceConflict: force,
        notes: _notes.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível salvar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
