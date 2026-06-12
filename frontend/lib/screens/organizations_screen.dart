import 'package:flutter/material.dart';
import '../widgets/dashboard_layout.dart';
import '../widgets/session_guard.dart';
import '../services/auth_service.dart';

class OrganizationsScreen extends StatefulWidget {
  const OrganizationsScreen({super.key});

  @override
  State<OrganizationsScreen> createState() => _OrganizationsScreenState();
}

class _OrganizationsScreenState extends State<OrganizationsScreen> {
  List<dynamic> _organizations = [];
  bool _loadingOrgs = false;
  late AuthService _authService;

  final _orgNameController = TextEditingController();
  final _orgSlugController = TextEditingController();
  final _orgFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _fetchOrganizations();
  }

  @override
  void dispose() {
    _orgNameController.dispose();
    _orgSlugController.dispose();
    super.dispose();
  }

  Future<void> _fetchOrganizations() async {
    setState(() => _loadingOrgs = true);
    final orgs = await _authService.listOrganizations();
    if (mounted) {
      setState(() {
        _organizations = orgs;
        _loadingOrgs = false;
      });
    }
  }

  Future<void> _createOrg() async {
    if (!_orgFormKey.currentState!.validate()) return;

    final created = await _authService.createOrganization(
      _orgNameController.text.trim(),
      _orgSlugController.text.trim(),
    );

    if (created != null) {
      _orgNameController.clear();
      _orgSlugController.clear();
      _fetchOrganizations();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Organization created successfully!')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create organization.')),
        );
      }
    }
  }

  Widget _buildOrgsTab(bool isMobile) {
    final listWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Your Organizations',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchOrganizations,
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_loadingOrgs)
          const Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent))
        else if (_organizations.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.group_work_outlined, size: 48, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('No organizations found', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _organizations.length,
            itemBuilder: (context, index) {
              final org = _organizations[index];
              final orgData = org['organization'] ?? org;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Builder(
                    builder: (context) {
                      final orgName = orgData['name'] as String? ?? '';
                      final orgInitial = orgName.isNotEmpty ? orgName[0].toUpperCase() : 'O';
                      return CircleAvatar(
                        backgroundColor: Colors.deepPurple.shade900,
                        child: Text(orgInitial),
                      );
                    }
                  ),
                  title: Text(orgData['name'] as String? ?? 'Unnamed', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Slug: ${orgData['slug'] ?? ''}'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.deepPurpleAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      org['role'] ?? 'Member',
                      style: const TextStyle(fontSize: 12, color: Colors.deepPurpleAccent),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );

    final formWidget = Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _orgFormKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create Organization',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _orgNameController,
                decoration: const InputDecoration(
                  labelText: 'Organization Name',
                  prefixIcon: Icon(Icons.business_outlined),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _orgSlugController,
                decoration: const InputDecoration(
                  labelText: 'Organization Slug',
                  prefixIcon: Icon(Icons.link_outlined),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a slug';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _createOrg,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurpleAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Create Org', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (isMobile) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            formWidget,
            const SizedBox(height: 24),
            listWidget,
          ],
        ),
      );
    } else {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              child: listWidget,
            ),
          ),
          const SizedBox(width: 32),
          Expanded(
            child: SingleChildScrollView(
              child: formWidget,
            ),
          ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SessionGuard(
      builder: (context, session, authService) {
        final isMobile = MediaQuery.of(context).size.width < 600;
        return DashboardLayout(
          selectedTab: 2,
          authService: authService,
          session: session,
          child: _buildOrgsTab(isMobile),
        );
      },
    );
  }
}
