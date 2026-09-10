import 'package:flutter/material.dart';

import '../../core/api/bck_api_client.dart';
import '../../core/auth/session_store.dart';
import '../onboarding/welcome_page.dart';

class SessionGate extends StatefulWidget {
  const SessionGate({super.key, required this.apiClient});
  final BckApiClient apiClient;

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  final SessionStore _store = SessionStore();
  late final Future<Widget> _destination = _resolve();

  Future<Widget> _resolve() async {
    final session = await _store.read();
    if (session == null) return WelcomePage(apiClient: widget.apiClient);

    final now = DateTime.now().toUtc();
    if (now.isBefore(session.accessTokenExpiresAt.toUtc())) {
      return _SessionReadyPage(session: session, mode: 'Online');
    }

    if (now.isBefore(session.refreshTokenExpiresAt.toUtc())) {
      try {
        final refreshed = await widget.apiClient.refresh(session.refreshToken);
        await _store.updateTokens(
          accessToken: refreshed.accessToken,
          accessTokenExpiresAt: refreshed.accessTokenExpiresAt,
          refreshToken: refreshed.refreshToken,
          refreshTokenExpiresAt: refreshed.refreshTokenExpiresAt,
          offlineLeaseExpiresAt: refreshed.offlineLeaseExpiresAt,
        );
        final updated = await _store.read();
        if (updated != null) return _SessionReadyPage(session: updated, mode: 'Online');
      } catch (_) {
        if (session.canOperateOffline) return _SessionReadyPage(session: session, mode: 'Offline');
      }
    }

    if (session.canOperateOffline) return _SessionReadyPage(session: session, mode: 'Offline');
    await _store.clear();
    return WelcomePage(apiClient: widget.apiClient);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Widget>(
        future: _destination,
        builder: (context, snapshot) {
          if (snapshot.hasData) return snapshot.data!;
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        },
      );
}

class _SessionReadyPage extends StatelessWidget {
  const _SessionReadyPage({required this.session, required this.mode});
  final StoredSession session;
  final String mode;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                const Icon(Icons.calendar_month_rounded, size: 64, color: Color(0xFFD6A84B)),
                const SizedBox(height: 20),
                Text('Olá, ${session.name}', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('Sessão restaurada • $mode', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                if (mode == 'Offline') ...[
                  const SizedBox(height: 16),
                  const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Sem conexão. O BCK Agenda continuará disponível dentro da autorização offline vigente.', textAlign: TextAlign.center))),
                ],
                const Spacer(),
                const Text('A próxima etapa conectará esta sessão à tela Início.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)),
              ],
            ),
          ),
        ),
      );
}
