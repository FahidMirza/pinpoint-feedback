import 'package:flutter/material.dart';
import 'package:pinpoint_feedback/pinpoint_feedback.dart';

void main() {
  // This is the entire integration.
  runApp(
    // The whole integration. The package id identifies the app; version and
    // device details are read from the platform.
    const Pinpoint(child: DemoApp()),
  );
}

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pinpoint Demo',
      debugShowCheckedModeBanner: false,
      navigatorObservers: [PinpointRouteObserver()],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0A84FF)),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (_) => const HomeScreen(),
        '/checkout': (_) => const CheckoutScreen(),
      },
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pinpoint Demo')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Pretend this is a client app.',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap the blue button bottom-right, mark a few spots, write a note '
            'and submit. Then check the feedback table in Supabase.',
            style: TextStyle(fontSize: 15, height: 1.4),
          ),
          const SizedBox(height: 28),
          Card(
            child: ListTile(
              leading: const Icon(Icons.shopping_bag_outlined),
              title: const Text('Go to checkout'),
              subtitle: const Text('Tests screen-name capture'),
              onTap: () => Navigator.pushNamed(context, '/checkout'),
            ),
          ),
          const SizedBox(height: 20),
          // Deliberately overlapping widgets — something to mark.
          SizedBox(
            height: 90,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 20,
                  child: FilledButton(onPressed: () {}, child: const Text('Confirm order')),
                ),
                Positioned(
                  left: 90,
                  top: 34,
                  child: OutlinedButton(onPressed: () {}, child: const Text('Cancel')),
                ),
              ],
            ),
          ),
          const Text(
            'Those two buttons overlap on purpose — a realistic thing for a '
            'client to complain about.',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class CheckoutScreen extends StatelessWidget {
  const CheckoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Feedback sent from here should record screen_name as /checkout.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}
