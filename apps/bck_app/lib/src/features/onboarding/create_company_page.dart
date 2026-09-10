import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/api/bck_api_client.dart';

class CreateCompanyPage extends StatefulWidget {
  const CreateCompanyPage({super.key, required this.apiClient});
  final BckApiClient apiClient;

  @override
  State<CreateCompanyPage> createState() => _CreateCompanyPageState();
}

class _CreateCompanyPageState extends State<CreateCompanyPage> {
  final _formKey = GlobalKey<FormState>();
  final _company = TextEditingController();
  final _phone = TextEditingController();
  final _owner = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _company.dispose(); _phone.dispose(); _owner.dispose(); _username.dispose(); _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final deviceId = const Uuid().v4();
      final created = await widget.apiClient.createCompany(BootstrapCompanyRequest(
        companyName: _company.text.trim(), companyPhone: _phone.text.trim().isEmpty ? null : _phone.text.trim(), ownerName: _owner.text.trim(), ownerUsername: _username.text.trim(), password: _password.text, deviceId: deviceId, deviceName: 'Aparelho principal', platform: 'ANDROID', deviceMode: 'PERSONAL'));
      final session = await widget.apiClient.login(groupId: created.groupId, username: _username.text.trim(), password: _password.text, deviceId: deviceId);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => _CreatedPage(companyName: created.companyName, ownerName: session.name)), (_) => false);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível criar a empresa. Verifique a conexão e os dados informados.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Criar minha empresa')),
      body: SafeArea(child: Form(key: _formKey, child: ListView(padding: const EdgeInsets.all(24), children: [
        Text('Primeiro acesso', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text('Cadastre a empresa e o primeiro Administrador/Proprietário.'),
        const SizedBox(height: 24),
        TextFormField(controller: _company, decoration: const InputDecoration(labelText: 'Nome da empresa', prefixIcon: Icon(Icons.storefront)), validator: _required),
        const SizedBox(height: 12),
        TextFormField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Telefone da empresa (opcional)', prefixIcon: Icon(Icons.phone))),
        const SizedBox(height: 12),
        TextFormField(controller: _owner, decoration: const InputDecoration(labelText: 'Seu nome', prefixIcon: Icon(Icons.person)), validator: _required),
        const SizedBox(height: 12),
        TextFormField(controller: _username, decoration: const InputDecoration(labelText: 'Usuário', prefixIcon: Icon(Icons.account_circle)), validator: _required),
        const SizedBox(height: 12),
        TextFormField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Senha', prefixIcon: Icon(Icons.lock)), validator: (v) => (v ?? '').length < 8 ? 'Use pelo menos 8 caracteres.' : null),
        const SizedBox(height: 28),
        FilledButton(onPressed: _busy ? null : _submit, child: Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text(_busy ? 'Criando...' : 'Criar empresa e continuar'))),
      ]))),
    );
  }

  String? _required(String? value) => value == null || value.trim().isEmpty ? 'Campo obrigatório.' : null;
}

class _CreatedPage extends StatelessWidget {
  const _CreatedPage({required this.companyName, required this.ownerName});
  final String companyName;
  final String ownerName;
  @override
  Widget build(BuildContext context) => Scaffold(body: SafeArea(child: Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.check_circle_rounded, size: 72, color: Color(0xFFD6A84B)), const SizedBox(height: 20),
    Text('Empresa criada', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)), const SizedBox(height: 12),
    Text('$companyName está conectado.\nBem-vindo, $ownerName.', textAlign: TextAlign.center), const SizedBox(height: 20),
    const Text('A próxima etapa conectará esta sessão à tela inicial do BCK Agenda.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
  ])))));
}
