import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'services/auth_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Better Auth Workspace',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        fontFamily: 'Outfit',
        cardTheme: CardThemeData(
          elevation: 12,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          color: Colors.deepPurple.shade900.withOpacity(0.35),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.deepPurple.shade900.withOpacity(0.2),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.deepPurple.shade800),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.deepPurple.shade900),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.deepPurpleAccent, width: 2),
          ),
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  Map<String, dynamic>? _session;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    setState(() => _isLoading = true);
    final session = await _authService.getSession();
    setState(() {
      _session = session;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Colors.deepPurpleAccent,
          ),
        ),
      );
    }

    if (_session == null) {
      return AuthScreen(
        authService: _authService,
        onAuthSuccess: _checkSession,
      );
    }

    return DashboardScreen(
      authService: _authService,
      session: _session!,
      onSignOut: _checkSession,
    );
  }
}

class AuthScreen extends StatefulWidget {
  final AuthService authService;
  final VoidCallback onAuthSuccess;

  const AuthScreen({
    super.key,
    required this.authService,
    required this.onAuthSuccess,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSending = false;
  bool _magicLinkSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendMagicLink() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSending = true);

    // Dynamic callback URL based on web window location
    final callbackUrl = Uri.base.origin;
    final success = await widget.authService.sendMagicLink(
      _emailController.text.trim(),
      callbackUrl,
    );

    setState(() {
      _isSending = false;
      if (success) {
        _magicLinkSent = true;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send magic link.')),
        );
      }
    });
  }

  Future<void> _signInWithGoogle() async {
    final callbackUrl = Uri.base.origin;
    final googleUrl = widget.authService.getGoogleLoginUrl(callbackUrl);
    
    try {
      await launchUrl(Uri.parse(googleUrl), webOnlyWindowName: '_self');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open login page: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.deepPurple.shade900,
              Colors.purple.shade900,
              Colors.blue.shade900,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              width: 420,
              padding: const EdgeInsets.all(32),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.lock_person_outlined,
                        size: 64,
                        color: Colors.deepPurpleAccent,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Welcome Back',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Authenticate via Magic Link or Google OAuth',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.deepPurple.shade200,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      if (!_magicLinkSent) ...[
                        Form(
                          key: _formKey,
                          child: TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email Address',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your email';
                              }
                              if (!value.contains('@')) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isSending ? null : _sendMagicLink,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurpleAccent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isSending
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text('Send Magic Link', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.shade800),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.mark_email_read_outlined, size: 48, color: Colors.green),
                              const SizedBox(height: 12),
                              const Text(
                                'Check your Email!',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'We have sent a login link to ${_emailController.text}. Click the link to securely sign in.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey.shade300, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextButton(
                          onPressed: () => setState(() => _magicLinkSent = false),
                          child: const Text('Back to sign in'),
                        )
                      ],
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(child: Divider(color: Colors.deepPurple.shade900)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text('OR', style: TextStyle(color: Colors.deepPurple.shade300, fontSize: 12)),
                          ),
                          Expanded(child: Divider(color: Colors.deepPurple.shade900)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: _signInWithGoogle,
                          icon: Image.network(
                            'https://upload.wikimedia.org/wikipedia/commons/c/c1/Google_%22G%22_logo.svg',
                            height: 20,
                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.g_mobiledata, size: 24),
                          ),
                          label: const Text('Continue with Google', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.deepPurple.shade800),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  final AuthService authService;
  final Map<String, dynamic> session;
  final VoidCallback onSignOut;

  const DashboardScreen({
    super.key,
    required this.authService,
    required this.session,
    required this.onSignOut,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _counter = 0;
  int _selectedTab = 0;
  List<dynamic> _organizations = [];
  bool _loadingOrgs = false;
  final _orgNameController = TextEditingController();
  final _orgSlugController = TextEditingController();
  final _orgFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
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
    final orgs = await widget.authService.listOrganizations();
    setState(() {
      _organizations = orgs;
      _loadingOrgs = false;
    });
  }

  Future<void> _createOrg() async {
    if (!_orgFormKey.currentState!.validate()) return;

    final created = await widget.authService.createOrganization(
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

  Future<void> _signOut() async {
    final success = await widget.authService.signOut();
    if (success) {
      widget.onSignOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.session['user'];
    final userRole = user['role'] ?? 'user';
    final isAdmin = userRole == 'admin';
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(isMobile ? 'Better Auth' : 'Better Auth Dashboard', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        actions: [
          Row(
            children: [
              GestureDetector(
                onTap: isMobile ? () => _showUserProfileDialog(context, user, userRole) : null,
                child: Builder(
                  builder: (context) {
                    final name = user['name'] as String? ?? '';
                    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
                    final displayName = name.isNotEmpty ? name : (user['email'] as String? ?? 'User');
                    return Row(
                      children: [
                        CircleAvatar(
                          backgroundImage: user['image'] != null ? NetworkImage(user['image']) : null,
                          backgroundColor: Colors.deepPurpleAccent,
                          child: user['image'] == null ? Text(initial) : null,
                        ),
                        if (!isMobile) ...[
                          const SizedBox(width: 12),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(displayName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                              Text(user['email'] as String? ?? '', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                            ],
                          ),
                        ],
                      ],
                    );
                  }
                ),
              ),
              if (isAdmin && !isMobile) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('Admin', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
              if (!isMobile) ...[
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: _signOut,
                  tooltip: 'Sign Out',
                ),
              ],
              const SizedBox(width: 8),
            ],
          )
        ],
      ),
      body: isMobile
          ? Container(
              padding: const EdgeInsets.all(16),
              color: Colors.black12,
              child: IndexedStack(
                index: _selectedTab,
                children: [
                  // Tab 0: Counter App (Protected)
                  _buildCounterTab(),
                  // Tab 1: Organizations Tab
                  _buildOrgsTab(true),
                  // Tab 2: Admin Panel (If admin)
                  if (isAdmin) _buildAdminTab(true) else const SizedBox.shrink(),
                ],
              ),
            )
          : Row(
              children: [
                // Sidebar
                NavigationRail(
                  selectedIndex: _selectedTab,
                  onDestinationSelected: (int index) {
                    setState(() {
                      _selectedTab = index;
                    });
                  },
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    const NavigationRailDestination(
                      icon: Icon(Icons.add),
                      selectedIcon: Icon(Icons.add_box),
                      label: Text('Counter'),
                    ),
                    const NavigationRailDestination(
                      icon: Icon(Icons.group_outlined),
                      selectedIcon: Icon(Icons.group),
                      label: Text('Organizations'),
                    ),
                    if (isAdmin)
                      const NavigationRailDestination(
                        icon: Icon(Icons.admin_panel_settings_outlined),
                        selectedIcon: Icon(Icons.admin_panel_settings),
                        label: Text('Admin Panel'),
                      ),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1),
                // Main Content Area
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    color: Colors.black12,
                    child: IndexedStack(
                      index: _selectedTab,
                      children: [
                        // Tab 0: Counter App (Protected)
                        _buildCounterTab(),
                        // Tab 1: Organizations Tab
                        _buildOrgsTab(false),
                        // Tab 2: Admin Panel (If admin)
                        if (isAdmin) _buildAdminTab(false) else const SizedBox.shrink(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: isMobile
          ? NavigationBar(
              selectedIndex: _selectedTab,
              onDestinationSelected: (int index) {
                setState(() {
                  _selectedTab = index;
                });
              },
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.add),
                  selectedIcon: Icon(Icons.add_box),
                  label: 'Counter',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.group_outlined),
                  selectedIcon: Icon(Icons.group),
                  label: 'Organizations',
                ),
                if (isAdmin)
                  const NavigationDestination(
                    icon: Icon(Icons.admin_panel_settings_outlined),
                    selectedIcon: Icon(Icons.admin_panel_settings),
                    label: 'Admin Panel',
                  ),
              ],
            )
          : null,
    );
  }

  void _showUserProfileDialog(BuildContext context, Map<String, dynamic> user, String role) {
    final name = user['name'] as String? ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    final displayName = name.isNotEmpty ? name : (user['email'] as String? ?? 'User');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('User Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundImage: user['image'] != null ? NetworkImage(user['image']) : null,
              backgroundColor: Colors.deepPurpleAccent,
              child: user['image'] == null ? Text(initial, style: const TextStyle(fontSize: 28)) : null,
            ),
            const SizedBox(height: 16),
            Text(displayName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(user['email'] as String? ?? '', style: TextStyle(color: Colors.grey.shade400)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: role == 'admin' ? Colors.red.shade900 : Colors.deepPurpleAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                role.toUpperCase(),
                style: TextStyle(
                  fontSize: 12, 
                  fontWeight: FontWeight.bold,
                  color: role == 'admin' ? Colors.white : Colors.deepPurpleAccent,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _signOut();
            },
            icon: const Icon(Icons.logout),
            label: const Text('Sign Out'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade900,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCounterTab() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.security, size: 72, color: Colors.deepPurpleAccent),
            const SizedBox(height: 16),
            const Text(
              'Protected Counter App',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'This counter is only accessible to authenticated users.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 48),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
                child: Column(
                  children: [
                    const Text(
                      'You have pushed the button this many times:',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '$_counter',
                      style: const TextStyle(fontSize: 72, fontWeight: FontWeight.bold, color: Colors.deepPurpleAccent),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => setState(() => _counter++),
                      icon: const Icon(Icons.add),
                      label: const Text('Increment'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurpleAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
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

  Widget _buildAdminTab(bool isMobile) {
    final statCards = [
      _buildStatCard('Total Users', '142', Icons.people_outline, Colors.blue),
      _buildStatCard('Active Sessions', '31', Icons.flash_on_outlined, Colors.orange),
      _buildStatCard('Total Orgs', '12', Icons.group_work_outlined, Colors.purple),
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
}
