import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class SessionGuard extends StatefulWidget {
  final Widget Function(BuildContext context, Map<String, dynamic> session, AuthService authService) builder;
  final bool requireAdmin;

  const SessionGuard({
    super.key,
    required this.builder,
    this.requireAdmin = false,
  });

  @override
  State<SessionGuard> createState() => _SessionGuardState();
}

class _SessionGuardState extends State<SessionGuard> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  Map<String, dynamic>? _session;

  @override
  void initState() {
    super.initState();
    _session = _authService.cachedSession;
    if (_session != null) {
      _isLoading = false;
    }
    _checkSession();
  }

  Future<void> _checkSession() async {
    final session = await _authService.getSession();
    if (!mounted) return;
    if (session == null) {
      Navigator.of(context).pushReplacementNamed('/');
      return;
    }

    if (widget.requireAdmin) {
      final user = session['user'];
      final userRole = user['role'] ?? 'user';
      if (userRole != 'admin') {
        Navigator.of(context).pushReplacementNamed('/counter');
        return;
      }
    }

    setState(() {
      _session = session;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _session == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Colors.deepPurpleAccent,
          ),
        ),
      );
    }
    return widget.builder(context, _session!, _authService);
  }
}
