import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../main.dart';
import '../admin/admin_dashboard.dart';
import 'login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }
        if (snapshot.hasData) {
          return _RoleRouter(user: snapshot.data!);
        }
        return const LoginScreen();
      },
    );
  }
}

class _RoleRouter extends StatefulWidget {
  final User user;
  const _RoleRouter({required this.user});

  @override
  State<_RoleRouter> createState() => _RoleRouterState();
}

class _RoleRouterState extends State<_RoleRouter> {
  late Future<String> _roleFuture;

  @override
  void initState() {
    super.initState();
    _roleFuture = UserService.getUserRole(widget.user.uid);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _roleFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const _LoadingScreen();
        final role = snapshot.data!;
        if (UserService.isAdmin(role)) return const AdminDashboard();
        return const HomeScreen();
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
