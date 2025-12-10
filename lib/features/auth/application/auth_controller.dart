import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../domain/entities/credentials.dart';
import '../domain/entities/user.dart';
import '../domain/repositories/auth_repository.dart';
import 'google_auth_service.dart';

class AuthState {
  const AuthState({this.user, this.isLoading = false, this.errorMessage});

  final User? user;
  final bool isLoading;
  final String? errorMessage;

  bool get isAuthenticated => user != null;

  AuthState copyWith({User? user, bool? isLoading, String? errorMessage}) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class AuthController extends ChangeNotifier {
  AuthController({required this.repository, this.googleAuthService});

  final AuthRepository repository;
  final GoogleAuthService? googleAuthService;
  AuthState _state = const AuthState();

  AuthState get state => _state;

  Future<void> restoreSession() async {
    _setState(_state.copyWith(isLoading: true, errorMessage: null));
    final user = await repository.currentUser();
    _setState(AuthState(user: user, isLoading: false));
  }

  Future<void> login({
    required String username,
    required String password,
  }) async {
    _setState(_state.copyWith(isLoading: true, errorMessage: null));
    try {
      final user = await repository.login(
        Credentials(username: username.trim(), password: password),
      );
      _setState(AuthState(user: user, isLoading: false));
    } on AuthException catch (error) {
      _setState(
        AuthState(user: null, isLoading: false, errorMessage: error.message),
      );
    }
  }

  Future<void> loginWithGoogle() async {
    final service = googleAuthService;
    if (service == null) return;

    _setState(_state.copyWith(isLoading: true, errorMessage: null));
    try {
      final account = await service.signIn();
      if (account == null) {
        _setState(_state.copyWith(isLoading: false));
        return;
      }

      final user = await repository.loginWithGoogle(account);
      _setState(AuthState(user: user, isLoading: false));
    } on AuthException catch (error) {
      _setState(
        AuthState(user: null, isLoading: false, errorMessage: error.message),
      );
    } catch (_) {
      _setState(
        const AuthState(
          user: null,
          isLoading: false,
          errorMessage: 'Google sign-in failed',
        ),
      );
    }
  }

  Future<void> signup({
    required String username,
    required String password,
  }) async {
    _setState(_state.copyWith(isLoading: true, errorMessage: null));
    try {
      final user = await repository.signup(
        Credentials(username: username.trim(), password: password),
      );
      _setState(AuthState(user: user, isLoading: false));
    } on AuthException catch (error) {
      _setState(
        AuthState(user: null, isLoading: false, errorMessage: error.message),
      );
    }
  }

  Future<void> signOut() async {
    try {
      await googleAuthService?.signOut();
    } catch (_) {}
    await repository.logout();
    _setState(const AuthState());
  }

  void _setState(AuthState state) {
    _state = state;
    notifyListeners();
  }
}

class AuthScope extends InheritedNotifier<AuthController> {
  const AuthScope({
    super.key,
    required AuthController controller,
    required super.child,
  }) : super(notifier: controller);

  static AuthController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AuthScope>();
    assert(scope != null, 'AuthScope not found in context');
    return scope!.notifier!;
  }
}
