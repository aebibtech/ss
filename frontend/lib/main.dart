import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'services/auth_service.dart';
import 'screens/counter_screen.dart';
import 'screens/movies_screen.dart';
import 'screens/organizations_screen.dart';
import 'screens/admin_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'New App',
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
      initialRoute: '/',
      onGenerateRoute: (settings) {
        WidgetBuilder builder;
        switch (settings.name) {
          case '/':
            builder = (context) => const MainScreen();
            break;
          case '/counter':
            builder = (context) => const CounterScreen();
            break;
          case '/movies':
            builder = (context) => const MoviesScreen();
            break;
          case '/organizations':
            builder = (context) => const OrganizationsScreen();
            break;
          case '/admin':
            builder = (context) => const AdminScreen();
            break;
          default:
            builder = (context) => const MainScreen();
        }
        return PageRouteBuilder(
          settings: settings,
          pageBuilder: (context, animation, secondaryAnimation) => builder(context),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        );
      },
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
    if (session != null && mounted) {
      Navigator.of(context).pushReplacementNamed('/counter');
    }
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

    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(
          color: Colors.deepPurpleAccent,
        ),
      ),
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
