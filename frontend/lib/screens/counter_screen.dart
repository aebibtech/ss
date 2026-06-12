import 'package:flutter/material.dart';
import '../widgets/dashboard_layout.dart';
import '../widgets/session_guard.dart';

class CounterScreen extends StatefulWidget {
  const CounterScreen({super.key});

  @override
  State<CounterScreen> createState() => _CounterScreenState();
}

class _CounterScreenState extends State<CounterScreen> {
  int _counter = 0;

  @override
  Widget build(BuildContext context) {
    return SessionGuard(
      builder: (context, session, authService) {
        return DashboardLayout(
          selectedTab: 0,
          authService: authService,
          session: session,
          child: Center(
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
          ),
        );
      },
    );
  }
}
