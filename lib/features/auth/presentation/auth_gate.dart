import 'package:flutter/material.dart';

import '../application/auth_controller.dart';
import 'auth_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    required this.controller,
    required this.homeBuilder,
  });

  final AuthController controller;
  final WidgetBuilder homeBuilder;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final state = controller.state;
        if (state.isLoading && !state.isAuthenticated) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!state.isAuthenticated) {
          return AuthPage(controller: controller);
        }

        return homeBuilder(context);
      },
    );
  }
}
