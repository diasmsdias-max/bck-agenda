import 'package:flutter/material.dart';
import '../../core/api/bck_api_client.dart';

class ClientsPage extends StatefulWidget {
  const ClientsPage({super.key, required this.apiClient});
  final BckApiClient apiClient;
  @override State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {
  final _search = TextEditingController();
  bool _loading = true;
  String? _error;
  List<ClientItem> _clients = const [];

  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _search.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final items = await widget.apiClient.clients('', query: _search.text.trim());
      if (mounted) setState(() => _clients = items);
    } catch (_) {
      if (mounted) setState(() => _error = 'Não foi possível carregar os clientes.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override Widget build(BuildContext context) => SafeArea(child: Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(20,20,20,12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Clientes', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 14),
      TextField(controller: _search, textInputAction: TextInputAction.search, onSubmitted: (_) => _load(), decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: 'Pesquisar por nome ou telefone', suffixIcon: IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)))),
    ])),
    Expanded(child: _body()),
  ]));

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!), const SizedBox(height: 12), FilledButton(onPressed: _load, child: const Text('Tentar novamente'))])));
    if (_clients.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.people_outline_rounded, size: 52), SizedBox(height: 12), Text('Nenhum cliente encontrado', style: TextStyle(fontWeight: FontWeight.w700)), SizedBox(height: 6), Text('Cadastre um cliente ou altere a pesquisa.')])));
    return RefreshIndicator(onRefresh: _load, child: ListView.separated(padding: const EdgeInsets.fromLTRB(16,4,16,100), itemCount: _clients.length, separatorBuilder: (_,__) => const SizedBox(height: 4), itemBuilder: (_,i) { final c = _clients[i]; return Card(child: ListTile(leading: CircleAvatar(child: Text(c.name.isEmpty ? '?' : c.name[0].toUpperCase())), title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)), subtitle: Text(c.phone), trailing: const Icon(Icons.chevron_right_rounded))); }));
  }
}
