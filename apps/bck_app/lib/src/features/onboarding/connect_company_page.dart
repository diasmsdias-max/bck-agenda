import 'package:flutter/material.dart';

import '../../core/api/bck_api_client.dart';
import '../../core/auth/session_store.dart';
import '../../core/device/device_identity_store.dart';
import '../../core/device/pending_pairing_store.dart';
import '../../core/theme/theme_controller.dart';
import '../home/home_shell.dart';

class ConnectCompanyPage extends StatefulWidget {
  const ConnectCompanyPage({
    super.key,
    required this.apiClient,
    required this.themeController,
  });

  final BckApiClient apiClient;
  final ThemeController themeController;

  @override
  State<ConnectCompanyPage> createState() => _ConnectCompanyPageState();
}

class _ConnectCompanyPageState extends State<ConnectCompanyPage> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _user = TextEditingController();
  final _password = TextEditingController();
  final _deviceName = TextEditingController(text: 'Meu aparelho');
  final _sessionStore = SessionStore();
  final _deviceIdentityStore = DeviceIdentityStore();
  final _pendingPairingStore = PendingPairingStore();
  bool _busy = false;
  bool _loadingPairingState = true;
  PendingPairing? _pendingPairing;

  @override
  void initState() {
    super.initState();
    _loadPairingState();
  }

  Future<void> _loadPairingState() async {
    final deviceId = await _deviceIdentityStore.getOrCreateDeviceId();
    final pending = await _pendingPairingStore.read();
    if (!mounted) return;
    setState(() {
      _pendingPairing = pending?.deviceId == deviceId ? pending : null;
      _loadingPairingState = false;
    });
  }

  Future<void> _useAnotherCode() async {
    await _pendingPairingStore.clear();
    if (!mounted) return;
    setState(() => _pendingPairing = null);
  }

  @override
  void dispose() {
    _code.dispose();
    _user.dispose();
    _password.dispose();
    _deviceName.dispose();
    super.dispose();
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Campo obrigatório.' : null;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final deviceId = await _deviceIdentityStore.getOrCreateDeviceId();
      final pending = await _pendingPairingStore.read();
      late final String groupId;

      if (pending != null && pending.deviceId == deviceId) {
        groupId = pending.groupId;
      } else {
        if (pending != null) await _pendingPairingStore.clear();
        final paired = await widget.apiClient.pairDevice(
          pairingCode: _code.text.trim().toUpperCase(),
          deviceId: deviceId,
          deviceName: _deviceName.text.trim(),
          username: _user.text.trim(),
          password: _password.text,
        );
        groupId = paired.groupId;
        await _pendingPairingStore.save(groupId: groupId, deviceId: deviceId);
      }

      final session = await widget.apiClient.login(
        groupId: groupId,
        username: _user.text.trim(),
        password: _password.text,
        deviceId: deviceId,
      );
      await _sessionStore.save(session);
      await _pendingPairingStore.clear();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => HomeShell(
            session: StoredSession(
              groupId: session.groupId,
              userId: session.userId,
              deviceId: session.deviceId,
              name: session.name,
              profile: session.profile,
              isOwner: session.isOwner,
              accessToken: session.accessToken,
              accessTokenExpiresAt: session.accessTokenExpiresAt,
              refreshToken: session.refreshToken,
              refreshTokenExpiresAt: session.refreshTokenExpiresAt,
              offlineLeaseExpiresAt: session.offlineLeaseExpiresAt,
              serverTimeUtc: session.serverTimeUtc,
              validatedAt: session.validatedAt,
              localValidatedAt: DateTime.now().toUtc(),
            ),
            offline: false,
            apiClient: widget.apiClient,
            themeController: widget.themeController,
          ),
        ),
        (_) => false,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível concluir a conexão. Verifique usuário, senha e conexão e tente novamente.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingPairingState) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final recovering = _pendingPairing != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Conectar à empresa')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                recovering ? 'Concluir conexão' : 'Empresa existente',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                recovering
                    ? 'Este aparelho já foi autorizado. Entre com seu usuário e senha para concluir a conexão.'
                    : 'Peça ao Administrador da empresa um código de conexão. O código é temporário e só pode ser usado uma vez.',
              ),
              const SizedBox(height: 24),
              if (!recovering) ...[
                TextFormField(
                  controller: _code,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Código de conexão',
                    prefixIcon: Icon(Icons.key),
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _deviceName,
                  decoration: const InputDecoration(
                    labelText: 'Nome deste aparelho',
                    prefixIcon: Icon(Icons.phone_android),
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _user,
                decoration: const InputDecoration(
                  labelText: 'Seu usuário',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Sua senha',
                  prefixIcon: Icon(Icons.lock),
                ),
                validator: _required,
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    _busy
                        ? 'Conectando...'
                        : recovering
                            ? 'Concluir conexão'
                            : 'Conectar a esta empresa',
                  ),
                ),
              ),
              if (recovering) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _busy ? null : _useAnotherCode,
                  child: const Text('Usar outro código'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
