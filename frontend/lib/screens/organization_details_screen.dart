import 'package:flutter/material.dart';
import '../widgets/dashboard_layout.dart';
import '../widgets/session_guard.dart';
import '../services/auth_service.dart';

class OrganizationDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> org;
  final Map<String, dynamic> session;
  final bool isEmbedded;
  final VoidCallback? onBack;

  const OrganizationDetailsScreen({
    super.key,
    required this.org,
    required this.session,
    this.isEmbedded = false,
    this.onBack,
  });

  @override
  State<OrganizationDetailsScreen> createState() => _OrganizationDetailsScreenState();
}

class _OrganizationDetailsScreenState extends State<OrganizationDetailsScreen> with SingleTickerProviderStateMixin {
  List<dynamic> _members = [];
  List<dynamic> _invitations = [];
  
  bool _loadingMembers = false;
  bool _loadingInvites = false;
  bool _actionInProgress = false;

  late String _orgId;
  late String _orgName;
  late String _currentUserRole;
  late AuthService _authService;
  late TabController _tabController;
  String? _activeOrgId;

  final _inviteEmailController = TextEditingController();
  String _inviteRole = 'member';
  final _inviteFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _tabController = TabController(length: 2, vsync: this);

    final orgData = widget.org['organization'] ?? widget.org;
    _orgId = orgData['id'] as String;
    _orgName = orgData['name'] as String? ?? 'Unnamed';
    _currentUserRole = widget.org['role'] as String? ?? 'member';

    if (widget.session['session'] != null) {
      _activeOrgId = widget.session['session']['activeOrganizationId'] as String?;
    }

    _fetchDetails();
  }

  @override
  void dispose() {
    _inviteEmailController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchDetails() async {
    setState(() {
      _loadingMembers = true;
      _loadingInvites = true;
    });

    final members = await _authService.listActiveOrganizationMembers(_orgId);
    final invites = await _authService.listActiveOrganizationInvitations(_orgId);

    if (mounted) {
      setState(() {
        _members = members;
        _invitations = invites;
        _loadingMembers = false;
        _loadingInvites = false;
      });
    }
  }

  bool _canManage() {
    return _currentUserRole == 'owner' || _currentUserRole == 'admin';
  }

  Future<void> _setActiveOrg() async {
    setState(() => _actionInProgress = true);
    final res = await _authService.setActiveOrganization(_orgId);
    setState(() => _actionInProgress = false);
    
    if (res != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Workspace updated successfully!')),
        );
        setState(() {
          _activeOrgId = _orgId;
        });
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to switch workspace.'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _showInviteDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.mail_outline, color: Colors.deepPurpleAccent),
                  SizedBox(width: 12),
                  Text('Invite Member', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: Form(
                key: _inviteFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Invite a new member to join this workspace. An email invitation will be sent.',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _inviteEmailController,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Enter email';
                        final email = value.trim().toLowerCase();
                        if (!email.contains('@')) return 'Invalid email';
                        
                        final isMember = _members.any((m) {
                          final user = m['user'] ?? {};
                          final mEmail = (user['email'] as String? ?? '').toLowerCase();
                          return mEmail == email;
                        });
                        if (isMember) {
                          return 'User is already a member of this workspace';
                        }

                        final isInvited = _invitations.any((i) {
                          final iEmail = (i['email'] as String? ?? '').toLowerCase();
                          final iStatus = (i['status'] as String? ?? 'pending').toLowerCase();
                          return iEmail == email && iStatus == 'pending';
                        });
                        if (isInvited) {
                          return 'User has already been invited';
                        }
                        
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _inviteRole,
                      decoration: const InputDecoration(
                        labelText: 'Workspace Role',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'member', child: Text('Member')),
                        DropdownMenuItem(value: 'admin', child: Text('Admin')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            _inviteRole = val;
                          });
                        }
                      },
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
                    if (!_inviteFormKey.currentState!.validate()) return;
                    
                    setDialogState(() {
                      _actionInProgress = true;
                    });
                    setState(() {
                      _actionInProgress = true;
                    });
                    
                    Map<String, dynamic>? invite;
                    String? errorMessage;
                    try {
                      invite = await _authService.inviteMember(
                        email: _inviteEmailController.text.trim(),
                        role: _inviteRole,
                        organizationId: _orgId,
                      );
                    } catch (e) {
                      errorMessage = e.toString().replaceFirst('Exception: ', '');
                    }
                    
                    setDialogState(() {
                      _actionInProgress = false;
                    });
                    setState(() {
                      _actionInProgress = false;
                    });
                    
                    if (invite != null) {
                      _inviteEmailController.clear();
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Invitation sent successfully!'), backgroundColor: Colors.green),
                        );
                      }
                      _fetchDetails();
                    } else {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(errorMessage ?? 'Failed to send invitation. Make sure the user is not already a member.'),
                            backgroundColor: Colors.redAccent,
                          ),
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
                      : const Text('Send Invitation'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _cancelInvite(String inviteId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Invitation'),
        content: const Text('Are you sure you want to revoke this pending invitation?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _actionInProgress = true);
    final success = await _authService.cancelInvitation(inviteId);
    setState(() => _actionInProgress = false);

    if (success) {
      _fetchDetails();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invitation cancelled.')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to cancel invitation.'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _removeMember(String memberId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text('Are you sure you want to remove $name from the workspace?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _actionInProgress = true);
    final success = await _authService.removeMember(memberId, _orgId);
    setState(() => _actionInProgress = false);

    if (success) {
      _fetchDetails();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Member removed from workspace.')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to remove member. Last owner cannot be removed.'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _updateRole(String memberId, String newRole) async {
    setState(() => _actionInProgress = true);
    final success = await _authService.updateMemberRole(memberId, newRole, _orgId);
    setState(() => _actionInProgress = false);

    if (success) {
      _fetchDetails();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Role updated to $newRole.')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update role.'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Widget _buildMembersTab() {
    if (_loadingMembers) {
      return const Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent));
    }

    final isOwnerOrAdmin = _canManage();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Workspace Members (${_members.length})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            itemCount: _members.length,
            itemBuilder: (ctx, index) {
              final member = _members[index];
              final user = member['user'] ?? {};
              final role = member['role'] as String? ?? 'member';
              final memberId = member['id'] as String;

              final name = user['name'] as String? ?? 'Unnamed';
              final email = user['email'] as String? ?? '';
              final image = user['image'] as String?;
              final isMe = user['id'] == _authService.cachedSession?['user']?['id'];
              
              final isOwner = role == 'owner';

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade900.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.deepPurple.shade900.withOpacity(0.2)),
                ),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundImage: image != null ? NetworkImage(image) : null,
                    backgroundColor: isMe ? Colors.deepPurpleAccent : Colors.grey.shade800,
                    child: image == null ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'U') : null,
                  ),
                  title: Text(
                    name + (isMe ? ' (You)' : ''),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: Text(email, style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isOwnerOrAdmin && !isMe && !isOwner)
                        DropdownButton<String>(
                          value: role == 'admin' ? 'admin' : 'member',
                          dropdownColor: Colors.deepPurple.shade900,
                          underline: const SizedBox.shrink(),
                          items: const [
                            DropdownMenuItem(value: 'member', child: Text('Member', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: 'admin', child: Text('Admin', style: TextStyle(fontSize: 12))),
                          ],
                          onChanged: _actionInProgress ? null : (newRole) {
                            if (newRole != null) {
                              _updateRole(memberId, newRole);
                            }
                          },
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: isOwner ? Colors.redAccent.withOpacity(0.2) : Colors.deepPurpleAccent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            role.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isOwner ? Colors.redAccent : Colors.deepPurpleAccent,
                            ),
                          ),
                        ),
                      if (isOwnerOrAdmin && !isMe && !isOwner) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                          onPressed: _actionInProgress ? null : () => _removeMember(memberId, name),
                          tooltip: 'Remove member',
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInvitationsTab() {
    if (_loadingInvites) {
      return const Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent));
    }

    final isOwnerOrAdmin = _canManage();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isOwnerOrAdmin) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Pending Invitations',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              ElevatedButton.icon(
                onPressed: _showInviteDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Invite Member', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurpleAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Only Admins and Owners can invite members or manage workspace credentials.',
                    style: TextStyle(color: Colors.orangeAccent, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Pending Invitations',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 8),
        ],
        Expanded(
          child: _invitations.isEmpty
              ? const Center(
                  child: Text('No pending invitations', style: TextStyle(color: Colors.grey, fontSize: 13)),
                )
              : ListView.builder(
                  itemCount: _invitations.length,
                  itemBuilder: (ctx, idx) {
                    final invite = _invitations[idx];
                    final inviter = invite['inviter'] ?? {};
                    final inviteId = invite['id'] as String;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(invite['email'] ?? ''),
                        subtitle: Text(
                          'Role: ${invite['role'] ?? 'member'} • Inviter: ${inviter['name'] ?? 'Unknown'}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                (invite['status'] as String? ?? 'pending').toUpperCase(),
                                style: const TextStyle(fontSize: 9, color: Colors.orangeAccent, fontWeight: FontWeight.bold),
                              ),
                            ),
                            if (isOwnerOrAdmin) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 20),
                                onPressed: _actionInProgress ? null : () => _cancelInvite(inviteId),
                                tooltip: 'Cancel Invitation',
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDetailsBody() {
    final header = Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack ?? () => Navigator.pop(context),
          tooltip: 'Back to Organizations',
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _orgName,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 12),
        if (_activeOrgId == _orgId)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('ACTIVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
          )
        else
          IconButton(
            icon: const Icon(Icons.play_circle_outline),
            onPressed: _actionInProgress ? null : _setActiveOrg,
            tooltip: 'Set as Active Workspace',
          ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.sync),
          onPressed: _fetchDetails,
          tooltip: 'Sync workspace data',
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 48.0), // Align with title text
          child: Text(
            'Role: ${_currentUserRole.toUpperCase()}',
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ),
        const SizedBox(height: 20),
        TabBar(
          controller: _tabController,
          indicatorColor: Colors.deepPurpleAccent,
          labelColor: Colors.deepPurpleAccent,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.people_alt_outlined), text: 'Members'),
            Tab(icon: Icon(Icons.mail_outline), text: 'Invitations'),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildMembersTab(),
              _buildInvitationsTab(),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEmbedded) {
      return _buildDetailsBody();
    }
    return SessionGuard(
      builder: (context, session, authService) {
        return DashboardLayout(
          selectedTab: 2,
          authService: authService,
          session: session,
          child: _buildDetailsBody(),
        );
      },
    );
  }
}
