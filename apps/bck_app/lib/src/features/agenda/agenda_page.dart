import 'package:flutter/material.dart';

import '../../core/api/bck_api_client.dart';
import '../../core/auth/session_store.dart';
import 'agenda_hours.dart';
import 'agenda_models.dart';
import 'agenda_scope.dart';
import 'agenda_service_session_bridge.dart';
import 'appointment_actions_sheet.dart';
import 'appointment_card.dart' as cards;
import 'new_appointment_page.dart';
import 'reschedule_appointment_page.dart';

class AgendaPage extends StatefulWidget {
  const AgendaPage({
    super.key,
    required this.session,
    required this.apiClient,
  });

  final StoredSession session;
  final BckApiClient apiClient;

  @override
  State<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends State<AgendaPage> {
  DateTime _day = DateTime.now();
  AgendaViewMode _mode = AgendaViewMode.day;
  late Future<List<AppointmentItem>> _items;
  late Future<List<ManagedUserItem>> _professionals;
  List<ManagedUserItem> _professionalCache = const [];
  String? _professionalId;

  bool get _isAdmin =>
      widget.session.profile.toUpperCase() == 'ADMIN' || widget.session.isOwner;
  String get _activeProfessionalId =>
      _professionalId ?? widget.session.userId;

  @override
  void initState() {
    super.initState();
    _professionalId = widget.session.userId;
    _professionals = widget.apiClient.professionals();
    _professionals.then((value) {
      _professionalCache = value;
      if (mounted && _professionalId == allProfessionalsAgendaScope) {
        setState(_reload);
      }
    });
    _reload();
  }

  void _reload() {
    final range = _rangeFor(_day, _mode);
    _items = loadAgendaScope(
      apiClient: widget.apiClient,
      groupId: widget.session.groupId,
      selectedProfessionalId: _activeProfessionalId,
      professionals: _professionalCache,
      from: range.$1,
      to: range.$2,
    );
  }

  (DateTime, DateTime) _rangeFor(DateTime date, AgendaViewMode mode) {
    final base = DateTime(date.year, date.month, date.day);
    switch (mode) {
      case AgendaViewMode.day:
        return (base, base.add(const Duration(days: 1)));
      case AgendaViewMode.week:
        final start = base.subtract(Duration(days: base.weekday - 1));
        return (start, start.add(const Duration(days: 7)));
      case AgendaViewMode.month:
        final start = DateTime(base.year, base.month, 1);
        return (start, DateTime(base.year, base.month + 1, 1));
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

  Future<void> _status(
    AppointmentItem item,
    String status, {
    String? reason,
  }) async {
    try {
      await widget.apiClient.changeAppointmentStatus(
        item.id,
        status,
        reason: reason,
      );
      if (mounted) setState(_reload);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não foi possível atualizar o atendimento: $error'),
          ),
        );
      }
    }
  }

  Future<void> _openActions(AppointmentItem item) async {
    final action = await showAppointmentActionsSheet(
      context,
      appointment: item,
    );
    if (action == null || !mounted) return;

    if (action == 'IN_SERVICE' || action == 'CONTINUE_SERVICE') {
      final changed = await openAgendaServiceSession(
        context,
        session: widget.session,
        appointment: item,
      );
      if (changed == true && mounted) setState(_reload);
      return;
    }

    if (action == 'RESCHEDULE') {
      final changed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => RescheduleAppointmentPage(
            session: widget.session,
            apiClient: widget.apiClient,
            appointment: item,
            professionalUserId: item.professionalUserId,
          ),
        ),
      );
      if (changed == true && mounted) setState(_reload);
      return;
    }

    if (action == 'CANCELLED' || action == 'NO_SHOW') {
      final reason = await _askReason(
        action == 'CANCELLED'
            ? 'Cancelar atendimento'
            : 'Registrar não comparecimento',
      );
      if (reason == null) return;
      await _status(item, action, reason: reason);
      return;
    }

    await _status(item, action);
  }

  Future<String?> _askReason(String title) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Motivo / observação'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
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
                IconButton(
                  onPressed: _pick,
                  icon: const Icon(Icons.calendar_today_rounded),
                ),
              ],
            ),
          ),
          if (_isAdmin)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: FutureBuilder<List<ManagedUserItem>>(
                future: _professionals,
                builder: (context, snapshot) {
                  final professionals = snapshot.data ?? [];
                  if (snapshot.hasData) _professionalCache = professionals;
                  return DropdownButtonFormField<String>(
                    initialValue: _professionalId,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.badge_outlined),
                      labelText: 'Visualizar agenda',
                    ),
                    items: [
                      DropdownMenuItem(
                        value: widget.session.userId,
                        child: Text('Minha agenda • ${widget.session.name}'),
                      ),
                      const DropdownMenuItem(
                        value: allProfessionalsAgendaScope,
                        child: Text('Todos • equipe completa'),
                      ),
                      ...professionals
                          .where((item) => item.id != widget.session.userId)
                          .map(
                            (item) => DropdownMenuItem(
                              value: item.id,
                              child: Text(item.name),
                            ),
                          ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _professionalId = value;
                          _reload();
                        });
                      }
                    },
                  );
                },
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
              onSelectionChanged: (value) {
                setState(() {
                  _mode = value.first;
                  _reload();
                });
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
            child: Row(
              children: [
                Icon(
                  Icons.today_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _rangeLabel(),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (_isAdmin)
                  Text(
                    agendaScopeLabel(
                      selectedProfessionalId: _activeProfessionalId,
                      currentUserId: widget.session.userId,
                      currentUserName: widget.session.name,
                      professionals: _professionalCache,
                    ),
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
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
  }

  String _rangeLabel() {
    final range = _rangeFor(_day, _mode);
    String format(DateTime date) =>
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
    return _mode == AgendaViewMode.day
        ? format(_day)
        : '${format(range.$1)} — '
            '${format(range.$2.subtract(const Duration(days: 1)))}';
  }

  Widget _dayView(List<AppointmentItem> items) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
      itemCount: agendaDayHours.length,
      itemBuilder: (context, index) {
        final hour = agendaDayHours[index];
        final appointments = items
            .where((item) => item.startsAt.toLocal().hour == hour)
            .toList()
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
        return Row(
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
              child: appointments.isEmpty
                  ? SizedBox(
                      height: 76,
                      child: _FreeSlot(onTap: () => _openNew(hour)),
                    )
                  : Column(
                      children: [
                        for (final appointment in appointments)
                          _AppointmentCard(
                            item: appointment,
                            onTap: () => _openActions(appointment),
                          ),
                        if (appointments.length > 1)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.layers_rounded,
                                  size: 16,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${appointments.length} atendimentos neste horário',
                                  style: Theme.of(context).textTheme.labelMedium,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _periodView(List<AppointmentItem> items) {
    final sorted = [...items]
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
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
        onTap: () => _openActions(sorted[index]),
      ),
    );
  }

  Future<void> _openNew(int hour) async {
    final initialProfessional =
        _activeProfessionalId == allProfessionalsAgendaScope
            ? widget.session.userId
            : _activeProfessionalId;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => NewAppointmentPage(
          session: widget.session,
          apiClient: widget.apiClient,
          day: _day,
          initialHour: hour,
          initialProfessionalId: initialProfessional,
        ),
      ),
    );
    if (changed == true && mounted) setState(_reload);
  }
}

class _FreeSlot extends StatelessWidget {
  const _FreeSlot({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
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
            Text(
              'Horário disponível',
              style: TextStyle(color: Colors.white38),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({
    required this.item,
    this.showDate = false,
    this.onTap,
  });

  final AppointmentItem item;
  final bool showDate;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => cards.AppointmentCard(
        item: item,
        showDate: showDate,
        onTap: onTap,
      );
}
