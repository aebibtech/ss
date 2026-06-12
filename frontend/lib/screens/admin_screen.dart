import 'package:flutter/material.dart';
import '../widgets/dashboard_layout.dart';
import '../widgets/session_guard.dart';
import '../services/auth_service.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  Map<String, dynamic>? _adminStats;
  bool _loadingAdminStats = false;
  late AuthService _authService;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _fetchAdminStats();
  }

  Future<void> _fetchAdminStats() async {
    setState(() => _loadingAdminStats = true);
    final stats = await _authService.getAdminStats();
    if (mounted) {
      setState(() {
        _adminStats = stats;
        _loadingAdminStats = false;
      });
    }
  }

  Widget _buildAdminTab(bool isMobile) {
    final totalUsers = _adminStats?['totalUsers']?.toString() ?? (_loadingAdminStats ? '...' : '0');
    final activeSessions = _adminStats?['activeSessions']?.toString() ?? (_loadingAdminStats ? '...' : '0');
    final totalOrgs = _adminStats?['totalOrganizations']?.toString() ?? (_loadingAdminStats ? '...' : '0');

    final statCards = [
      _buildStatCard('Total Users', totalUsers, Icons.people_outline, Colors.blue),
      _buildStatCard('Active Sessions', activeSessions, Icons.flash_on_outlined, Colors.orange),
      _buildStatCard('Total Orgs', totalOrgs, Icons.group_work_outlined, Colors.purple),
    ];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Admin Control Panel',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'This panel is only visible to users with the admin role in the system.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          if (isMobile)
            Column(
              children: statCards.map((card) => Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: card,
              )).toList(),
            )
          else
            Row(
              children: statCards.map((card) => Expanded(child: card)).toList(),
            ),
          const SizedBox(height: 32),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Quick Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.person_add_alt_1_outlined, size: 16),
                        label: const Text('Invite User'),
                        onPressed: () {},
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.security_outlined, size: 16),
                        label: const Text('Audit Logs'),
                        onPressed: () {},
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.settings_outlined, size: 16),
                        label: const Text('System Settings'),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 14, color: Colors.grey.shade400)),
                const SizedBox(height: 8),
                Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              ],
            ),
            CircleAvatar(
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, color: color),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SessionGuard(
      requireAdmin: true,
      builder: (context, session, authService) {
        final isMobile = MediaQuery.of(context).size.width < 600;
        return DashboardLayout(
          selectedTab: 3,
          authService: authService,
          session: session,
          child: _buildAdminTab(isMobile),
        );
      },
    );
  }
}
