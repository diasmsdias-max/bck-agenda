import 'package:flutter/material.dart';

import '../../core/api/bck_api_client.dart';
import '../../core/auth/session_store.dart';
import 'agenda_models.dart';

class AgendaPage extends StatefulWidget {
  const AgendaPage({super.key, required this.session, required this.apiClient});
  final StoredSession session;
  final BckApiClient apiClient;

  @override
  State<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends State<AgendaPage> {
  DateTime _day = DateTime.now();
  AgendaViewMode _mode = AgendaViewMode.day;
  late Future<List<AppointmentItem>> _items;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final range = _rangeFor(_day, _mode);
    _items = widget.apiClient.appointments(
      groupId: widget.session.groupId,
      professionalUserId: widget.session.userId,
      from: range.$1,
      to: range.$2,
    );
  }

  (DateTime, DateTime) _rangeFor(DateTime day, AgendaViewMode mode) {
    final base = DateTime(day.year, day.month, day.day);
    switch (mode) {
      case AgendaViewMode.day:
        return (base, base.add(const Duration(days: 1)));
      case AgendaViewMode.week:
        final monday = base.subtract(Duration(days: base.weekday - 1));
        return (monday, monday.add(const Duration(days: 7)));
      case AgendaViewMode.month:
        final first = DateTime(base.year, base.month, 1);
        return (first, DateTime(base.year, base.month + 1, 1));
    }
  }

  Future<void> _pick() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (selected != null) {
      setState(() {
        _day = selected;
        _reload();
      });
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Agenda',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(onPressed: _pick, icon: const Icon(Icons.calendar_today_rounded)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SegmentedButton<AgendaViewMode>(
                segments: const [
                  ButtonSegment(value: AgendaViewMode.day, label: Text('Dia')),
                  ButtonSegment(value: AgendaViewMode.week, label: Text('Semana')),
                  ButtonSegment(value: AgendaViewMode.month, label: Text('Mês')),
                ],
                selected: {_mode},
                onSelectionChanged: (value) => setState(() {
                  _mode = value.first;
                  _reload();
                }),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
              child: Row(
                children: [
                  Icon(Icons.today_rounded, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 10),
                  Text(_rangeLabel(), style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<AppointmentItem>>(
                future: _items,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Não foi possível carregar a agenda.\n${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  final items = snapshot.data ?? [];
                  return RefreshIndicator(
                    onRefresh: () async => setState(_reload),
                    child: _mode == AgendaViewMode.day
                        ? _dayView(items)
                        : _periodView(items),
                  );
                },
              ),
            ),
          ],
        ),
      );

  String _rangeLabel() {
    final range = _rangeFor(_day, _mode);
    String date(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    if (_mode == AgendaViewMode.day) return date(_day);
    return '${date(range.$1)} — ${date(range.$2.subtract(const Duration(days: 1)))}';
  }

  Widget _dayView(List<AppointmentItem> items) => ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
        itemCount: 11,
        itemBuilder: (context, index) {
          final hour = index + 8;
          final atHour = items.where((a) => a.startsAt.toLocal().hour == hour).toList();
          return SizedBox(
            height: 76,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 52,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      '${hour.toString().padLeft(2, '0')}:00',
                      style: const TextStyle(color: Colors.white60),
                    ),
                  ),
                ),
                Expanded(
                  child: atHour.isEmpty
                      ? _FreeSlot(onTap: () => _openNew(hour))
                      : _AppointmentCard(item: atHour.first),
                ),
              ],
            ),
          );
        },
      );

  Widget _periodView(List<AppointmentItem> items) {
    final sorted = [...items]..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    if (sorted.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          SizedBox(height: 80),
          Icon(Icons.event_available_rounded, size: 48, color: Colors.white38),
          SizedBox(height: 12),
          Center(child: Text('Nenhum agendamento neste período.')),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
      itemCount: sorted.length,
      itemBuilder: (context, index) => _AppointmentCard(
        item: sorted[index],
        showDate: true,
      ),
    );
  }

  Future<void> _openNew(int hour) async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => NewAppointmentPage(
          session: widget.session,
          apiClient: widget.apiClient,
          day: _day,
          initialHour: hour,
        ),
      ),
    );
    if (created == true && mounted) setState(_reload);
  }
}

class _FreeSlot extends StatelessWidget {
  const _FreeSlot({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: const Row(
            children: [
              Icon(Icons.add_rounded, size: 18, color: Colors.white38),
              SizedBox(width: 8),
              Text('Horário disponível', style: TextStyle(color: Colors.white38)),
            ],
          ),
        ),
      );
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({required this.item, this.showDate = false});
  final AppointmentItem item;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final status = AgendaStatus.fromApi(item.status);
    final color = AgendaPalette.forStatus(status);
    final start = item.startsAt.toLocal();
    final end = item.endsAt.toLocal();
    final datePrefix = showDate ? '${start.day.toString().padLeft(2, '0')}/${start.month.toString().padLeft(2, '0')} • ' : '';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        leading: Icon(status.icon, color: color),
        title: Text(item.clientName, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('$datePrefix${_hm(start)}–${_hm(end)} • ${status.label}'),
        trailing: Container(width: 4, height: 36, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
      ),
    );
  }

  static String _hm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class NewAppointmentPage extends StatefulWidget {
  const NewAppointmentPage({super.key, required this.session, required this.apiClient, this.day, this.initialHour});
  final StoredSession session;
  final BckApiClient apiClient;
  final DateTime? day;
  final int? initialHour;

  @override
  State<NewAppointmentPage> createState() => _NewAppointmentPageState();
}

class _NewAppointmentPageState extends State<NewAppointmentPage> {
  late Future<List<ClientItem>> _clients;
  late Future<List<ServiceItem>> _services;
  ClientItem? _client;
  ServiceItem? _service;
  int _duration = 30;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _clients = widget.apiClient.clients(widget.session.groupId);
    _services = widget.apiClient.services(widget.session.groupId);
  }

  DateTime get _start {
    final d = widget.day ?? DateTime.now();
    return DateTime(d.year, d.month, d.day, widget.initialHour ?? DateTime.now().hour);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Novo agendamento')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text('1. Cliente', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              FutureBuilder<List<ClientItem>>(
                future: _clients,
                builder: (context, snapshot) => DropdownButtonFormField<ClientItem>(
                  initialValue: _client,
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.person_outline), labelText: 'Cliente'),
                  items: (snapshot.data ?? [])
                      .map((c) => DropdownMenuItem(value: c, child: Text('${c.name} • ${c.phone}')))
                      .toList(),
                  onChanged: (value) => setState(() => _client = value),
                ),
              ),
              const SizedBox(height: 20),
              const Text('2. Serviço', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              FutureBuilder<List<ServiceItem>>(
                future: _services,
                builder: (context, snapshot) => DropdownButtonFormField<ServiceItem>(
                  initialValue: _service,
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.content_cut_rounded), labelText: 'Serviço'),
                  items: (snapshot.data ?? [])
                      .map((x) => DropdownMenuItem(value: x, child: Text('${x.name} • ${x.durationMinutes} min')))
                      .toList(),
                  onChanged: (value) => setState(() {
                    _service = value;
                    if (value != null) _duration = value.durationMinutes;
                  }),
                ),
              ),
              const SizedBox(height: 20),
              const Text('3. Horário', style: TextStyle(fontWeight: FontWeight.w700)),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule_rounded),
                title: Text('${_start.hour.toString().padLeft(2, '0')}:00'),
                subtitle: Text('Duração prevista: $_duration min'),
              ),
              Wrap(
                spacing: 8,
                children: [20, 30, 40, 60]
                    .map((m) => ChoiceChip(label: Text('$m min'), selected: _duration == m, onSelected: (_) => setState(() => _duration = m)))
                    .toList(),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check_rounded),
                label: const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Text('Confirmar agendamento')),
              ),
            ],
          ),
        ),
      );

  Future<void> _save() async {
    if (_client == null || _service == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione cliente e serviço.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final end = _start.add(Duration(minutes: _duration));
      final available = await widget.apiClient.availability(
        groupId: widget.session.groupId,
        professionalUserId: widget.session.userId,
        startsAt: _start,
        endsAt: end,
      );
      if (!available) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Este horário possui conflito. Escolha outro horário.')));
        }
        return;
      }
      await widget.apiClient.createAppointment(
        groupId: widget.session.groupId,
        professionalUserId: widget.session.userId,
        createdByUserId: widget.session.userId,
        clientId: _client!.id,
        serviceId: _service!.id,
        startsAt: _start,
        durationMinutes: _duration,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível agendar: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
