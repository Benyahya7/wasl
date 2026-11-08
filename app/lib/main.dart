import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/firebase_options.dart';
import 'core/result.dart';
import 'models/app_user.dart';
import 'screens/admin_home.dart';
import 'screens/customer_home.dart';
import 'screens/driver_home.dart';
import 'screens/onboarding_screen.dart';
import 'screens/sign_in_screen.dart';
import 'screens/store_home.dart';
import 'services/auth_service.dart';
import 'theme.dart';
import 'widgets/call_overlay.dart';

/// DIAGNOSTIC BUILD (1.0.1): 1.0.0 crashed on launch on the user's phone with
/// no visible error. Instead of dying silently, this build catches any
/// startup failure and SHOWS it on screen, so the cause can be read.
/// Once the cause is known and fixed, the zone handler goes back to
/// reporting-only.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runZonedGuarded(
    () async {
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } catch (e, stack) {
        runApp(StartupErrorApp(message: '$e\n$stack'));
        return;
      }
      runApp(const WaslApp());
    },
    (error, stack) {
      runApp(StartupErrorApp(message: '$error\n$stack'));
    },
  );
}

/// Shown instead of a crash: the exact error, readable on the phone.
class StartupErrorApp extends StatelessWidget {
  final String message;

  const StartupErrorApp({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wasl',
      theme: WaslTheme.light,
      home: StartupErrorScreen(message: message),
    );
  }
}

class StartupErrorScreen extends StatefulWidget {
  final String message;

  const StartupErrorScreen({super.key, required this.message});

  @override
  State<StartupErrorScreen> createState() => _StartupErrorScreenState();
}

class _StartupErrorScreenState extends State<StartupErrorScreen> {
  bool _busy = false;
  String? _retryError;

  Future<void> _retry() async {
    setState(() {
      _busy = true;
      _retryError = null;
    });
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      if (mounted) runApp(const WaslApp());
    } catch (e) {
      setState(() {
        _retryError = e.toString();
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wasl could not start')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'The app hit an error while starting. This is what happened:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _retryError ?? widget.message,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _busy ? null : _retry,
              child: const Text('Try again'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please send a screenshot of the error above to Raiss — it says exactly what failed.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class WaslApp extends StatelessWidget {
  const WaslApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wasl',
      theme: WaslTheme.light,
      home: const AuthGate(),
    );
  }
}

/// Routes by auth state + Wasl profile:
/// signed out → sign-in; no profile → role picker;
/// pending → waiting screen; approved → home by role.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AuthService _auth = AuthService();
  int _refresh = 0;

  @override
  void initState() {
    super.initState();
    _auth.initialize();
  }

  void _bump() => setState(() => _refresh++);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth.authStateChanges,
      builder: (context, authSnapshot) {
        final user = authSnapshot.data;
        if (user == null) {
          // The auth stream drives navigation after sign-in.
          return SignInScreen(auth: _auth, onSignedIn: (_) {});
        }
        return FutureBuilder<Result<AppUser?>>(
          key: ValueKey(_refresh),
          future: _auth.ensureProfile(user),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState ==
                ConnectionState.waiting) {
              return const Scaffold(
                  body: Center(child: CircularProgressIndicator()));
            }
            if (profileSnapshot.hasError) {
              return Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: ErrorBanner(
                      message:
                          'Could not load your account: ${profileSnapshot.error}',
                      onRetry: _bump,
                    ),
                  ),
                ),
              );
            }
            final result = profileSnapshot.data;
            if (result == null) {
              return Scaffold(
                body: Center(
                  child: ErrorBanner(
                    message: 'Could not load your account.',
                    onRetry: _bump,
                  ),
                ),
              );
            }
            return result.fold(
              (profile) {
                if (profile == null) {
                  return OnboardingScreen(
                    auth: _auth,
                    user: user,
                    onProfileCreated: (_) => _bump(),
                  );
                }
                if (profile.isPending ||
                    profile.verificationStatus == 'rejected') {
                  return PendingApprovalScreen(
                    profile: profile,
                    auth: _auth,
                    onRefresh: _bump,
                  );
                }
                // Calls ring only while the app is open (no push
                // notifications on the free plan): each role home sits
                // inside a CallOverlay that watches the `calls` docs.
                // Customers are never call parties, so they skip it.
                return switch (profile.role) {
                  'admin' => CallOverlay(
                      profile: profile,
                      child: AdminHome(profile: profile, auth: _auth),
                    ),
                  'store' => CallOverlay(
                      profile: profile,
                      child: StoreHome(profile: profile, auth: _auth),
                    ),
                  'customer' =>
                    CustomerHome(profile: profile, auth: _auth),
                  _ => CallOverlay(
                      profile: profile,
                      child: DriverHome(profile: profile, auth: _auth),
                    ),
                };
              },
              (message) => Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: ErrorBanner(message: message, onRetry: _bump),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
