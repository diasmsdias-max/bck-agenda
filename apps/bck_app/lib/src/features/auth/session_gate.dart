import 'package:flutter/material.dart';

import '../../core/api/bck_api_client.dart';
import '../../core/auth/session_store.dart';
import '../home/home_shell.dart';
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

    final now = session.estimatedServerNow();
    if (now.isBefore(session.accessTokenExpiresAt.toUtc())) {
      widget.apiClient.setAccessToken(session.accessToken);
      return HomeShell(session: session, offline: false, apiClient: widget.apiClient);
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
          serverTimeUtc: refreshed.serverTimeUtc,
          validatedAt: refreshed.validatedAt,
        );
        final updated = await _store.read();
        if (updated != null) {
          widget.apiClient.setAccessToken(updated.accessToken);
          return HomeShell(session: updated, offline: false, apiClient: widget.apiClient);
        }
      } catch (_) {
        if (session.canOperateOffline) {
          widget.apiClient.setAccessToken(null);
          return HomeShell(session: session, offline: true, apiClient: widget.apiClient);
        }
      }
    }

    if (session.canOperateOffline) {
      widget.apiClient.setAccessToken(null);
      return HomeShell(session: session, offline: true, apiClient: widget.apiClient);
    }
    widget.apiClient.setAccessToken(null);
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
