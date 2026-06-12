import 'package:flutter/material.dart';
import '../widgets/dashboard_layout.dart';
import '../widgets/session_guard.dart';
import '../services/auth_service.dart';
import 'organization_details_screen.dart';

class OrganizationsScreen extends StatefulWidget {
  const OrganizationsScreen({super.key});

  @override
  State<OrganizationsScreen> createState() => _OrganizationsScreenState();
}

class _OrganizationsScreenState extends State<OrganizationsScreen> {
  List<dynamic> _organizations = [];
  List<dynamic> _myPendingInvites = [];
  
  bool _loadingOrgs = false;
  bool _loadingMyInvites = false;
  bool _actionInProgress = false;

  String? _activeOrgId;
  late AuthService _authService;
  Map<String, dynamic>? _selectedOrg;

  final _orgNameController = TextEditingController();
  final _orgSlugController = TextEditingController();
  final _orgFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _fetchData();
    
    // Check if user clicked an invite link (URL contains query parameter `inviteId`)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUrlInvite();
    });
  }

  @override
  void dispose() {
    _orgNameController.dispose();
    _orgSlugController.dispose();
    super.dispose();
  }

  // Detect query parameters representing email invitations
  void _checkForUrlInvite() {
    final baseUri = Uri.base;
    String? inviteId = baseUri.queryParameters['inviteId'];
    if (inviteId == null && baseUri.fragment.isNotEmpty) {
      try {
        final fragmentUri = Uri.parse(baseUri.fragment);
        inviteId = fragmentUri.queryParameters['inviteId'];
      } catch (_) {}
    }

    if (inviteId != null && inviteId.isNotEmpty) {
      _showUrlInviteDialog(inviteId);
    }
  }

  void _showUrlInviteDialog(String inviteId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.mail_outline, color: Colors.deepPurpleAccent),
            SizedBox(width: 12),
            Text('Workspace Invitation', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'You have clicked an invitation link to join a workspace. Would you like to accept it now?',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Decline'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              setState(() => _loadingOrgs = true);
              final success = await _authService.acceptInvitation(inviteId);
              if (success) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Successfully accepted the invitation! Welcome to your new workspace.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to accept the invitation. It may have expired.'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
              _fetchData();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurpleAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Accept & Join'),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchData() async {
    setState(() {
      _loadingOrgs = true;
      _loadingMyInvites = true;
    });

    // 1. Fetch current session to read activeOrganizationId
    final session = await _authService.getSession();
    if (session != null && session['session'] != null) {
      _activeOrgId = session['session']['activeOrganizationId'] as String?;
    }

    // 2. Load user memberships / organizations
    final orgs = await _authService.listOrganizations();

    // 3. Load user pending invitations
    final myInvites = await _authService.listMyPendingInvitations();

    if (mounted) {
      setState(() {
        _organizations = orgs;
        _myPendingInvites = myInvites;
        _loadingOrgs = false;
        _loadingMyInvites = false;
      });
    }
  }

  Future<void> _setActiveOrg(String orgId) async {
    setState(() => _actionInProgress = true);
    final res = await _authService.setActiveOrganization(orgId);
    setState(() => _actionInProgress = false);
    
    if (res != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Workspace updated successfully!')),
        );
      }
      _fetchData();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to switch workspace.'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _showCreateOrgDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.business_outlined, color: Colors.deepPurpleAccent),
                  SizedBox(width: 12),
                  Text('Create Organization', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: Form(
                key: _orgFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Create a new organization workspace to manage users and projects.',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _orgNameController,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        prefixIcon: Icon(Icons.business_outlined),
                      ),
                      validator: (value) => (value == null || value.trim().isEmpty) ? 'Enter organization name' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _orgSlugController,
                      decoration: const InputDecoration(
                        labelText: 'Slug (e.g. my-team)',
                        prefixIcon: Icon(Icons.link_outlined),
                      ),
                      validator: (value) => (value == null || value.trim().isEmpty) ? 'Enter unique slug' : null,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _actionInProgress ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _actionInProgress ? null : () async {
                    if (!_orgFormKey.currentState!.validate()) return;
                    
                    setDialogState(() {
                      _actionInProgress = true;
                    });
                    setState(() {
                      _actionInProgress = true;
                    });
                    
                    final created = await _authService.createOrganization(
                      _orgNameController.text.trim(),
                      _orgSlugController.text.trim(),
                    );
                    
                    setDialogState(() {
                      _actionInProgress = false;
                    });
                    setState(() {
                      _actionInProgress = false;
                    });
                    
                    if (created != null) {
                      _orgNameController.clear();
                      _orgSlugController.clear();
                      _fetchData();
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Organization created successfully!'), backgroundColor: Colors.green),
                        );
                      }
                    } else {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Failed to create organization.'), backgroundColor: Colors.redAccent),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurpleAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _actionInProgress
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Create', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handlePendingInviteAction(String inviteId, bool accept) async {
    setState(() => _actionInProgress = true);
    final success = accept 
        ? await _authService.acceptInvitation(inviteId)
        : await _authService.rejectInvitation(inviteId);
    setState(() => _actionInProgress = false);

    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(accept ? 'Invitation accepted!' : 'Invitation declined.'),
            backgroundColor: accept ? Colors.green : Colors.grey,
          ),
        );
      }
      _fetchData();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Action failed. Invitation might be invalid.'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Widget _buildReceivedInvitationsSection() {
    if (_loadingMyInvites) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent)),
        ),
      );
    }

    if (_myPendingInvites.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.green, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.mail_outline, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'Pending Invitations to You',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _myPendingInvites.length,
              itemBuilder: (ctx, index) {
                final invite = _myPendingInvites[index];
                final org = invite['organization'] ?? {};
                final inviter = invite['inviter'] ?? {};

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              org['name'] ?? 'Unnamed Organization',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Invited by: ${inviter['name'] ?? 'Unknown'} (${invite['role'] ?? 'member'})',
                              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.check_circle, color: Colors.green),
                        onPressed: _actionInProgress ? null : () => _handlePendingInviteAction(invite['id'], true),
                        tooltip: 'Accept invitation',
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.redAccent),
                        onPressed: _actionInProgress ? null : () => _handlePendingInviteAction(invite['id'], false),
                        tooltip: 'Decline invitation',
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrgsListSection(Map<String, dynamic> session) {
    if (_loadingOrgs) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20.0),
          child: CircularProgressIndicator(color: Colors.deepPurpleAccent),
        ),
      );
    }

    if (_organizations.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40.0),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.group_work_outlined, size: 48, color: Colors.grey),
                SizedBox(height: 12),
                Text('No organizations found. Create one to get started!', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _organizations.length,
      itemBuilder: (context, index) {
        final org = _organizations[index];
        final orgData = org['organization'] ?? org;
        final orgId = orgData['id'] as String;
        final isActive = orgId == _activeOrgId;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isActive ? Colors.deepPurpleAccent : Colors.transparent,
              width: isActive ? 2 : 0,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: ListTile(
              onTap: () {
                setState(() {
                  _selectedOrg = org;
                });
              },
              leading: CircleAvatar(
                backgroundColor: isActive ? Colors.deepPurpleAccent : Colors.deepPurple.shade900,
                foregroundColor: Colors.white,
                child: Text((orgData['name'] as String? ?? 'O')[0].toUpperCase()),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      orgData['name'] as String? ?? 'Unnamed',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.deepPurpleAccent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('ACTIVE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              subtitle: Text('Slug: ${orgData['slug'] ?? ''}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.deepPurpleAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      (org['role'] as String? ?? 'Member').toUpperCase(),
                      style: const TextStyle(fontSize: 10, color: Colors.deepPurpleAccent, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (!isActive) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.play_circle_outline, color: Colors.deepPurpleAccent),
                      onPressed: _actionInProgress ? null : () => _setActiveOrg(orgId),
                      tooltip: 'Set Active Workspace',
                    ),
                  ],
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrgsTab(bool isMobile, Map<String, dynamic> session) {
    final header = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Organizations',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: _showCreateOrgDialog,
              icon: const Icon(Icons.add),
              label: const Text('Create New'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchData,
              tooltip: 'Refresh organizations',
            ),
          ],
        ),
      ],
    );

    final content = SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildReceivedInvitationsSection(),
          if (_myPendingInvites.isNotEmpty) const SizedBox(height: 20),
          _buildOrgsListSection(session),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        const SizedBox(height: 20),
        Expanded(child: content),
      ],
    );
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
          child: _selectedOrg == null
              ? _buildOrgsTab(isMobile, session)
              : OrganizationDetailsScreen(
                  org: _selectedOrg!,
                  session: session,
                  isEmbedded: true,
                  onBack: () {
                    setState(() {
                      _selectedOrg = null;
                    });
                    _fetchData();
                  },
                ),
        );
      },
    );
  }
}
