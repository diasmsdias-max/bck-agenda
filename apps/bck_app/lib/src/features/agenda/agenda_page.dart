import 'package:flutter/material.dart';

class AgendaPage extends StatefulWidget {
  const AgendaPage({super.key, required this.isAdmin});
  final bool isAdmin;

  @override
  State<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends State<AgendaPage> {
  int _view = 0;
  String _scope = 'Minha';
  DateTime _selectedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              children: [
                Expanded(child: Text('Agenda', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700))),
                IconButton(onPressed: _pickDate, icon: const Icon(Icons.calendar_today_rounded)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Hoje')),
                ButtonSegment(value: 1, label: Text('Semana')),
                ButtonSegment(value: 2, label: Text('Mês')),
              ],
              selected: {_view},
              onSelectionChanged: (value) => setState(() => _view = value.first),
            ),
          ),
          if (widget.isAdmin) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                const Text('Visualizar:'),
                const SizedBox(width: 12),
                DropdownButton<String>(value: _scope, items: const [DropdownMenuItem(value: 'Minha', child: Text('Minha agenda')), DropdownMenuItem(value: 'Todos', child: Text('Todos'))], onChanged: (value) => setState(() => _scope = value ?? 'Minha')),
              ]),
            ),
          ],
          const SizedBox(height: 12),
          _DateHeader(day: _selectedDay),
          const Divider(height: 1),
          Expanded(child: _view == 0 ? const _TodayTimeline() : _EmptyPeriod(view: _view)),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(context: context, initialDate: _selectedDay, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (selected != null) setState(() => _selectedDay = selected);
  }
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.day});
  final DateTime day;
  @override
  Widget build(BuildContext context) {
    const months = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), child: Row(children: [const Icon(Icons.today_rounded, color: Color(0xFFD6A84B)), const SizedBox(width: 10), Text('${day.day} ${months[day.month - 1]} ${day.year}', style: const TextStyle(fontWeight: FontWeight.w700))]));
  }
}

class _TodayTimeline extends StatelessWidget {
  const _TodayTimeline();
  @override
  Widget build(BuildContext context) {
    final hours = List<int>.generate(11, (index) => index + 8);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
      itemCount: hours.length,
      itemBuilder: (context, index) {
        final hour = hours[index];
        return SizedBox(
          height: 72,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 52, child: Padding(padding: const EdgeInsets.only(top: 10), child: Text('${hour.toString().padLeft(2, '0')}:00', style: const TextStyle(color: Colors.white60)))),
            Expanded(child: InkWell(onTap: () => _newAppointment(context, hour), borderRadius: BorderRadius.circular(12), child: Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 14), decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)), child: const Row(children: [Icon(Icons.add_rounded, size: 18, color: Colors.white38), SizedBox(width: 8), Text('Horário disponível', style: TextStyle(color: Colors.white38))])))),
          ]),
        );
      },
    );
  }

  void _newAppointment(BuildContext context, int hour) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => NewAppointmentPage(initialHour: hour)));
  }
}

class _EmptyPeriod extends StatelessWidget {
  const _EmptyPeriod({required this.view});
  final int view;
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.calendar_view_week_rounded, size: 52, color: Color(0xFFD6A84B)), const SizedBox(height: 12), Text(view == 1 ? 'Visão semanal' : 'Visão mensal', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)), const SizedBox(height: 6), const Text('Estrutura pronta para receber os agendamentos.', style: TextStyle(color: Colors.white60))]));
}

class NewAppointmentPage extends StatefulWidget {
  const NewAppointmentPage({super.key, this.initialHour});
  final int? initialHour;
  @override
  State<NewAppointmentPage> createState() => _NewAppointmentPageState();
}

class _NewAppointmentPageState extends State<NewAppointmentPage> {
  final _client = TextEditingController();
  final _service = TextEditingController();
  int _duration = 30;

  @override
  void dispose() { _client.dispose(); _service.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Novo agendamento')), body: SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: [
    const Text('1. Cliente', style: TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 8), TextField(controller: _client, decoration: const InputDecoration(labelText: 'Cliente ou encaixe sem cadastro', prefixIcon: Icon(Icons.person_outline))),
    const SizedBox(height: 20), const Text('2. Serviço', style: TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 8), TextField(controller: _service, decoration: const InputDecoration(labelText: 'Serviço', prefixIcon: Icon(Icons.content_cut_rounded))),
    const SizedBox(height: 20), const Text('3. Horário', style: TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 8), ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.schedule_rounded), title: Text(widget.initialHour == null ? 'Escolher horário' : '${widget.initialHour.toString().padLeft(2, '0')}:00'), subtitle: Text('Duração prevista: $_duration min')),
    Wrap(spacing: 8, children: [20, 30, 40, 60].map((minutes) => ChoiceChip(label: Text('$minutes min'), selected: _duration == minutes, onSelected: (_) => setState(() => _duration = minutes))).toList()),
    const SizedBox(height: 24), Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [const Icon(Icons.auto_awesome_rounded, color: Color(0xFFD6A84B)), const SizedBox(width: 12), Expanded(child: Text('O BCK Agenda poderá sugerir uma duração inteligente após reunir histórico suficiente deste cliente e serviço.', style: Theme.of(context).textTheme.bodyMedium))]))),
    const SizedBox(height: 24), FilledButton.icon(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.check_rounded), label: const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Text('Confirmar agendamento'))),
  ])));
}
